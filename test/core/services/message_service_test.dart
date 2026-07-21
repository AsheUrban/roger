import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MessageService', skip: 'feature not built — step 6', () {
    group('send', () {
      test('sendVideo creates message with type video and r2Key', () {});

      test('sendPhoto creates message with type photo', () {});

      test('sendPhoto supports optional voice overlay', () {});

      test('sendNote creates message with type note and encrypted text', () {});
    });

    group('retrieve', () {
      test('getMessages returns messages for conversation', () {});

      test('watchMessages streams real-time updates', () {});
    });

    group('content actions', () {
      test('deleteMessage purges R2 and notifies all members', () {});

      test('forwardMessage re-encrypts with target conversation key', () {});

      test('downloadDecrypted returns plaintext bytes for camera roll save',
          () {});
    });

    group('views', () {
      test('markDownloaded records download timestamp', () {});

      test('markViewed records view timestamp', () {});
    });

    group('reactions', () {
      test('sendEmojiReaction attaches emoji to message', () {});

      test('sendVideoReaction attaches video to parent message', () {});

      test('video reactions cannot be nested (depth capped at 1)', () {});
    });

    group('rolling window', () {
      test('enforceRollingWindow deletes oldest messages beyond limit', () {});

      test('reactions do not count toward rolling window', () {});
    });
  });
}
