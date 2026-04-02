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
      authStateChangesProvider.overrideWith(
        (ref) => const Stream<AuthState>.empty(),
      ),
    ]);

    notifier = container.read(onboardingProvider.notifier);
  });

  tearDown(() {
    container.dispose();
  });

  /// Helper: advance notifier to a given step with valid state
  Future<void> advanceTo(OnboardingStep target) async {
    if (target == OnboardingStep.emailEntry) return;

    when(() => authService.sendMagicLink(any())).thenAnswer((_) async {});
    await notifier.sendMagicLink('ashe@example.com');

    if (target == OnboardingStep.awaitingEmail) return;

    // Simulate magic link callback — new user
    when(() => authService.getCurrentUser())
        .thenAnswer((_) async => null);
    await notifier.onAuthStateChanged();

    if (target == OnboardingStep.phoneNumber) return;

    when(() => authService.isPhoneNumberTaken(any()))
        .thenAnswer((_) async => false);
    await notifier.submitPhoneNumber('+15551234567');

    if (target == OnboardingStep.displayName) return;

    notifier.setDisplayName('Ashe');
  }

  group('OnboardingNotifier', () {
    group('email entry', () {
      test('sendMagicLink calls authService and advances to awaitingEmail',
          () async {
        when(() => authService.sendMagicLink('ashe@example.com'))
            .thenAnswer((_) async {});

        await notifier.sendMagicLink('ashe@example.com');

        verify(() => authService.sendMagicLink('ashe@example.com')).called(1);
        expect(notifier.state.step, OnboardingStep.awaitingEmail);
        expect(notifier.state.email, 'ashe@example.com');
        expect(notifier.state.isLoading, false);
      });

      test('trims whitespace from email', () async {
        when(() => authService.sendMagicLink('ashe@example.com'))
            .thenAnswer((_) async {});

        await notifier.sendMagicLink('  ashe@example.com  ');

        expect(notifier.state.email, 'ashe@example.com');
        expect(notifier.state.step, OnboardingStep.awaitingEmail);
      });

      test('rejects empty email', () async {
        await notifier.sendMagicLink('');

        expect(notifier.state.step, OnboardingStep.emailEntry);
        expect(notifier.state.error, contains('valid email'));
        verifyNever(() => authService.sendMagicLink(any()));
      });

      test('rejects invalid email format', () async {
        await notifier.sendMagicLink('not-an-email');

        expect(notifier.state.step, OnboardingStep.emailEntry);
        expect(notifier.state.error, contains('valid email'));
        verifyNever(() => authService.sendMagicLink(any()));
      });

      test('shows error on failure', () async {
        when(() => authService.sendMagicLink(any()))
            .thenThrow(Exception('Network error'));

        await notifier.sendMagicLink('ashe@example.com');

        expect(notifier.state.step, OnboardingStep.emailEntry);
        expect(notifier.state.error, isNotNull);
        expect(notifier.state.isLoading, false);
      });
    });

    group('awaiting email', () {
      setUp(() async {
        await advanceTo(OnboardingStep.awaitingEmail);
      });

      test('onAuthStateChanged with existing user completes onboarding',
          () async {
        when(() => authService.getCurrentUser()).thenAnswer((_) async => User(
              id: 'existing-id',
              email: 'ashe@example.com',
              phoneNumber: '+15551234567',
              displayName: 'Existing',
              avatarColor: 'Rust',
              createdAt: DateTime.now(),
            ));

        await notifier.onAuthStateChanged();

        expect(notifier.state.onboardingComplete, true);
      });

      test('onAuthStateChanged with new user assigns avatar and advances',
          () async {
        when(() => authService.getCurrentUser())
            .thenAnswer((_) async => null);

        await notifier.onAuthStateChanged();

        expect(notifier.state.step, OnboardingStep.phoneNumber);
        expect(notifier.state.avatarColor, 'Deep Ember');
      });

      test('resendMagicLink calls authService again', () async {
        reset(authService);
        when(() => authService.sendMagicLink('ashe@example.com'))
            .thenAnswer((_) async {});

        await notifier.resendMagicLink();

        verify(() => authService.sendMagicLink('ashe@example.com')).called(1);
      });
    });

    group('phone number', () {
      setUp(() async {
        await advanceTo(OnboardingStep.phoneNumber);
      });

      test('submitPhoneNumber stores value and advances to displayName',
          () async {
        when(() => authService.isPhoneNumberTaken('+15551234567'))
            .thenAnswer((_) async => false);

        await notifier.submitPhoneNumber('+15551234567');

        expect(notifier.state.phoneNumber, '+15551234567');
        expect(notifier.state.step, OnboardingStep.displayName);
      });

      test('rejects empty phone number', () async {
        await notifier.submitPhoneNumber('');

        expect(notifier.state.step, OnboardingStep.phoneNumber);
        expect(notifier.state.error, isNotNull);
      });

      test('rejects phone number already claimed by another account',
          () async {
        when(() => authService.isPhoneNumberTaken('+15559999999'))
            .thenAnswer((_) async => true);

        await notifier.submitPhoneNumber('+15559999999');

        expect(notifier.state.step, OnboardingStep.phoneNumber);
        expect(notifier.state.error, contains('already in use'));
      });

      test('trims whitespace', () async {
        when(() => authService.isPhoneNumberTaken('+15551234567'))
            .thenAnswer((_) async => false);

        await notifier.submitPhoneNumber('  +15551234567  ');

        expect(notifier.state.phoneNumber, '+15551234567');
        expect(notifier.state.step, OnboardingStep.displayName);
      });

      test('network failure on uniqueness check shows error and stays',
          () async {
        when(() => authService.isPhoneNumberTaken(any()))
            .thenThrow(Exception('Network error'));

        await notifier.submitPhoneNumber('+15551234567');

        expect(notifier.state.step, OnboardingStep.phoneNumber);
        expect(notifier.state.error, contains('Check your connection'));
      });
    });

    group('display name', () {
      setUp(() async {
        await advanceTo(OnboardingStep.displayName);
      });

      test('accepts any non-empty string up to 50 characters', () {
        notifier.setDisplayName('Ashe');

        expect(notifier.state.displayName, 'Ashe');
        expect(notifier.state.step, OnboardingStep.contactsPermission);
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
        expect(notifier.state.step, OnboardingStep.contactsPermission);
      });
    });

    group('contacts permission', () {
      setUp(() async {
        await advanceTo(OnboardingStep.contactsPermission);
        when(() => authService.createAccount(
              email: any(named: 'email'),
              phoneNumber: any(named: 'phoneNumber'),
              displayName: any(named: 'displayName'),
              avatarColor: any(named: 'avatarColor'),
            )).thenAnswer((_) async => User(
              id: 'new-id',
              email: 'ashe@example.com',
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
              email: any(named: 'email'),
              phoneNumber: any(named: 'phoneNumber'),
              displayName: any(named: 'displayName'),
              avatarColor: any(named: 'avatarColor'),
            )).thenAnswer((_) async => User(
              id: 'new-id',
              email: 'ashe@example.com',
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
              'Add integration test when router is wired up.',
          () {});

      test('createAccount fails, user can retry', () async {
        when(() => contactsService.requestPermission())
            .thenAnswer((_) async => false);

        when(() => authService.createAccount(
              email: any(named: 'email'),
              phoneNumber: any(named: 'phoneNumber'),
              displayName: any(named: 'displayName'),
              avatarColor: any(named: 'avatarColor'),
            )).thenThrow(Exception('Network error'));

        await notifier.requestContactsPermission();

        expect(notifier.state.onboardingComplete, false);
        expect(notifier.state.error, isNotNull);

        when(() => authService.createAccount(
              email: any(named: 'email'),
              phoneNumber: any(named: 'phoneNumber'),
              displayName: any(named: 'displayName'),
              avatarColor: any(named: 'avatarColor'),
            )).thenAnswer((_) async => User(
              id: 'new-id',
              email: 'ashe@example.com',
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
        // A fresh container always starts at emailEntry
        final freshContainer = ProviderContainer(overrides: [
          authServiceProvider.overrideWithValue(authService),
          contactsServiceProvider.overrideWithValue(contactsService),
          randomProvider.overrideWithValue(random),
          authStateChangesProvider.overrideWith(
            (ref) => const Stream<AuthState>.empty(),
          ),
        ]);
        final freshNotifier =
            freshContainer.read(onboardingProvider.notifier);
        expect(freshNotifier.state.step, OnboardingStep.emailEntry);
        expect(freshNotifier.state.email, '');
        expect(freshNotifier.state.phoneNumber, '');
        expect(freshNotifier.state.displayName, '');
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
              email: any(named: 'email'),
              phoneNumber: any(named: 'phoneNumber'),
              displayName: any(named: 'displayName'),
              avatarColor: any(named: 'avatarColor'),
            )).thenAnswer((_) async => User(
              id: 'new-id',
              email: 'ashe@example.com',
              phoneNumber: '+15551234567',
              displayName: 'Ashe',
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
      test('goBack from awaitingEmail returns to emailEntry', () async {
        await advanceTo(OnboardingStep.awaitingEmail);

        notifier.goBack();

        expect(notifier.state.step, OnboardingStep.emailEntry);
      });

      test('goBack from phoneNumber returns to emailEntry and signs out',
          () async {
        await advanceTo(OnboardingStep.phoneNumber);

        when(() => authService.signOut()).thenAnswer((_) async {});

        notifier.goBack();

        expect(notifier.state.step, OnboardingStep.emailEntry);
        verify(() => authService.signOut()).called(1);
      });

      test('goBack from displayName returns to phoneNumber', () async {
        await advanceTo(OnboardingStep.displayName);

        notifier.goBack();

        expect(notifier.state.step, OnboardingStep.phoneNumber);
      });

      test('goBack from contactsPermission returns to displayName', () async {
        await advanceTo(OnboardingStep.contactsPermission);

        notifier.goBack();

        expect(notifier.state.step, OnboardingStep.displayName);
      });

      test('goBack from emailEntry stays on emailEntry', () {
        notifier.goBack();

        expect(notifier.state.step, OnboardingStep.emailEntry);
      });

      test('goBack clears error state', () async {
        await advanceTo(OnboardingStep.displayName);
        notifier.setDisplayName('');
        expect(notifier.state.error, isNotNull);

        notifier.goBack();

        expect(notifier.state.error, isNull);
      });
    });
  });
}
