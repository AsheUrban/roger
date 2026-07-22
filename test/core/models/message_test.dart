import 'package:flutter_test/flutter_test.dart';
import 'package:roger/core/models/message.dart';

// Message model becomes real in Camera 6b-3 (the note spine). Contracts:
//   * schema alignment — sender_id and r2_expires_at are nullable in the DB
//     (sender SET NULL on account delete; notes never touch R2), so the model
//     carries String? / DateTime?.
//   * type mapping — DB stores snake_case 'call_chunk'; Dart enum is callChunk
//     (the other three match). Tracked since the 5/31 whole-project read.
//   * fromRow — parses a Supabase messages row.
//   * value equality — needed by CameraState (thumbnails listEquals).

Message _message({
  String id = 'm-1',
  String conversationId = 'conv-1',
  String? senderId = 'u-1',
  MessageType type = MessageType.note,
  String? r2Key,
  String? encryptedText = 'cipher',
  DateTime? r2ExpiresAt,
  DateTime? createdAt,
}) {
  return Message(
    id: id,
    conversationId: conversationId,
    senderId: senderId,
    type: type,
    r2Key: r2Key,
    encryptedText: encryptedText,
    r2ExpiresAt: r2ExpiresAt,
    createdAt: createdAt ?? DateTime(2026, 7, 22),
  );
}

void main() {
  group('MessageType db mapping', () {
    test('maps callChunk to call_chunk and back; others match verbatim', () {
      expect(MessageType.video.dbValue, 'video');
      expect(MessageType.photo.dbValue, 'photo');
      expect(MessageType.note.dbValue, 'note');
      expect(MessageType.callChunk.dbValue, 'call_chunk');

      for (final type in MessageType.values) {
        expect(messageTypeFromDb(type.dbValue), type);
      }
    });

    test('an unknown db value throws (schema CHECK should make it impossible)',
        () {
      expect(() => messageTypeFromDb('gif'), throwsA(anything));
    });
  });

  group('Message.fromRow', () {
    test('parses a note row (no r2 fields, no expiry)', () {
      final message = Message.fromRow({
        'id': 'm-1',
        'conversation_id': 'conv-1',
        'sender_id': 'u-1',
        'type': 'note',
        'r2_key': null,
        'voice_overlay_r2_key': null,
        'encrypted_text': 'ciphertext',
        'call_session_id': null,
        'r2_expires_at': null,
        'nudge_sent_at': null,
        'created_at': '2026-07-22T12:00:00.000Z',
      });

      expect(message.id, 'm-1');
      expect(message.conversationId, 'conv-1');
      expect(message.senderId, 'u-1');
      expect(message.type, MessageType.note);
      expect(message.r2Key, isNull);
      expect(message.encryptedText, 'ciphertext');
      expect(message.r2ExpiresAt, isNull);
      expect(message.createdAt, DateTime.utc(2026, 7, 22, 12));
    });

    test('parses a call_chunk row to MessageType.callChunk', () {
      final message = Message.fromRow({
        'id': 'm-2',
        'conversation_id': 'conv-1',
        'sender_id': 'u-1',
        'type': 'call_chunk',
        'created_at': '2026-07-22T12:00:00.000Z',
      });

      expect(message.type, MessageType.callChunk);
    });

    test('a deleted sender (sender_id null) parses instead of crashing', () {
      final message = Message.fromRow({
        'id': 'm-3',
        'conversation_id': 'conv-1',
        'sender_id': null,
        'type': 'note',
        'encrypted_text': 'ciphertext',
        'created_at': '2026-07-22T12:00:00.000Z',
      });

      expect(message.senderId, isNull);
    });
  });

  group('Message equality', () {
    test('two instances with the same field values are equal', () {
      final a = _message();
      final b = _message();
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('not equal when any identifying field differs', () {
      expect(_message(id: 'm-1'), isNot(equals(_message(id: 'm-2'))));
      expect(_message(conversationId: 'conv-1'),
          isNot(equals(_message(conversationId: 'conv-2'))));
      expect(_message(senderId: 'u-1'),
          isNot(equals(_message(senderId: null))));
      expect(_message(type: MessageType.note),
          isNot(equals(_message(type: MessageType.video))));
      expect(_message(encryptedText: 'a'),
          isNot(equals(_message(encryptedText: 'b'))));
      expect(_message(createdAt: DateTime(2026, 7, 22)),
          isNot(equals(_message(createdAt: DateTime(2026, 7, 23)))));
    });
  });
}
