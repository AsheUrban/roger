// E2EE key management (spec §7, pulled forward into Camera 6b) against REAL
// Supabase — proves the KeyService contracts and the §18-invariant-1 property
// that the server only ever holds WRAPPED conversation keys.
//
// Also live-verifies the conversation_keys write model (2026-07-22, revised
// same day after the third-pass review): key rows are written ONLY by the
// distribute_conversation_keys SECURITY DEFINER RPC — no client INSERT policy
// exists, which closes first-write poisoning (a member pre-planting a garbage
// row before any key exists). The RPC refuses if an active key already exists
// and requires the set to cover exactly the active members; the
// one-active-key-per-member unique index serializes concurrent initiations.
//
// Run (Ashe or Claude, emulator only — always pass -d):
//   flutter test integration_test/security/e2ee_key_test.dart \
//     -d emulator-5554 --dart-define-from-file=.env
//
// Uses test users A + B (see harness.dart). STATE CAVEAT: each run creates one
// fresh A+B conversation (clients can't delete conversations — no DELETE
// policy, by design), so test conversations accumulate in the dev DB. Wipe via
// the SQL editor when they get annoying. user_keys rows are reused across runs
// (ensureOwnKeyPair is idempotent) — but a device wipe loses the stored private
// keys, and the next run retires the old rows and uploads fresh ones.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:roger/core/services/encryption_service.dart';
import 'package:roger/core/services/key_service.dart';

