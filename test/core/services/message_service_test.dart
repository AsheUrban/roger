import 'package:flutter_test/flutter_test.dart';

void main() {
  // 6b-3 built the note spine (sendNote / getMessages / watchMessages) — those
  // hit real Supabase and are proven by integration_test/security/
  // note_e2ee_test.dart plus the on-device smoke. Row parsing and the type
  // mapping are unit-covered in test/core/models/message_test.dart.
  group('MessageService — note spine',
      skip: 'Integration test — needs real Supabase '
          '(see integration_test/security/note_e2ee_test.dart)', () {
    test('sendNote inserts an encrypted note row (type note, no r2_key) and '
        'returns the stored message', () {});

    test('getMessages returns the conversation messages ascending by '
        'created_at', () {});

    test('watchMessages emits the current list, then again on every insert',
        () {});
  });

  group('MessageService — video/photo', skip: 'feature not built — step 6c',
      () {
    test('sendVideo creates message with type video and r2Key', () {});

    test('sendPhoto creates message with type photo', () {});

    test('sendPhoto supports optional voice overlay', () {});
  });

  group('MessageService — content actions',
      skip: 'feature not built — step 6c', () {
    test('deleteMessage purges R2 and notifies all members', () {});

    test('forwardMessage re-encrypts with target conversation key', () {});

    test('downloadDecrypted returns plaintext bytes for camera roll save',
        () {});
  });

  group('MessageService — views', skip: 'feature not built — step 11', () {
    test('markDownloaded records download timestamp', () {});

    test('markViewed records view timestamp', () {});
  });

  group('MessageService — reactions', skip: 'feature not built — step 7', () {
    test('sendEmojiReaction attaches emoji to message', () {});

    test('sendVideoReaction attaches video to parent message', () {});

    test('video reactions cannot be nested (depth capped at 1)', () {});
  });

  group('MessageService — rolling window',
      skip: 'feature not built — step 13', () {
    test('enforceRollingWindow deletes oldest messages beyond limit', () {});

    test('reactions do not count toward rolling window', () {});
  });
}
