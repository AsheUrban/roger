import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PendingInvite model', skip: 'feature not built — step 5', () {
    test('requires phoneNumber, invitingUserId, conversationId, messageId',
        () {});

    test('expiresAt is 7 days from creation', () {});

    test('nudgeSentAt is nullable (optional day-3 nudge)', () {});

    test('multiple users can invite the same phone number independently',
        () {});
  });
}
