// §9 group prerequisite (replied 1:1) against REAL Supabase, 2026-07-25.
//
// create_conversation only creates a GROUP (3+ members) when every non-caller
// member has REPLIED to the caller in a 1:1 — a conversation with exactly two
// member rows where the member's first_message_at is set. first_message_at is
// stamped by a trigger on a member's first message and never cleared. 1:1
// creation stays ungated. The Search picker prevents this path for honest
// users; these tests prove the server boundary that a modified client hits.
//
// Run (emulator only — always pass -d):
//   flutter test integration_test/security/group_gate_test.dart \
//     -d emulator-5554 --dart-define-from-file=.env
//
// Uses test users A (creator), B (replied), C (starts silent). STATE CAVEATS:
// creates a handful of A+B / A+C conversations (clients can't delete
// conversations — no DELETE policy, by design) and burns a few units of the
// A→B / A→C add allowance (5 per pair per 12h) — do NOT run back-to-back with
// add_limit_test.dart in the same 12h window, and reset via the SQL editor if
// a run rejects unexpectedly:
//   delete from conversation_add_limit;
// Message rows inserted here are direct ciphertext-free placeholders ('x') —
// fine for the dev DB, they only exist to fire the stamp trigger.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'harness.dart';

Future<String> _create(SupabaseClient client, List<String> memberIds) async {
  return await client.rpc('create_conversation', params: {
    'p_name': null,
    'p_member_ids': memberIds,
  }) as String;
}

Future<void> _sendPlaceholderMessage(
  SupabaseClient client,
  String conversationId,
) async {
  await client.from('messages').insert({
    'conversation_id': conversationId,
    'sender_id': client.auth.currentUser!.id,
    'type': 'note',
    'encrypted_text': 'x',
  });
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late SupabaseClient a;
  late SupabaseClient b;
  late SupabaseClient c;
  late String aId;
  late String bId;
  late String cId;

  setUpAll(() async {
    final ra = await signIn(phoneA, 'Deep Red');
    final rb = await signIn(phoneB, 'Cornflower');
    final rc = await signIn(phoneC, 'Olive');
    a = ra.client;
    aId = ra.userId;
    b = rb.client;
    bId = rb.userId;
    c = rc.client;
    cId = rc.userId;
  });

  tearDownAll(() async {
    await a.auth.signOut();
    await b.auth.signOut();
    await c.auth.signOut();
  });

  group('first_message_at trigger', () {
    test('a member\'s first message stamps their own membership row once',
        () async {
      final convId = await _create(a, [aId, bId]);

      var rows = await a
          .from('conversation_members')
          .select('user_id, first_message_at')
          .eq('conversation_id', convId) as List;
      expect(rows.every((r) => r['first_message_at'] == null), isTrue,
          reason: 'no one has posted yet');

      await _sendPlaceholderMessage(b, convId);

      rows = await a
          .from('conversation_members')
          .select('user_id, first_message_at')
          .eq('conversation_id', convId) as List;
      final bRow = rows.firstWhere((r) => r['user_id'] == bId);
      final aRow = rows.firstWhere((r) => r['user_id'] == aId);
      expect(bRow['first_message_at'], isNotNull,
          reason: 'the sender\'s row is stamped');
      expect(aRow['first_message_at'], isNull,
          reason: 'only the sender is stamped — a partner\'s messages never '
              'mark YOU as having replied');
    });

    test('first_message_at is not client-writable (column-restricted update)',
        () async {
      final convId = await _create(a, [aId, bId]);

      await expectLater(
        a
            .from('conversation_members')
            .update({'first_message_at': DateTime.now().toIso8601String()})
            .eq('conversation_id', convId)
            .eq('user_id', aId),
        throwsA(isA<PostgrestException>()),
        reason: 'the stamp is server-derived — a client must not be able to '
            'fake its own reply state',
      );
    });
  });

  group('group prerequisite (replied 1:1)', () {
    test('a group containing a member who has not replied to the caller is '
        'rejected; it succeeds after they reply', () async {
      // B has replied to A (trigger test above). C: fresh 1:1, silent so far.
      final acConv = await _create(a, [aId, cId]);
      await _sendPlaceholderMessage(a, acConv); // A speaking doesn't count

      await expectLater(
        _create(a, [aId, bId, cId]),
        throwsA(isA<PostgrestException>()),
        reason: 'C has never replied to A in a 1:1',
      );

      await _sendPlaceholderMessage(c, acConv); // C replies

      final groupId = await _create(a, [aId, bId, cId]);
      expect(groupId, isNotEmpty);
    });

    test('sharing a GROUP with the caller never satisfies the prerequisite — '
        'only a replied 1:1 does', () async {
      // B (in the group above, has posted in 1:1s with A) creates nothing
      // here; the subject is C→B: they share the group but no 1:1 at all.
      await expectLater(
        _create(c, [cId, bId, aId]),
        throwsA(isA<PostgrestException>()),
        reason: 'B has never replied to C in a 1:1 — group co-membership is '
            'not enough (closes the lateral vector)',
      );
    });

    test('1:1 creation stays ungated — no reply required to start a chat',
        () async {
      final convId = await _create(b, [bId, cId]);
      expect(convId, isNotEmpty,
          reason: 'a 1:1 is where a relationship starts');
    });
  });

  group('write hardening (fourth-pass review)', () {
    test('a member cannot DELETE their own membership row — rows are '
        'load-bearing for the gate and the true-1:1 rule', () async {
      final convId = await _create(a, [aId, bId]);

      // RLS-denied DELETE is a silent no-op, so assert persistence.
      await a
          .from('conversation_members')
          .delete()
          .eq('conversation_id', convId)
          .eq('user_id', aId);

      final rows = await a
          .from('conversation_members')
          .select('user_id')
          .eq('conversation_id', convId) as List;
      expect(rows.length, 2,
          reason: 'deleting a row would shrink a group into a "1:1" and '
              'erase first_message_at — must be impossible');
    });

    test('conversations UPDATE is name-only — created_at is not client-'
        'writable', () async {
      final convId = await _create(a, [aId, bId]);

      await expectLater(
        a
            .from('conversations')
            .update({'created_at': DateTime.now().toUtc().toIso8601String()})
            .eq('id', convId),
        throwsA(isA<PostgrestException>()),
      );

      await a.from('conversations').update({'name': 'renamed'}).eq(
          'id', convId);
      final row = await a
          .from('conversations')
          .select('name')
          .eq('id', convId)
          .single();
      expect(row['name'], 'renamed');
    });

    test('messages are immutable to clients — a sender cannot move their own '
        'message between conversations', () async {
      final convId = await _create(a, [aId, bId]);
      await _sendPlaceholderMessage(a, convId);
      final message = await a
          .from('messages')
          .select('id')
          .eq('conversation_id', convId)
          .limit(1)
          .single();

      await expectLater(
        a
            .from('messages')
            .update({'encrypted_text': 'rewritten'}).eq('id', message['id']),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('avatar_color only accepts the eight spec values', () async {
      await expectLater(
        a.from('users').update({'avatar_color': 'NotAColor'}).eq('id', aId),
        throwsA(isA<PostgrestException>()),
      );
    });
  });
}
