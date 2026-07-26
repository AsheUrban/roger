import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import 'package:roger/core/auth_notifier.dart';
import 'package:roger/core/auth_state.dart';
import 'package:roger/core/models/user.dart';
import 'package:roger/core/providers.dart';
import 'package:roger/core/services/auth_service.dart';
import 'package:roger/core/services/key_service.dart';

// J (cached auth state). See LOG_5_29.md for the full design.
//
// Contract these tests define for the AuthNotifier:
//  - build() reads AuthService.currentSession SYNCHRONOUSLY and seeds:
//      null session  -> AuthStateNeedsOnboarding
//      session present -> AuthStateOnboarded (optimistic)
//  - build() fires an async correction (Future.microtask): if a session is
//    present, call AuthService.getCurrentUser(). Correct DOWN to
//    NeedsOnboarding ONLY on a definitive null (authenticated, no public.users
//    row). Never up. ERROR-RESILIENT: on a thrown error (transient 401 mid
//    token-refresh, network failure) leave the optimistic Onboarded — don't
//    bounce a real returning user over a blip.
//  - build() subscribes to AuthService.authEvents and acts on signedOut ONLY
//    (-> NeedsOnboarding). signedIn / tokenRefreshed are ignored (Supabase
//    fires those on startup; reacting would clobber the correction).
//    Subscription cancelled via ref.onDispose.
//  - markOnboarded() -> AuthStateOnboarded (called by OnboardingNotifier on
//    account-creation success, before the imperative navigation).
//
// AuthService gains: `Session? get currentSession` and
// `Stream<AuthChangeEvent> get authEvents` (= onAuthStateChange.map((s) => s.event)).

class MockAuthService extends Mock implements AuthService {}

class MockKeyService extends Mock implements KeyService {}

supa.Session _session() => supa.Session(
      accessToken: 'test-token',
      tokenType: 'bearer',
      user: supa.User(
        id: 'auth-user-id',
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: '2026-01-01T00:00:00.000Z',
      ),
    );

