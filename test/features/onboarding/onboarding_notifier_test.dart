import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:roger/core/models/user.dart';
import 'package:roger/core/providers.dart';
import 'package:roger/core/services/auth_service.dart';
import 'package:roger/core/services/contacts_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:roger/features/onboarding/onboarding_notifier.dart';
import 'package:roger/features/onboarding/onboarding_state.dart';

class MockAuthService extends Mock implements AuthService {}
class MockContactsService extends Mock implements ContactsService {}
class MockRandom extends Mock implements Random {}

void main() {
  late MockAuthService authService;
  late MockContactsService contactsService;
  late MockRandom random;
  late ProviderContainer container;
  late OnboardingNotifier notifier;

  setUp(() {
    authService = MockAuthService();
    contactsService = MockContactsService();
    random = MockRandom();
    // Default: random returns index 2 → 'Deep Ember'
    when(() => random.nextInt(any())).thenReturn(2);

    container = ProviderContainer(overrides: [
      authServiceProvider.overrideWithValue(authService),
      contactsServiceProvider.overrideWithValue(contactsService),
      randomProvider.overrideWithValue(random),
    ]);

    notifier = container.read(onboardingProvider.notifier);
  });

  tearDown(() {
    container.dispose();
  });

  /// Helper: advance notifier to a given step with valid state
  Future<void> advanceTo(OnboardingStep target) async {
    if (target == OnboardingStep.phoneEntry) return;

    when(() => authService.sendOtp(any())).thenAnswer((_) async {});
    await notifier.sendOtp('+15550001000');

    if (target == OnboardingStep.otpVerification) return;

    // Simulate successful OTP verification — new user
    when(() => authService.verifyOtp(
          phoneNumber: any(named: 'phoneNumber'),
          otpCode: any(named: 'otpCode'),
        )).thenAnswer((_) async => AuthResponse(
          session: null,
          user: null,
        ));
    when(() => authService.getCurrentUser())
        .thenAnswer((_) async => null);
    await notifier.verifyOtp('123456');
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
        expect(notifier.state.step, OnboardingStep.otpVerification);
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
        expect(notifier.state.isLoading, false);
      });
    });

    group('OTP verification', () {
      setUp(() async {
        await advanceTo(OnboardingStep.otpVerification);
      });

      test('verifyOtp with existing user completes onboarding', () async {
        when(() => authService.verifyOtp(
              phoneNumber: any(named: 'phoneNumber'),
              otpCode: any(named: 'otpCode'),
            )).thenAnswer((_) async => AuthResponse(
              session: null,
              user: null,
            ));
        when(() => authService.getCurrentUser()).thenAnswer((_) async => User(
              id: 'existing-id',
              phoneNumber: '+15550001000',
              avatarColor: 'Rust',
              createdAt: DateTime.now(),
            ));

        await notifier.verifyOtp('123456');

        expect(notifier.state.onboardingComplete, true);
      });

      test('verifyOtp with new user assigns avatar and advances to contacts',
          () async {
        when(() => authService.verifyOtp(
              phoneNumber: any(named: 'phoneNumber'),
              otpCode: any(named: 'otpCode'),
            )).thenAnswer((_) async => AuthResponse(
              session: null,
              user: null,
            ));
        when(() => authService.getCurrentUser())
            .thenAnswer((_) async => null);

        await notifier.verifyOtp('123456');

        expect(notifier.state.step, OnboardingStep.contactsPermission);
        expect(notifier.state.avatarColor, 'Deep Ember');
      });

      test('verifyOtp with invalid code shows error', () async {
        when(() => authService.verifyOtp(
              phoneNumber: any(named: 'phoneNumber'),
              otpCode: any(named: 'otpCode'),
            )).thenThrow(Exception('Invalid OTP'));

        await notifier.verifyOtp('000000');

        expect(notifier.state.step, OnboardingStep.otpVerification);
        expect(notifier.state.error, contains('Invalid or expired'));
        expect(notifier.state.isLoading, false);
      });

      test('rejects empty OTP code', () async {
        await notifier.verifyOtp('');

        expect(notifier.state.step, OnboardingStep.otpVerification);
        expect(notifier.state.error, contains('verification code'));
        verifyNever(() => authService.verifyOtp(
              phoneNumber: any(named: 'phoneNumber'),
              otpCode: any(named: 'otpCode'),
            ));
      });

      test('resendOtp calls authService again', () async {
        reset(authService);
        when(() => authService.sendOtp('+15550001000'))
            .thenAnswer((_) async {});

        await notifier.resendOtp();

        verify(() => authService.sendOtp('+15550001000')).called(1);
      });
    });

    group('contacts permission', () {
      setUp(() async {
        await advanceTo(OnboardingStep.contactsPermission);
        when(() => authService.createAccount(
              phoneNumber: any(named: 'phoneNumber'),
              avatarColor: any(named: 'avatarColor'),
            )).thenAnswer((_) async => User(
              id: 'new-id',
              phoneNumber: '+15550001000',
              avatarColor: 'Deep Ember',
              createdAt: DateTime.now(),
            ));
      });

      test('granted: triggers hashed batch check in background', () async {
        when(() => contactsService.requestPermission())
            .thenAnswer((_) async => true);
        when(() => contactsService.refreshBatchCheck())
            .thenAnswer((_) async {});

        await notifier.requestContactsPermission();

        verify(() => contactsService.refreshBatchCheck()).called(1);
        expect(notifier.state.onboardingComplete, true);
      });

      test('denied: continues to Search with only search bar', () async {
        when(() => contactsService.requestPermission())
            .thenAnswer((_) async => false);

        await notifier.requestContactsPermission();

        verifyNever(() => contactsService.refreshBatchCheck());
        expect(notifier.state.onboardingComplete, true);
      });
    });

    group('completion', () {
      setUp(() async {
        await advanceTo(OnboardingStep.contactsPermission);
      });

      test('lands on Search screen after onboarding', () async {
        when(() => contactsService.requestPermission())
            .thenAnswer((_) async => false);
        when(() => authService.createAccount(
              phoneNumber: any(named: 'phoneNumber'),
              avatarColor: any(named: 'avatarColor'),
            )).thenAnswer((_) async => User(
              id: 'new-id',
              phoneNumber: '+15550001000',
              avatarColor: 'Deep Ember',
              createdAt: DateTime.now(),
            ));

        await notifier.requestContactsPermission();

        expect(notifier.state.onboardingComplete, true);
      });

      // Deep link routing tested in test/core/routing_test.dart (unit)
      // and integration_test/ (on-device). Not a notifier concern.

      test('createAccount fails, user can retry', () async {
        when(() => contactsService.requestPermission())
            .thenAnswer((_) async => false);

        when(() => authService.createAccount(
              phoneNumber: any(named: 'phoneNumber'),
              avatarColor: any(named: 'avatarColor'),
            )).thenThrow(Exception('Network error'));

        await notifier.requestContactsPermission();

        expect(notifier.state.onboardingComplete, false);
        expect(notifier.state.error, isNotNull);

        when(() => authService.createAccount(
              phoneNumber: any(named: 'phoneNumber'),
              avatarColor: any(named: 'avatarColor'),
            )).thenAnswer((_) async => User(
              id: 'new-id',
              phoneNumber: '+15550001000',
              avatarColor: 'Deep Ember',
              createdAt: DateTime.now(),
            ));

        await notifier.completeOnboarding();

        expect(notifier.state.onboardingComplete, true);
        expect(notifier.state.error, isNull);
      });

      test('abandoning mid-flow and relaunching restarts from beginning', () {
        // A fresh container always starts at phoneEntry
        final freshContainer = ProviderContainer(overrides: [
          authServiceProvider.overrideWithValue(authService),
          contactsServiceProvider.overrideWithValue(contactsService),
          randomProvider.overrideWithValue(random),
        ]);
        final freshNotifier =
            freshContainer.read(onboardingProvider.notifier);
        expect(freshNotifier.state.step, OnboardingStep.phoneEntry);
        expect(freshNotifier.state.phoneNumber, '');
        freshContainer.dispose();
      });

      test(
          'camera and microphone permissions NOT requested during onboarding',
          () async {
        when(() => contactsService.requestPermission())
            .thenAnswer((_) async => true);
        when(() => contactsService.refreshBatchCheck())
            .thenAnswer((_) async {});
        when(() => authService.createAccount(
              phoneNumber: any(named: 'phoneNumber'),
              avatarColor: any(named: 'avatarColor'),
            )).thenAnswer((_) async => User(
              id: 'new-id',
              phoneNumber: '+15550001000',
              avatarColor: 'Deep Ember',
              createdAt: DateTime.now(),
            ));

        await notifier.requestContactsPermission();

        verify(() => contactsService.requestPermission()).called(1);
        verify(() => contactsService.refreshBatchCheck()).called(1);
        verifyNoMoreInteractions(contactsService);
      });
    });

    group('back navigation', () {
      test('goBack from otpVerification returns to phoneEntry', () async {
        await advanceTo(OnboardingStep.otpVerification);

        notifier.goBack();

        expect(notifier.state.step, OnboardingStep.phoneEntry);
      });

      test('goBack from contactsPermission returns to otpVerification',
          () async {
        await advanceTo(OnboardingStep.contactsPermission);

        notifier.goBack();

        expect(notifier.state.step, OnboardingStep.otpVerification);
      });

      test('goBack from phoneEntry stays on phoneEntry', () {
        notifier.goBack();

        expect(notifier.state.step, OnboardingStep.phoneEntry);
      });
    });
  });
}
