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

      // Atomicity (Gap 1, LOG_5_31): createAccount calls the create_account
      // RPC (migration 00004), which inserts the users and user_settings rows
      // in one transaction. A failure must leave NEITHER row — never an
      // orphaned users row with no settings.
      test('atomic — a failed account creation leaves no users or settings row',
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