User _appUser() => User(
      id: 'auth-user-id',
      avatarColor: 'Rust',
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  late MockAuthService authService;
  late MockKeyService keyService;
  late StreamController<supa.AuthChangeEvent> events;

  setUp(() {
    authService = MockAuthService();
    keyService = MockKeyService();
    events = StreamController<supa.AuthChangeEvent>.broadcast();
    when(() => authService.authEvents).thenAnswer((_) => events.stream);
    // Defaults: no session, no users row. Overridden per test.
    when(() => authService.currentSession).thenReturn(null);
    when(() => authService.getCurrentUser()).thenAnswer((_) async => null);
    when(() => keyService.ensureOwnKeyPair())
        .thenAnswer((_) async => (publicKey: 'pub', privateKey: 'priv'));
  });

  tearDown(() async {
    await events.close();
  });

  ProviderContainer makeContainer() => ProviderContainer.test(
        overrides: [
          authServiceProvider.overrideWithValue(authService),
          keyServiceProvider.overrideWithValue(keyService),
        ],
      );

  group('seed (synchronous, from currentSession)', () {
    test('no session seeds NeedsOnboarding', () {
      when(() => authService.currentSession).thenReturn(null);

      final container = makeContainer();

      expect(container.read(authProvider), const AuthStateNeedsOnboarding());
    });

    test('session present optimistically seeds Onboarded', () {
      when(() => authService.currentSession).thenReturn(_session());

      final container = makeContainer();

      expect(container.read(authProvider), const AuthStateOnboarded());
    });
  });

  group('async correction', () {
    test('session present but no users row corrects to NeedsOnboarding',
        () async {
      when(() => authService.currentSession).thenReturn(_session());
      when(() => authService.getCurrentUser()).thenAnswer((_) async => null);

      final container = makeContainer();
      // optimistic seed is visible first (this is the accepted edge-case flash)
      expect(container.read(authProvider), const AuthStateOnboarded());

      await pumpEventQueue();
      expect(container.read(authProvider), const AuthStateNeedsOnboarding());
    });

    test('session present with a users row stays Onboarded', () async {
      when(() => authService.currentSession).thenReturn(_session());
      when(() => authService.getCurrentUser())
          .thenAnswer((_) async => _appUser());

      final container = makeContainer();
      expect(container.read(authProvider), const AuthStateOnboarded()); // seed; build fires, correction queued
      await pumpEventQueue(); // correction confirms the row → stays Onboarded
      expect(container.read(authProvider), const AuthStateOnboarded());
    });

    test('no session skips the correction query entirely', () async {
      when(() => authService.currentSession).thenReturn(null);

      final container = makeContainer();
      container.read(authProvider);
      await pumpEventQueue();

      verifyNever(() => authService.getCurrentUser());
    });

    test('does NOT downgrade when getCurrentUser throws (transient error)',
        () async {
      when(() => authService.currentSession).thenReturn(_session());
      when(() => authService.getCurrentUser())
          .thenThrow(Exception('network'));

      final container = makeContainer();
      expect(container.read(authProvider), const AuthStateOnboarded());

      await pumpEventQueue();
      // Inconclusive check must leave the optimistic Onboarded — a real
      // returning user must not be bounced to onboarding over a blip.
      expect(container.read(authProvider), const AuthStateOnboarded());
    });
  });

  group('onAuthStateChange subscription (signedOut only)', () {
    test('signedOut transitions to NeedsOnboarding', () async {
      when(() => authService.currentSession).thenReturn(_session());
      when(() => authService.getCurrentUser())
          .thenAnswer((_) async => _appUser());

      final container = makeContainer();
      await pumpEventQueue();
      expect(container.read(authProvider), const AuthStateOnboarded());

      events.add(supa.AuthChangeEvent.signedOut);
      await pumpEventQueue();
      expect(container.read(authProvider), const AuthStateNeedsOnboarding());
    });

    test('signedIn / tokenRefreshed do NOT clobber a corrected state',
        () async {
      // session present but no row -> correction takes it to NeedsOnboarding
      when(() => authService.currentSession).thenReturn(_session());
      when(() => authService.getCurrentUser()).thenAnswer((_) async => null);

      final container = makeContainer();
      expect(container.read(authProvider), const AuthStateOnboarded()); // seed; build fires, correction queued
      await pumpEventQueue(); // correction runs → NeedsOnboarding (no row)
      expect(container.read(authProvider), const AuthStateNeedsOnboarding());

      // Supabase fires these on startup; reacting would re-flip to Onboarded
      // and undo the correction. They must be ignored.
      events.add(supa.AuthChangeEvent.signedIn);
      events.add(supa.AuthChangeEvent.tokenRefreshed);
      await pumpEventQueue();
      expect(container.read(authProvider), const AuthStateNeedsOnboarding());
    });
  });

  group('markOnboarded', () {
    test('flips state to Onboarded (called on onboarding completion)', () {
      when(() => authService.currentSession).thenReturn(null);

      final container = makeContainer();
      expect(container.read(authProvider), const AuthStateNeedsOnboarding());

      container.read(authProvider.notifier).markOnboarded();
      expect(container.read(authProvider), const AuthStateOnboarded());
    });
  });

  group('key publication (spec §7 — keys exist from account creation)', () {
    test('a confirmed onboarded user at launch publishes their key pair',
        () async {
      when(() => authService.currentSession).thenReturn(_session());
      when(() => authService.getCurrentUser())
          .thenAnswer((_) async => _appUser());

      final container = makeContainer();
      container.read(authProvider);
      await pumpEventQueue();

      verify(() => keyService.ensureOwnKeyPair()).called(1);
    });

    test('markOnboarded (new account just created) publishes the key pair',
        () async {
      when(() => authService.currentSession).thenReturn(null);

      final container = makeContainer();
      container.read(authProvider.notifier).markOnboarded();
      await pumpEventQueue();

      verify(() => keyService.ensureOwnKeyPair()).called(1);
    });

    test('no session → no key publication attempt', () async {
      when(() => authService.currentSession).thenReturn(null);

      final container = makeContainer();
      container.read(authProvider);
      await pumpEventQueue();

      verifyNever(() => keyService.ensureOwnKeyPair());
    });

    test('a stale session corrected to NeedsOnboarding does not publish',
        () async {
      when(() => authService.currentSession).thenReturn(_session());
      when(() => authService.getCurrentUser()).thenAnswer((_) async => null);

      final container = makeContainer();
      container.read(authProvider);
      await pumpEventQueue();

      verifyNever(() => keyService.ensureOwnKeyPair());
    });

    test('a failed publication is swallowed — retried lazily on the next '
        'launch / first send, never crashes auth', () async {
      when(() => authService.currentSession).thenReturn(_session());
      when(() => authService.getCurrentUser())
          .thenAnswer((_) async => _appUser());
      when(() => keyService.ensureOwnKeyPair())
          .thenThrow(Exception('offline'));

      final container = makeContainer();
      container.read(authProvider);
      await pumpEventQueue();

      expect(container.read(authProvider), const AuthStateOnboarded());
    });
  });
}
