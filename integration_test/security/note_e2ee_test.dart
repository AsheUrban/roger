// Note E2EE spine (Camera 6b) against REAL Supabase — proves §18 invariant 1
// for the first message type: the server stores CIPHERTEXT only. A note's
// text AND colors ride inside the encrypted payload; the messages row exposes
// nothing readable.
//
// Full stack, no mocks: KeyService (key distribution) → EncryptionService
// (AES-256-GCM) → MessageService (Postgres row + realtime stream).
//
// Run (emulator only — always pass -d):
//   flutter test integration_test/security/note_e2ee_test.dart \
//     -d emulator-5554 --dart-define-from-file=.env
//
// Uses test users A + B (harness.dart). STATE CAVEAT: each run creates one
// fresh A+B conversation plus its note rows (clients can't delete
// conversations — no DELETE policy, by design); wipe via the SQL editor when
// they get annoying.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:roger/core/models/message.dart';
import 'package:roger/core/models/note_payload.dart';
import 'package:roger/core/services/encryption_service.dart';
import 'package:roger/core/services/key_service.dart';
import 'package:roger/core/services/message_service.dart';

import 'harness.dart';

const _noteText = 'private note: the whole point of roger 📝';
const _payload = NotePayload(
  text: _noteText,
  backgroundColor: 0xFF595900,
  textColor: 0xFFE8E600,
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late SupabaseClient a;
  late SupabaseClient b;
  late String aId;
  late String conversationId;
  late KeyService keysA;
  late KeyService keysB;
  final encryption = EncryptionService();

  setUpAll(() async {
    final ra = await signIn(phoneA, 'Deep Red');
    final rb = await signIn(phoneB, 'Cornflower');
    a = ra.client;
    aId = ra.userId;
    b = rb.client;
    keysA = KeyService(client: a, encryption: encryption);
    keysB = KeyService(client: b, encryption: encryption);
    await keysA.ensureOwnKeyPair();
    await keysB.ensureOwnKeyPair();

    conversationId = await a.rpc('create_conversation', params: {
      'p_name': null,
      'p_member_ids': [aId, rb.userId],
    }) as String;
  });

  tearDownAll(() async {
    await a.auth.signOut();
    await b.auth.signOut();
  });

  Future<Message> sendNoteAsA() async {
    final key = await keysA.getConversationKey(conversationId);
    final ciphertext = await encryption.encryptText(
      plaintext: _payload.toJsonString(),
      conversationKey: key,
    );
    return MessageService(client: a)
        .sendNote(conversationId: conversationId, encryptedText: ciphertext);
  }

  group('Invariant 1 — no plaintext content server-side (notes)', () {
    test('the stored row is ciphertext: no note text, no payload structure, '
        'type note with no r2 fields', () async {
      final sent = await sendNoteAsA();

      final row =
          await a.from('messages').select().eq('id', sent.id).single();

      expect(row['type'], 'note');
      expect(row['r2_key'], isNull, reason: 'notes never touch R2');
      final stored = row['encrypted_text'] as String;
      expect(stored, isNotEmpty);
      expect(stored.contains(_noteText), isFalse,
          reason: 'server must never see the note text');
      expect(stored.contains('"text"'), isFalse,
          reason: 'server must not even see the payload JSON structure');
      expect(stored, isNot(equals(_payload.toJsonString())));
    });

    test('the recipient fetches and decrypts to the exact composed note '
        '(text + colors)', () async {
      final sent = await sendNoteAsA();

      final fetched = await MessageService(client: b)
          .getMessages(conversationId: conversationId);
      final received = fetched.firstWhere((m) => m.id == sent.id);

      final keyB = await keysB.getConversationKey(conversationId);
      final decoded = NotePayload.fromJsonString(
        await encryption.decryptText(
          ciphertext: received.encryptedText!,
          conversationKey: keyB,
        ),
      );

      expect(decoded, _payload);
      expect(received.senderId, aId);
    });

    test('realtime: a note sent by A arrives on B\'s message stream', () async {
      final stream =
          MessageService(client: b).watchMessages(conversationId: conversationId);

      // Subscribe first, then send. The predicate waits for the specific new
      // id — the initial snapshot (which already holds this run's earlier
      // notes) can't satisfy it early.
      String? sentId;
      final arrival = stream.firstWhere(
        (messages) =>
            sentId != null && messages.any((m) => m.id == sentId),
      );

      final sent = await sendNoteAsA();
      sentId = sent.id;

      final messages = await arrival.timeout(const Duration(seconds: 30));
      expect(messages.map((m) => m.id), contains(sent.id));
    });
  });
}
