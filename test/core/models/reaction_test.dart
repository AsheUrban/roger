import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReactionEmoji model', skip: 'feature not built — step 7', () {
    test('requires messageId, userId, and emoji', () {});
  });

  group('ReactionVideo model', skip: 'feature not built — step 7', () {
    test('requires parentMessageId, senderId, and r2Key', () {});

    test('inherits parent message R2 lifecycle (no separate expiry)', () {});
  });
}
