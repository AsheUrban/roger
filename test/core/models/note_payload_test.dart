import 'package:flutter_test/flutter_test.dart';
import 'package:roger/core/models/note_payload.dart';
import 'package:roger/core/services/encryption_service.dart';

// The note payload (Camera 6b). A note's background and text colors are
// content, not metadata — they must ride INSIDE the encrypted payload, never as
// plaintext columns (spec §18 invariant 1: no plaintext content server-side).
// So `messages.encrypted_text` holds the ciphertext of this JSON envelope:
// {text, backgroundColor, textColor}, colors as ARGB ints (render-exact, no
// palette-name lookup).

void main() {
  group('NotePayload', () {
    test('JSON round-trip preserves text and both colors', () {
      const payload = NotePayload(
        text: 'note text',
        backgroundColor: 0xFF1E1D18,
        textColor: 0xFFFAFAF5,
      );

      final decoded = NotePayload.fromJsonString(payload.toJsonString());

      expect(decoded.text, 'note text');
      expect(decoded.backgroundColor, 0xFF1E1D18);
      expect(decoded.textColor, 0xFFFAFAF5);
    });

    test('round-trips emoji, newlines, and quotes in the text', () {
      const payload = NotePayload(
        text: 'she said "hi"\nthen 🎉\\done',
        backgroundColor: 0xFFFF6B4E,
        textColor: 0xFF2E0A0A,
      );

      final decoded = NotePayload.fromJsonString(payload.toJsonString());

      expect(decoded, payload);
    });

    test('value equality on all fields', () {
      const a = NotePayload(
          text: 't', backgroundColor: 0xFF000000, textColor: 0xFFFFFFFF);
      const b = NotePayload(
          text: 't', backgroundColor: 0xFF000000, textColor: 0xFFFFFFFF);
      const differentText = NotePayload(
          text: 'x', backgroundColor: 0xFF000000, textColor: 0xFFFFFFFF);
      const differentBg = NotePayload(
          text: 't', backgroundColor: 0xFF111111, textColor: 0xFFFFFFFF);
      const differentFg = NotePayload(
          text: 't', backgroundColor: 0xFF000000, textColor: 0xFFEEEEEE);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(differentText)));
      expect(a, isNot(equals(differentBg)));
      expect(a, isNot(equals(differentFg)));
    });

    test('malformed JSON throws (never silently renders a broken note)', () {
      expect(() => NotePayload.fromJsonString('not json'), throwsA(anything));
      expect(() => NotePayload.fromJsonString('{"text": "only"}'),
          throwsA(anything));
    });

    test('full spine: encode → encrypt → decrypt → decode returns the '
        'original note', () async {
      final service = EncryptionService();
      final key = await service.generateConversationKey();
      const payload = NotePayload(
        text: 'the whole point of 6b 📝',
        backgroundColor: 0xFF595900,
        textColor: 0xFFE8E600,
      );

      final ciphertext = await service.encryptText(
        plaintext: payload.toJsonString(),
        conversationKey: key,
      );
      final decoded = NotePayload.fromJsonString(
        await service.decryptText(ciphertext: ciphertext, conversationKey: key),
      );

      expect(decoded, payload);
    });
  });
}
