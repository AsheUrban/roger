import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthService', skip: 'Integration test — needs real Supabase', () {
    group('sendOtp', () {
      test('sends OTP to valid phone number', () {});
    });

    group('verifyOtp', () {
      test('verifies OTP and authenticates user', () {});

      test('rejects invalid OTP code', () {});
    });

    group('getCurrentUser', () {
      test('returns user if public.users row exists', () {});

      test('returns null if no public.users row', () {});
    });

    group('createAccount', () {
      test('requires phone number and avatar color', () {});

      test('existing phone number logs in instead of creating duplicate',
          () {});
    });

    group('updatePhoneNumber', () {
      test('updates phone number after OTP verification', () {});
    });

    group('updateRecoveryEmail', () {
      test('updates recovery email', () {});
    });
  });
}
