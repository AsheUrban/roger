import 'package:flutter_test/flutter_test.dart';
import 'package:roger/core/auth_state.dart';

// J (cached auth state) — AuthState is a sealed class. See LOG_5_29.md.
// Two variants for now; sealed (not enum/bool) so AuthStateOnboarded can carry
// a User in Step 8 and a future SessionExpired arm can be added additively,
// with the compiler walking every switch.

void main() {
  group('AuthState', () {
    test('const variants of the same type are equal', () {
      expect(const AuthStateNeedsOnboarding(),
          equals(const AuthStateNeedsOnboarding()));
      expect(const AuthStateOnboarded(), equals(const AuthStateOnboarded()));
    });

    test('different variants are not equal', () {
      expect(
        const AuthStateNeedsOnboarding(),
        isNot(equals(const AuthStateOnboarded())),
      );
    });

    test('switch over AuthState is exhaustive at compile time', () {
      // No `default` arm: adding a variant without updating every switch is a
      // compile error. That exhaustiveness is the reason for a sealed class
      // over a plain bool here.
      String label(AuthState s) => switch (s) {
            AuthStateNeedsOnboarding() => 'needs',
            AuthStateOnboarded() => 'onboarded',
          };
      expect(label(const AuthStateNeedsOnboarding()), 'needs');
      expect(label(const AuthStateOnboarded()), 'onboarded');
    });
  });
}
