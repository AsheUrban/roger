import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Message model', skip: 'feature not built — step 6', () {
    test('type must be video, photo, note, or call_chunk', () {});

    test('r2Key is nullable (notes have no blob)', () {});

    test('voiceOverlayR2Key only applies to photo messages', () {});

    test('encryptedText only applies to note messages', () {});

    test('callSessionId only applies to call_chunk messages', () {});

    test('r2ExpiresAt defaults to createdAt + 60 days', () {});
  });
}
