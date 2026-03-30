import 'package:flutter_test/flutter_test.dart';

void main() {
  // OnboardingScreen creates AuthService and ContactsService internally,
  // which depend on Supabase.instance. Widget tests need dependency
  // injection via Riverpod providers so we can substitute mocks.
  // All tests skipped until the Riverpod conversion.

  group('OnboardingScreen', () {
    test('renders phone number input on phoneEntry step',
        skip: 'Requires Supabase mock injection via Riverpod.', () {});

    test('renders OTP input on otpVerification step',
        skip: 'Requires Supabase mock injection via Riverpod.', () {});

    test('renders display name input on displayName step',
        skip: 'Requires Supabase mock injection via Riverpod.', () {});

    test('renders 9 avatar color options on avatarColor step',
        skip: 'Requires Supabase mock injection via Riverpod.', () {});

    test('renders recovery email input with skip option',
        skip: 'Requires Supabase mock injection via Riverpod.', () {});

    test('shows consequence copy when skipping recovery email',
        skip: 'Requires Supabase mock injection via Riverpod.', () {});

    test('renders contacts permission request',
        skip: 'Requires Supabase mock injection via Riverpod.', () {});
  });
}
