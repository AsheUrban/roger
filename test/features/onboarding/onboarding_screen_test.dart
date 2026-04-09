import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:roger/core/providers.dart';
import 'package:roger/core/services/auth_service.dart';
import 'package:roger/core/services/contacts_service.dart';
import 'package:roger/features/onboarding/onboarding_notifier.dart';
import 'package:roger/features/onboarding/onboarding_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

class MockAuthService extends Mock implements AuthService {}
class MockContactsService extends Mock implements ContactsService {}
class MockRandom extends Mock implements Random {}

void main() {
  late MockAuthService authService;
  late MockContactsService contactsService;
  late MockRandom random;

  setUp(() {
    authService = MockAuthService();
    contactsService = MockContactsService();
    random = MockRandom();
    when(() => random.nextInt(any())).thenReturn(2);
  });

  Widget buildTestWidget() {
    return ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(authService),
        contactsServiceProvider.overrideWithValue(contactsService),
        randomProvider.overrideWithValue(random),
        authStateChangesProvider.overrideWith(
          (ref) => const Stream<AuthState>.empty(),
        ),
      ],
      child: const MaterialApp(
        home: OnboardingScreen(),
      ),
    );
  }

  group('OnboardingScreen', () {
    group('emailEntry step', () {
      testWidgets('renders roger wordmark, email field, and Continue button',
          (tester) async {
        await tester.pumpWidget(buildTestWidget());

        expect(find.text('roger'), findsOneWidget);
        expect(find.text('Email address'), findsOneWidget);
        expect(find.text('Continue'), findsOneWidget);
        expect(find.byIcon(Icons.arrow_back), findsNothing);
      });

      testWidgets('tapping Continue with valid email calls sendMagicLink',
          (tester) async {
        when(() => authService.sendMagicLink(any()))
            .thenAnswer((_) async {});

        await tester.pumpWidget(buildTestWidget());

        await tester.enterText(
          find.byType(TextField),
          'ashe@example.com',
        );
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        verify(() => authService.sendMagicLink('ashe@example.com')).called(1);
      });

      testWidgets('tapping Continue with invalid email shows error',
          (tester) async {
        await tester.pumpWidget(buildTestWidget());

        await tester.enterText(find.byType(TextField), 'not-an-email');
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        expect(find.textContaining('valid email'), findsOneWidget);
        verifyNever(() => authService.sendMagicLink(any()));
      });
    });

    group('awaitingEmail step', () {
      testWidgets('renders check email message and resend button',
          (tester) async {
        when(() => authService.sendMagicLink(any()))
            .thenAnswer((_) async {});

        await tester.pumpWidget(buildTestWidget());

        // Advance to awaitingEmail
        await tester.enterText(find.byType(TextField), 'ashe@example.com');
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        expect(find.text('Check your email'), findsOneWidget);
        expect(find.text('ashe@example.com'), findsOneWidget);
        expect(find.text('Resend email'), findsOneWidget);
        expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      });

      testWidgets('tapping back returns to emailEntry', (tester) async {
        when(() => authService.sendMagicLink(any()))
            .thenAnswer((_) async {});

        await tester.pumpWidget(buildTestWidget());

        // Advance to awaitingEmail
        await tester.enterText(find.byType(TextField), 'ashe@example.com');
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        // Tap back
        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();

        expect(find.text('roger'), findsOneWidget);
        expect(find.text('Email address'), findsOneWidget);
      });

      testWidgets('tapping Resend email calls sendMagicLink again',
          (tester) async {
        when(() => authService.sendMagicLink(any()))
            .thenAnswer((_) async {});

        await tester.pumpWidget(buildTestWidget());

        // Advance to awaitingEmail
        await tester.enterText(find.byType(TextField), 'ashe@example.com');
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        // Reset and tap resend
        reset(authService);
        when(() => authService.sendMagicLink(any()))
            .thenAnswer((_) async {});

        await tester.tap(find.text('Resend email'));
        await tester.pumpAndSettle();

        verify(() => authService.sendMagicLink('ashe@example.com')).called(1);
      });
    });

    group('phoneNumber step', () {
      Future<void> advanceToPhone(WidgetTester tester) async {
        when(() => authService.sendMagicLink(any()))
            .thenAnswer((_) async {});
        when(() => authService.getCurrentUser())
            .thenAnswer((_) async => null);

        await tester.pumpWidget(buildTestWidget());

        // email → awaitingEmail
        await tester.enterText(find.byType(TextField), 'ashe@example.com');
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        // Simulate magic link auth callback
        final container = ProviderScope.containerOf(
          tester.element(find.byType(OnboardingScreen)),
        );
        await container.read(onboardingProvider.notifier).onAuthStateChanged();
        await tester.pumpAndSettle();
      }

      testWidgets('renders phone number field', (tester) async {
        await advanceToPhone(tester);

        expect(find.text('Your phone number'), findsOneWidget);
        expect(find.text('Phone number'), findsOneWidget);
        expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      });

      testWidgets('tapping back signs out and returns to emailEntry',
          (tester) async {
        when(() => authService.signOut()).thenAnswer((_) async {});

        await advanceToPhone(tester);
        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();

        verify(() => authService.signOut()).called(1);
        expect(find.text('roger'), findsOneWidget);
      });

      testWidgets('tapping Continue with valid number advances',
          (tester) async {
        when(() => authService.isPhoneNumberTaken(any()))
            .thenAnswer((_) async => false);

        await advanceToPhone(tester);

        await tester.enterText(find.byType(TextField), '+15551234567');
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        expect(find.text('Find your people'), findsOneWidget);
      });

      testWidgets('empty phone number shows error', (tester) async {
        await advanceToPhone(tester);

        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        expect(find.textContaining('cannot be empty'), findsOneWidget);
      });
    });

    group('contactsPermission step', () {
      Future<void> advanceToContacts(WidgetTester tester) async {
        when(() => authService.sendMagicLink(any()))
            .thenAnswer((_) async {});
        when(() => authService.getCurrentUser())
            .thenAnswer((_) async => null);
        when(() => authService.isPhoneNumberTaken(any()))
            .thenAnswer((_) async => false);

        await tester.pumpWidget(buildTestWidget());

        // email → awaitingEmail
        await tester.enterText(find.byType(TextField), 'ashe@example.com');
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        // Simulate auth callback
        final container = ProviderScope.containerOf(
          tester.element(find.byType(OnboardingScreen)),
        );
        await container.read(onboardingProvider.notifier).onAuthStateChanged();
        await tester.pumpAndSettle();

        // phone → contacts
        await tester.enterText(find.byType(TextField), '+15551234567');
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
      }

      testWidgets('renders Allow contacts and Not now buttons',
          (tester) async {
        await advanceToContacts(tester);

        expect(find.text('Find your people'), findsOneWidget);
        expect(find.text('Allow contacts'), findsOneWidget);
        expect(find.text('Not now'), findsOneWidget);
      });

      testWidgets('tapping back returns to phone number', (tester) async {
        await advanceToContacts(tester);

        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();

        expect(find.text('Your phone number'), findsOneWidget);
      });
    });
  });
}
