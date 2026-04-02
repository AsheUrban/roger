import 'package:flutter_test/flutter_test.dart';

void main() {
  // OnboardingScreen creates AuthService and ContactsService internally,
  // which depend on Supabase.instance. Widget tests need dependency
  // injection via Riverpod providers so we can substitute mocks.
  // All tests skipped until the Riverpod conversion.

  group('OnboardingScreen', () {
    test('renders email input on emailEntry step',
        skip: 'Requires Supabase mock injection via Riverpod.', () {});

    test('renders awaiting email screen on awaitingEmail step',
        skip: 'Requires Supabase mock injection via Riverpod.', () {});

    test('renders phone number input on phoneNumber step',
        skip: 'Requires Supabase mock injection via Riverpod.', () {});

    test('renders display name input on displayName step',
        skip: 'Requires Supabase mock injection via Riverpod.', () {});

    test('renders contacts permission request',
        skip: 'Requires Supabase mock injection via Riverpod.', () {});
  });
}
