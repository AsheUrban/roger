import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:roger/core/models/user.dart';
import 'package:roger/core/providers.dart';
import 'package:roger/core/services/auth_service.dart';
import 'package:roger/core/services/key_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:roger/features/onboarding/onboarding_notifier.dart';
import 'package:roger/features/onboarding/onboarding_state.dart';

class MockAuthService extends Mock implements AuthService {}

class MockKeyService extends Mock implements KeyService {}

class MockRandom extends Mock implements Random {}

class MockSession extends Mock implements Session {}

void main() {
  late MockAuthService authService;
  late MockKeyService keyService;
  late MockRandom random;
  late ProviderContainer container;
  late OnboardingNotifier notifier;

  // A User as createAccount returns on success (no phone number under the
  // privacy model).
  User newUserRow() => User(
        id: 'new-id',
        avatarColor: 'Deep Ember',
        createdAt: DateTime.now(),
      );

  setUp(() {
    authService = MockAuthService();
    keyService = MockKeyService();
    random = MockRandom();
    when(() => random.nextInt(any())).thenReturn(2); // → 'Deep Ember'
    when(() => authService.currentSession).thenReturn(null);
    when(() => authService.authEvents)
        .thenAnswer((_) => Stream<AuthChangeEvent>.empty());
    when(() => keyService.ensureOwnKeyPair())
        .thenAnswer((_) async => (publicKey: 'pub', privateKey: 'priv'));

    container = ProviderContainer.test(overrides: [
      authServiceProvider.overrideWithValue(authService),
      keyServiceProvider.overrideWithValue(keyService),
      randomProvider.overrideWithValue(random),
    ]);

    notifier = container.read(onboardingProvider.notifier);
  });

  Future<void> advanceToOtp() async {
    when(() => authService.sendOtp(any())).thenAnswer((_) async {});
    await notifier.sendOtp('+15550001000');
  }

  group('OnboardingNotifier', () {
    group('phone entry', () {
      test('sendOtp calls authService and advances to otpVerification',
          () async {
        when(() => authService.sendOtp('+15550001000'))
            .thenAnswer((_) async {});

        await notifier.sendOtp('+15550001000');

        verify(() => authService.sendOtp('+15550001000')).called(1);
        expect(notifier.state.step, OnboardingStep.otpVerification);
        expect(notifier.state.phoneNumber, '+15550001000');
        expect(notifier.state.isLoading, false);
      });

      test('trims whitespace from phone number', () async {
        when(() => authService.sendOtp('+15550001000'))
            .thenAnswer((_) async {});

        await notifier.sendOtp('  +15550001000  ');

        expect(notifier.state.phoneNumber, '+15550001000');
      });

      test('rejects empty phone number', () async {
        await notifier.sendOtp('');

        expect(notifier.state.step, OnboardingStep.phoneEntry);
        expect(notifier.state.error, contains('cannot be empty'));
        verifyNever(() => authService.sendOtp(any()));
      });

      test('shows error on failure', () async {
        when(() => authService.sendOtp(any()))
            .thenThrow(Exception('Network error'));

        await notifier.sendOtp('+15550001000');

        expect(notifier.state.step, OnboardingStep.phoneEntry);
        expect(notifier.state.error, isNotNull);
      });
    });

    group('OTP verification', () {
      setUp(advanceToOtp);

      test('existing user → completes onboarding, no account created',
          () async {
        when(() => authService.verifyOtp(
              phoneNumber: any(named: 'phoneNumber'),
              otpCode: any(named: 'otpCode'),
            )).thenAnswer((_) async => AuthResponse(session: null, user: null));
        when(() => authService.getCurrentUser())
            .thenAnswer((_) async => newUserRow());

        await notifier.verifyOtp('123456');

        expect(notifier.state.onboardingComplete, true);
        verifyNever(() => authService.createAccount(
              avatarColor: any(named: 'avatarColor'),
            ));
      });

      test('new user → creates account and completes onboarding (lands Search)',
          () async {
        when(() => authService.verifyOtp(
              phoneNumber: any(named: 'phoneNumber'),
              otpCode: any(named: 'otpCode'),
            )).thenAnswer((_) async => AuthResponse(session: null, user: null));
        when(() => authService.getCurrentUser()).thenAnswer((_) async => null);
        when(() => authService.createAccount(
              avatarColor: any(named: 'avatarColor'),
            )).thenAnswer((_) async => newUserRow());

        await notifier.verifyOtp('123456');

        verify(() => authService.createAccount(avatarColor: 'Deep Ember'))
            .called(1);
        // No contacts-permission step under single-pick — straight to Search.
        expect(notifier.state.onboardingComplete, true);
        expect(notifier.state.avatarColor, 'Deep Ember');
      });

      test('createAccount failure keeps user on OTP step with error', () async {
        when(() => authService.verifyOtp(
              phoneNumber: any(named: 'phoneNumber'),
              otpCode: any(named: 'otpCode'),
            )).thenAnswer((_) async => AuthResponse(session: null, user: null));
        when(() => authService.getCurrentUser()).thenAnswer((_) async => null);
        when(() => authService.createAccount(
              avatarColor: any(named: 'avatarColor'),
            )).thenThrow(Exception('Network error'));

        await notifier.verifyOtp('123456');

        expect(notifier.state.step, OnboardingStep.otpVerification);
        expect(notifier.state.error, isNotNull);
        expect(notifier.state.onboardingComplete, false);
      });

      test('retry after createAccount failure skips OTP re-verification',
          () async {
        when(() => authService.verifyOtp(
              phoneNumber: any(named: 'phoneNumber'),
              otpCode: any(named: 'otpCode'),
            )).thenAnswer((_) async => AuthResponse(session: null, user: null));
        when(() => authService.getCurrentUser()).thenAnswer((_) async => null);
        when(() => authService.createAccount(
              avatarColor: any(named: 'avatarColor'),
            )).thenThrow(Exception('Network error'));

        await notifier.verifyOtp('123456');
        expect(notifier.state.error, isNotNull);

        // Session now exists (first verify succeeded); the write now succeeds.
        when(() => authService.currentSession).thenReturn(MockSession());
        when(() => authService.createAccount(
              avatarColor: any(named: 'avatarColor'),
            )).thenAnswer((_) async => newUserRow());

        await notifier.verifyOtp('123456');

        verify(() => authService.verifyOtp(
              phoneNumber: any(named: 'phoneNumber'),
              otpCode: any(named: 'otpCode'),
            )).called(1);
        verify(() => authService.createAccount(
              avatarColor: any(named: 'avatarColor'),
            )).called(2);
        expect(notifier.state.onboardingComplete, true);
      });

      test('invalid code shows error', () async {
        when(() => authService.verifyOtp(
              phoneNumber: any(named: 'phoneNumber'),
              otpCode: any(named: 'otpCode'),
            )).thenThrow(Exception('Invalid OTP'));

        await notifier.verifyOtp('000000');

        expect(notifier.state.step, OnboardingStep.otpVerification);
        expect(notifier.state.error, contains('Invalid or expired'));
      });

      test('rejects empty OTP code', () async {
        await notifier.verifyOtp('');

        expect(notifier.state.error, contains('verification code'));
        verifyNever(() => authService.verifyOtp(
              phoneNumber: any(named: 'phoneNumber'),
              otpCode: any(named: 'otpCode'),
            ));
      });

      test('resendOtp calls authService again once the 30s cooldown has '
          'elapsed', () {
        fakeAsync((async) {
          when(() => authService.sendOtp(any())).thenAnswer((_) async {});
          notifier.sendOtp('+15550001000');
          async.flushMicrotasks();
          expect(notifier.state.resendCooldown, 30);

          async.elapse(const Duration(seconds: 30));
          expect(notifier.state.resendCooldown, 0);

          notifier.resendOtp();
          async.flushMicrotasks();

          // The group's setUp (advanceToOtp) + the in-zone send + the resend.
          verify(() => authService.sendOtp('+15550001000')).called(3);
        });
      });
    });

    group('resend cooldown (spec §18: resend available after 30 seconds)', () {
      test('sendOtp starts a 30s cooldown that ticks down to zero', () {
        fakeAsync((async) {
          when(() => authService.sendOtp(any())).thenAnswer((_) async {});
          notifier.sendOtp('+15550001000');
          async.flushMicrotasks();

          expect(notifier.state.resendCooldown, 30);
          async.elapse(const Duration(seconds: 12));
          expect(notifier.state.resendCooldown, 18);
          async.elapse(const Duration(seconds: 18));
          expect(notifier.state.resendCooldown, 0);
        });
      });

      test('resendOtp during the cooldown is a no-op — no SMS is sent', () {
        fakeAsync((async) {
          when(() => authService.sendOtp(any())).thenAnswer((_) async {});
          notifier.sendOtp('+15550001000');
          async.flushMicrotasks();

          async.elapse(const Duration(seconds: 5));
          notifier.resendOtp();
          async.flushMicrotasks();

          verify(() => authService.sendOtp(any())).called(1); // initial only
        });
      });

      test('a successful resend restarts the cooldown', () {
        fakeAsync((async) {
          when(() => authService.sendOtp(any())).thenAnswer((_) async {});
          notifier.sendOtp('+15550001000');
          async.flushMicrotasks();
          async.elapse(const Duration(seconds: 30));

          notifier.resendOtp();
          async.flushMicrotasks();

          expect(notifier.state.resendCooldown, 30);
          async.elapse(const Duration(seconds: 30));
          expect(notifier.state.resendCooldown, 0);
        });
      });

      test('goBack cancels the cooldown', () {
        fakeAsync((async) {
          when(() => authService.sendOtp(any())).thenAnswer((_) async {});
          notifier.sendOtp('+15550001000');
          async.flushMicrotasks();
          expect(notifier.state.resendCooldown, 30);

          notifier.goBack();
          expect(notifier.state.resendCooldown, 0);

          // No stray timer keeps mutating state after the cancel.
          async.elapse(const Duration(seconds: 60));
          expect(notifier.state.resendCooldown, 0);
        });
      });
    });

    group('back navigation', () {
      test('goBack from otpVerification returns to phoneEntry', () async {
        await advanceToOtp();

        notifier.goBack();

        expect(notifier.state.step, OnboardingStep.phoneEntry);
      });

      test('goBack from phoneEntry stays on phoneEntry', () {
        notifier.goBack();

        expect(notifier.state.step, OnboardingStep.phoneEntry);
      });
    });
  });
}
