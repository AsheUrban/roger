import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthService', () {
    group('sendMagicLink', () {
      test('sends magic link to valid email address', () {
        fail('not implemented');
      });
    });

    group('getCurrentUser', () {
      test('returns user if public.users row exists', () {
        fail('not implemented');
      });

      test('returns null if no public.users row', () {
        fail('not implemented');
      });
    });

    group('createAccount', () {
      test('requires email, phone number, display name, and avatar color', () {
        fail('not implemented');
      });

      test('existing email logs in instead of creating duplicate', () {
        fail('not implemented');
      });
    });

    group('isPhoneNumberTaken', () {
      test('returns true when phone number exists', () {
        fail('not implemented');
      });

      test('returns false when phone number is available', () {
        fail('not implemented');
      });
    });

    group('updatePhoneNumber', () {
      test('updates phone number directly (no OTP at MVP)', () {
        fail('not implemented');
      });
    });
  });
}
