import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthService', () {
    group('sendOtp', () {
      test('sends OTP to valid phone number', () {
        fail('not implemented');
      });

      test('OTP expires after 10 minutes', () {
        fail('not implemented');
      });
    });

    group('verifyOtp', () {
      test('returns user on correct OTP', () {
        fail('not implemented');
      });

      test('returns null on incorrect OTP', () {
        fail('not implemented');
      });

      test('resets after 5 failed attempts', () {
        fail('not implemented');
      });

      test('expired OTP never authenticates', () {
        fail('not implemented');
      });
    });

    group('createAccount', () {
      test('requires phone number, display name, and avatar color', () {
        fail('not implemented');
      });

      test('existing phone number logs in instead of creating duplicate', () {
        fail('not implemented');
      });
    });

    group('updatePhoneNumber', () {
      test('requires OTP verification of new number', () {
        fail('not implemented');
      });
    });
  });
}
