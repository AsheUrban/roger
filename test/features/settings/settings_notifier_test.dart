import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SettingsNotifier', skip: 'feature not built — step 8', () {
    test('loadSettings populates user and settings state', () {});

    test('updatePhoneNumber requires OTP verification to the new number', () {});

    test('updateAvatarColor changes color globally', () {});

    group('message storage', () {
      test('updateMessageLimit to lower value prompts confirmation', () {});

      test('updateMessageLimit to higher value takes effect immediately', () {});

      test('messageLimit must be between 10 and 500', () {});
    });

    group('disappearing messages', () {
      test('toggling on stores pre_disappearing_limit', () {});

      test('toggling off restores previous limit', () {});

      test('toggling on prompts to clear existing messages', () {});
    });

    group('account actions', () {
      test('signOut requires confirmation', () {});

      test('deleteAccount purges all data', () {});

      test('deleteAccount in group creates new thread for remaining members',
          () {});

      test('deleteAccount in 1:1 ends conversation', () {});
    });
  });
}
