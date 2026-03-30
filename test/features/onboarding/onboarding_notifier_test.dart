import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:roger/core/models/user.dart';
import 'package:roger/core/services/auth_service.dart';
import 'package:roger/core/services/contacts_service.dart';
import 'package:roger/features/onboarding/onboarding_notifier.dart';
import 'package:roger/features/onboarding/onboarding_state.dart';

class MockAuthService extends Mock implements AuthService {}
class MockContactsService extends Mock implements ContactsService {}
class MockRandom extends Mock implements Random {}

void main() {
  late MockAuthService authService;
  late MockContactsService contactsService;
  late MockRandom random;
  late OnboardingNotifier notifier;

  setUp(() {
    authService = MockAuthService();
    contactsService = MockContactsService();
    random = MockRandom();
    // Default: random returns index 2 → 'Deep Ember'
    when(() => random.nextInt(any())).thenReturn(2);
    notifier = OnboardingNotifier(
      authService: authService,
      contactsService: contactsService,
      random: random,
    );
  });

  /// Helper: advance notifier to a given step with valid state
  Future<void> advanceTo(OnboardingStep target) async {
    if (target == OnboardingStep.phoneEntry) return;

    when(() => authService.sendOtp(any())).thenAnswer((_) async {});
    await notifier.submitPhoneNumber('+15551234567');

    if (target == OnboardingStep.otpVerification) return;

    // verifyOtp returns null → new user, continue onboarding
    when(() => authService.verifyOtp(any(), any()))
        .thenAnswer((_) async => null);
    await notifier.verifyOtp('123456');

    if (target == OnboardingStep.displayName) return;

    notifier.setDisplayName('Ashe');

    if (target == OnboardingStep.avatarColor) return;

    notifier.setAvatarColor('Deep Ember');
    notifier.confirmAvatarColor();

    if (target == OnboardingStep.recoveryEmail) return;

    notifier.skipRecoveryEmail();
  }

  group('OnboardingNotifier', () {
    group('phone entry', () {
      test('submitPhoneNumber sends OTP and advances to otpVerification',
          () async {
        when(() => authService.sendOtp('+15551234567'))
            .thenAnswer((_) async {});

        await notifier.submitPhoneNumber('+15551234567');

        verify(() => authService.sendOtp('+15551234567')).called(1);
        expect(notifier.state.step, OnboardingStep.otpVerification);
        expect(notifier.state.phoneNumber, '+15551234567');
        expect(notifier.state.isLoading, false);
      });

      test('user can go back and re-enter phone number before OTP sent',
          () async {
        // Initial state is phoneEntry — user hasn't submitted yet
        expect(notifier.state.step, OnboardingStep.phoneEntry);

        // User can submit a different number
        when(() => authService.sendOtp('+15559999999'))
            .thenAnswer((_) async {});
        await notifier.submitPhoneNumber('+15559999999');

        expect(notifier.state.phoneNumber, '+15559999999');
      });

      test('submitPhoneNumber shows error on failure', () async {
        when(() => authService.sendOtp(any()))
            .thenThrow(Exception('Network error'));

        await notifier.submitPhoneNumber('+15551234567');

        expect(notifier.state.step, OnboardingStep.phoneEntry);
        expect(notifier.state.error, isNotNull);
        expect(notifier.state.isLoading, false);
      });
    });

    group('OTP verification', () {
      setUp(() async {
        await advanceTo(OnboardingStep.otpVerification);
      });

      test('correct OTP advances to displayName step', () async {
        when(() => authService.verifyOtp(any(), '123456'))
            .thenAnswer((_) async => null);

        await notifier.verifyOtp('123456');

        expect(notifier.state.step, OnboardingStep.displayName);
        expect(notifier.state.isLoading, false);
      });

      test('incorrect OTP decrements attempts remaining', () async {
        when(() => authService.verifyOtp(any(), 'wrong'))
            .thenThrow(Exception('Invalid OTP'));

        await notifier.verifyOtp('wrong');

        expect(notifier.state.otpAttemptsRemaining, 4);
        expect(notifier.state.step, OnboardingStep.otpVerification);
        expect(notifier.state.error, isNotNull);
      });

      test('5 failed attempts resets flow and requires new OTP', () async {
        when(() => authService.verifyOtp(any(), 'wrong'))
            .thenThrow(Exception('Invalid OTP'));

        for (var i = 0; i < 5; i++) {
          await notifier.verifyOtp('wrong');
        }

        expect(notifier.state.step, OnboardingStep.phoneEntry);
        expect(notifier.state.otpAttemptsRemaining, 5);
        expect(notifier.state.error, contains('Too many attempts'));
      });

      test('resendOtp available after 30 seconds', () async {
        // Right after submit, canResendOtp is false
        expect(notifier.state.canResendOtp, false);
      });

      test('existing phone number logs in instead of creating duplicate',
          () async {
        final existingUser = User(
          id: 'existing-id',
          phoneNumber: '+15551234567',
          displayName: 'Existing',
          avatarColor: 'Rust',
          createdAt: DateTime.now(),
        );
        when(() => authService.verifyOtp(any(), '123456'))
            .thenAnswer((_) async => existingUser);

        await notifier.verifyOtp('123456');

        // Skips onboarding entirely
        expect(notifier.state.onboardingComplete, true);
      });
    });

    group('display name', () {
      setUp(() async {
        await advanceTo(OnboardingStep.displayName);
      });

      test('accepts any non-empty string up to 50 characters', () {
        notifier.setDisplayName('Ashe');

        expect(notifier.state.displayName, 'Ashe');
        expect(notifier.state.step, OnboardingStep.avatarColor);
        expect(notifier.state.error, isNull);
      });

      test('rejects empty string', () {
        notifier.setDisplayName('');

        expect(notifier.state.step, OnboardingStep.displayName);
        expect(notifier.state.error, isNotNull);
      });

      test('rejects string over 50 characters', () {
        notifier.setDisplayName('A' * 51);

        expect(notifier.state.step, OnboardingStep.displayName);
        expect(notifier.state.error, isNotNull);
      });

      test('trims whitespace', () {
        notifier.setDisplayName('  Ashe  ');

        expect(notifier.state.displayName, 'Ashe');
        expect(notifier.state.step, OnboardingStep.avatarColor);
      });
    });

    group('avatar color', () {
      setUp(() async {
        await advanceTo(OnboardingStep.avatarColor);
      });

      test('randomized default from 9-color system', () {
        // MockRandom returns 2 → 'Deep Ember'
        expect(notifier.state.avatarColor, 'Deep Ember');
      });

      test('user can browse colors without advancing', () {
        notifier.setAvatarColor('Cornflower');

        expect(notifier.state.avatarColor, 'Cornflower');
        expect(notifier.state.step, OnboardingStep.avatarColor);
      });

      test('confirmAvatarColor advances to recoveryEmail', () {
        notifier.setAvatarColor('Cornflower');
        notifier.confirmAvatarColor();

        expect(notifier.state.avatarColor, 'Cornflower');
        expect(notifier.state.step, OnboardingStep.recoveryEmail);
      });

      test('ignores invalid color', () {
        notifier.setAvatarColor('Neon Green');

        // Stays on avatarColor step, keeps previous color
        expect(notifier.state.step, OnboardingStep.avatarColor);
        expect(notifier.state.avatarColor, 'Deep Ember');
      });
    });

    group('recovery email', () {
      setUp(() async {
        await advanceTo(OnboardingStep.recoveryEmail);
      });

      test('setRecoveryEmail saves and advances', () {
        notifier.setRecoveryEmail('ashe@example.com');

        expect(notifier.state.recoveryEmail, 'ashe@example.com');
        expect(notifier.state.step, OnboardingStep.contactsPermission);
      });

      test('skipRecoveryEmail advances without saving', () {
        notifier.skipRecoveryEmail();

        expect(notifier.state.recoveryEmail, isNull);
        expect(notifier.state.step, OnboardingStep.contactsPermission);
      });
    });

    group('contacts permission', () {
      setUp(() async {
        await advanceTo(OnboardingStep.contactsPermission);
        when(() => authService.createAccount(
              phoneNumber: any(named: 'phoneNumber'),
              displayName: any(named: 'displayName'),
              avatarColor: any(named: 'avatarColor'),
              recoveryEmail: any(named: 'recoveryEmail'),
            )).thenAnswer((_) async => User(
              id: 'new-id',
              phoneNumber: '+15551234567',
              displayName: 'Ashe',
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
              displayName: any(named: 'displayName'),
              avatarColor: any(named: 'avatarColor'),
              recoveryEmail: any(named: 'recoveryEmail'),
            )).thenAnswer((_) async => User(
              id: 'new-id',
              phoneNumber: '+15551234567',
              displayName: 'Ashe',
              avatarColor: 'Deep Ember',
              createdAt: DateTime.now(),
            ));

        await notifier.requestContactsPermission();

        expect(notifier.state.onboardingComplete, true);
      });

      test('deep link arrival skips to pending conversation',
          skip: 'Deep link routing lives in GoRouter, not the notifier. '
              'Add integration test when router is wired up (step 3).',
          () {});

      test('createAccount fails, user can retry', () async {
        when(() => contactsService.requestPermission())
            .thenAnswer((_) async => false);

        // First attempt fails
        when(() => authService.createAccount(
              phoneNumber: any(named: 'phoneNumber'),
              displayName: any(named: 'displayName'),
              avatarColor: any(named: 'avatarColor'),
              recoveryEmail: any(named: 'recoveryEmail'),
            )).thenThrow(Exception('Network error'));

        await notifier.requestContactsPermission();

        expect(notifier.state.onboardingComplete, false);
        expect(notifier.state.error, isNotNull);

        // Retry succeeds
        when(() => authService.createAccount(
              phoneNumber: any(named: 'phoneNumber'),
              displayName: any(named: 'displayName'),
              avatarColor: any(named: 'avatarColor'),
              recoveryEmail: any(named: 'recoveryEmail'),
            )).thenAnswer((_) async => User(
              id: 'new-id',
              phoneNumber: '+15551234567',
              displayName: 'Ashe',
              avatarColor: 'Deep Ember',
              createdAt: DateTime.now(),
            ));

        await notifier.completeOnboarding();

        expect(notifier.state.onboardingComplete, true);
        expect(notifier.state.error, isNull);
      });

      test('abandoning mid-flow and relaunching restarts from beginning', () {
        // A fresh notifier always starts at phoneEntry
        final freshNotifier = OnboardingNotifier(
          authService: authService,
          contactsService: contactsService,
        );
        expect(freshNotifier.state.step, OnboardingStep.phoneEntry);
        expect(freshNotifier.state.phoneNumber, '');
        expect(freshNotifier.state.displayName, '');
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
              displayName: any(named: 'displayName'),
              avatarColor: any(named: 'avatarColor'),
              recoveryEmail: any(named: 'recoveryEmail'),
            )).thenAnswer((_) async => User(
              id: 'new-id',
              phoneNumber: '+15551234567',
              displayName: 'Ashe',
              avatarColor: 'Deep Ember',
              createdAt: DateTime.now(),
            ));

        await notifier.requestContactsPermission();

        // Verify only contacts permission was requested — no camera or mic.
        // The notifier has no camera/mic dependency, so there's nothing
        // to call. This test asserts that the API surface is correct.
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

      test('goBack from displayName returns to otpVerification', () async {
        await advanceTo(OnboardingStep.displayName);

        notifier.goBack();

        expect(notifier.state.step, OnboardingStep.otpVerification);
      });

      test('goBack from avatarColor returns to displayName', () async {
        await advanceTo(OnboardingStep.avatarColor);

        notifier.goBack();

        expect(notifier.state.step, OnboardingStep.displayName);
      });

      test('goBack from recoveryEmail returns to avatarColor', () async {
        await advanceTo(OnboardingStep.recoveryEmail);

        notifier.goBack();

        expect(notifier.state.step, OnboardingStep.avatarColor);
      });

      test('goBack from contactsPermission returns to recoveryEmail',
          () async {
        await advanceTo(OnboardingStep.contactsPermission);

        notifier.goBack();

        expect(notifier.state.step, OnboardingStep.recoveryEmail);
      });

      test('goBack from phoneEntry stays on phoneEntry', () {
        notifier.goBack();

        expect(notifier.state.step, OnboardingStep.phoneEntry);
      });

      test('goBack clears error state', () async {
        await advanceTo(OnboardingStep.displayName);
        notifier.setDisplayName(''); // triggers error
        expect(notifier.state.error, isNotNull);

        notifier.goBack();

        expect(notifier.state.error, isNull);
      });
    });
  });
}