import 'harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late SupabaseClient a;
  late SupabaseClient b;
  late String aId;
  late String bId;
  late KeyService keysA;
  late KeyService keysB;
  late String conversationId;

  setUpAll(() async {
    final ra = await signIn(phoneA, 'Deep Red');
    final rb = await signIn(phoneB, 'Cornflower');
    a = ra.client;
    aId = ra.userId;
    b = rb.client;
    bId = rb.userId;
    keysA = KeyService(client: a, encryption: EncryptionService());
    keysB = KeyService(client: b, encryption: EncryptionService());

    // Both users need a published key before A can initiate a conversation key.
    await keysA.ensureOwnKeyPair();
    await keysB.ensureOwnKeyPair();

    // A fresh conversation per run so the initiator path is always exercised.
    conversationId = await a.rpc('create_conversation', params: {
      'p_name': null,
      'p_member_ids': [aId, bId],
    }) as String;
  });

  tearDownAll(() async {
    await a.auth.signOut();
    await b.auth.signOut();
  });

  group('ensureOwnKeyPair', () {
    test('is idempotent and leaves exactly one active public key', () async {
      final first = await keysA.ensureOwnKeyPair();
      final second = await keysA.ensureOwnKeyPair();

      expect(second.publicKey, first.publicKey);
      expect(second.privateKey, first.privateKey);

      final active = await a
          .from('user_keys')
          .select('public_key')
          .eq('user_id', aId)
          .isFilter('retired_at', null) as List;
      expect(active.length, 1);
      expect(active.first['public_key'], first.publicKey);
    });

    test('uploads only the public key — the private key never appears in '
        'user_keys', () async {
      final own = await keysA.ensureOwnKeyPair();

      final rows =
          await a.from('user_keys').select().eq('user_id', aId) as List;
      for (final row in rows) {
        expect(row.values.contains(own.privateKey), isFalse,
            reason: 'private key must never leave the device');
      }
    });
  });

  group('conversation key distribution (§7)', () {
    test('initiator writes a wrapped row for EVERY member; both sides unwrap '
        'to the same key', () async {
      final keyA = await keysA.getConversationKey(conversationId);
      final keyB = await keysB.getConversationKey(conversationId);

      expect(keyB, keyA,
          reason: 'recipient must unwrap to the key the initiator generated');

      // The initiator (A) wrote B's row — the member-scoped INSERT policy at
      // work. B sees exactly one active row: their own (select-own RLS).
      final bRows = await b
          .from('conversation_keys')
          .select('user_id')
          .eq('conversation_id', conversationId)
          .isFilter('retired_at', null) as List;
      expect(bRows.length, 1);
      expect(bRows.first['user_id'], bId);
    });

    test('server holds only WRAPPED keys — never the plaintext conversation '
        'key (invariant 1)', () async {
      final keyA = await keysA.getConversationKey(conversationId);

      final row = await a
          .from('conversation_keys')
          .select('encrypted_conversation_key')
          .eq('conversation_id', conversationId)
          .eq('user_id', aId)
          .isFilter('retired_at', null)
          .single();
      final stored = row['encrypted_conversation_key'] as String;

      expect(stored, isNot(equals(keyA)));
      expect(stored.contains(keyA), isFalse);
    });

    test("A cannot read B's conversation_keys row (select-own RLS)", () async {
      final rows = await a
          .from('conversation_keys')
          .select()
          .eq('conversation_id', conversationId)
          .eq('user_id', bId) as List;
      expect(rows, isEmpty);
    });

    test("a conversation-mate still cannot read user_private — invariant 3 in "
        'the shared-conversation state', () async {
      // A and B DO share a conversation here — the state the identity test
      // deliberately avoids, and the one where the user_private split is
      // load-bearing.
      final rows =
          await a.from('user_private').select().eq('user_id', bId) as List;
      expect(rows, isEmpty,
          reason: 'phone_hash / recovery_email must stay sealed even from '
              'conversation-mates');
    });

    test('ANY direct client insert into conversation_keys is rejected — key '
        'rows are RPC-only (closes first-write poisoning)', () async {
      // Before a key exists, a member could otherwise pre-plant a garbage row
      // for a victim (or themselves) and permanently brick the conversation's
      // key distribution. With no INSERT policy, the first write and every
      // write goes through distribute_conversation_keys.
      final freshConv = await b.rpc('create_conversation', params: {
        'p_name': null,
        'p_member_ids': [aId, bId],
      }) as String;

      await expectLater(
        b.from('conversation_keys').insert({
          'conversation_id': freshConv,
          'user_id': aId,
          'encrypted_conversation_key': 'poison',
        }),
        throwsA(isA<PostgrestException>()),
      );
      await expectLater(
        b.from('conversation_keys').insert({
          'conversation_id': freshConv,
          'user_id': bId,
          'encrypted_conversation_key': 'poison-own-row',
        }),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('the RPC refuses a distribution that is not exactly the active '
        'member set (no partial, no extras)', () async {
      final rc = await signIn(phoneC, 'Olive');
      try {
        final freshConv = await a.rpc('create_conversation', params: {
          'p_name': null,
          'p_member_ids': [aId, bId],
        }) as String;

        // Partial: only A's row — would lock B out.
        await expectLater(
          a.rpc('distribute_conversation_keys', params: {
            'p_conversation_id': freshConv,
            'p_keys': [
              {'user_id': aId, 'encrypted_conversation_key': 'wrapped-a'},
            ],
          }),
          throwsA(isA<PostgrestException>()),
        );

        // Extra: includes C, who is not a member.
        await expectLater(
          a.rpc('distribute_conversation_keys', params: {
            'p_conversation_id': freshConv,
            'p_keys': [
              {'user_id': aId, 'encrypted_conversation_key': 'wrapped-a'},
              {'user_id': bId, 'encrypted_conversation_key': 'wrapped-b'},
              {
                'user_id': rc.userId,
                'encrypted_conversation_key': 'wrapped-c',
              },
            ],
          }),
          throwsA(isA<PostgrestException>()),
        );
      } finally {
        await rc.client.auth.signOut();
      }
    });

    test('the RPC refuses re-distribution over an existing active key', () {
      // The main conversation was keyed by the distribution test above.
      return expectLater(
        a.rpc('distribute_conversation_keys', params: {
          'p_conversation_id': conversationId,
          'p_keys': [
            {'user_id': aId, 'encrypted_conversation_key': 'late-a'},
            {'user_id': bId, 'encrypted_conversation_key': 'late-b'},
          ],
        }),
        throwsA(isA<PostgrestException>()),
      );
    });
  });
}
