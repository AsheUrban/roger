import 'package:flutter_test/flutter_test.dart';
import 'package:roger/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('Router redirect', () {
    Session makeSession() {
      return Session(
        accessToken: 'test-token',
        tokenType: 'bearer',
        user: User(
          id: 'test-user-id',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
    }

    test('unauthenticated user on /conversations redirected to /onboarding',
        () async {
      final result = await routerRedirect(
        session: null,
        hasUsersRow: (_) async => false,
        path: '/conversations',
      );
      expect(result, '/onboarding');
    });

    test('unauthenticated user on /onboarding stays on /onboarding', () async {
      final result = await routerRedirect(
        session: null,
        hasUsersRow: (_) async => false,
        path: '/onboarding',
      );
      expect(result, isNull);
    });

    test(
        'authenticated user without users row on /conversations redirected to /onboarding',
        () async {
      final result = await routerRedirect(
        session: makeSession(),
        hasUsersRow: (_) async => false,
        path: '/conversations',
      );
      expect(result, '/onboarding');
    });

    test('fully onboarded user on /onboarding redirected to /conversations',
        () async {
      final result = await routerRedirect(
        session: makeSession(),
        hasUsersRow: (_) async => true,
        path: '/onboarding',
      );
      expect(result, '/conversations');
    });

    test('fully onboarded user on /conversations stays', () async {
      final result = await routerRedirect(
        session: makeSession(),
        hasUsersRow: (_) async => true,
        path: '/conversations',
      );
      expect(result, isNull);
    });

    test('fully onboarded user on /search stays', () async {
      final result = await routerRedirect(
        session: makeSession(),
        hasUsersRow: (_) async => true,
        path: '/search',
      );
      expect(result, isNull);
    });
  });
}
