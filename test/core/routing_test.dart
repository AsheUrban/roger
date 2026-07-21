import 'package:flutter_test/flutter_test.dart';
import 'package:roger/core/auth_state.dart';
import 'package:roger/main.dart';

// J (cached auth state) — the router redirect is now a pure synchronous
// function of AuthState + path. See LOG_5_29.md.
//
// Under the combined-seed design the auth state is always resolved
// (NeedsOnboarding | Onboarded) before the first frame, because `main()`
// awaits `Supabase.initialize` and the notifier seeds synchronously from
// `currentSession`. There is no runtime "checking" window, so AuthState has
// two variants and the redirect never needs a transient null-while-checking
// branch. (Earlier framing carried a third `Checking` variant; dropped as
// unreachable — see LOG_5_29 "Refinements from writing the tests".)

void main() {
  group('routerRedirect', () {
    group('NeedsOnboarding', () {
      test('on /conversations redirects to /onboarding', () {
        expect(
          routerRedirect(
              authState: const AuthStateNeedsOnboarding(),
              path: '/conversations'),
          '/onboarding',
        );
      });

      test('on /search redirects to /onboarding', () {
        expect(
          routerRedirect(
              authState: const AuthStateNeedsOnboarding(), path: '/search'),
          '/onboarding',
        );
      });

      test('on /camera/:id redirects to /onboarding', () {
        expect(
          routerRedirect(
              authState: const AuthStateNeedsOnboarding(),
              path: '/camera/abc'),
          '/onboarding',
        );
      });

      test('on /onboarding stays (no redirect)', () {
        expect(
          routerRedirect(
              authState: const AuthStateNeedsOnboarding(), path: '/onboarding'),
          isNull,
        );
      });
    });

    group('Onboarded', () {
      test('on /onboarding redirects to /conversations', () {
        expect(
          routerRedirect(
              authState: const AuthStateOnboarded(), path: '/onboarding'),
          '/conversations',
        );
      });

      test('on /conversations stays', () {
        expect(
          routerRedirect(
              authState: const AuthStateOnboarded(), path: '/conversations'),
          isNull,
        );
      });

      test('on /search stays', () {
        expect(
          routerRedirect(
              authState: const AuthStateOnboarded(), path: '/search'),
          isNull,
        );
      });

      test('on /camera/:id stays', () {
        expect(
          routerRedirect(
              authState: const AuthStateOnboarded(), path: '/camera/abc'),
          isNull,
        );
      });
    });

    group('no redirect loop (idempotent on its own target)', () {
      test('NeedsOnboarding: redirect to /onboarding, then stays there', () {
        final target = routerRedirect(
            authState: const AuthStateNeedsOnboarding(),
            path: '/conversations');
        expect(target, '/onboarding');
        expect(
          routerRedirect(
              authState: const AuthStateNeedsOnboarding(), path: target!),
          isNull,
        );
      });

      test('Onboarded: redirect to /conversations, then stays there', () {
        final target = routerRedirect(
            authState: const AuthStateOnboarded(), path: '/onboarding');
        expect(target, '/conversations');
        expect(
          routerRedirect(
              authState: const AuthStateOnboarded(), path: target!),
          isNull,
        );
      });
    });
  });
}
