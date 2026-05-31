import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:roger/core/models/user.dart';
import 'package:roger/core/providers.dart';
import 'package:roger/core/services/auth_service.dart';
import 'package:roger/core/services/contacts_service.dart';
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
      ],
      child: const MaterialApp(
        home: OnboardingScreen(),
      ),
    );
  }

  group('OnboardingScreen', () {
    group('phoneEntry step', () {
      testWidgets('renders roger wordmark, phone field, and Continue button',
          (tester) async {
        await tester.pumpWidget(buildTestWidget());

        expect(find.text('roger'), findsOneWidget);
        expect(find.text('Phone number'), findsOneWidget);
        expect(find.text('Continue'), findsOneWidget);
        expect(find.byIcon(Icons.arrow_back), findsNothing);
      });

      testWidgets('tapping Continue with valid phone calls sendOtp',
          (tester) async {
        when(() => authService.sendOtp(any()))
            .thenAnswer((_) async {});

        await tester.pumpWidget(buildTestWidget());

        // Enter local number only — country picker provides +1
        await tester.enterText(
          find.byType(TextField).last,
          '5550001000',
        );
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        verify(() => authService.sendOtp('+15550001000')).called(1);
      });

      testWidgets('tapping Continue with empty phone shows error',
          (tester) async {
        await tester.pumpWidget(buildTestWidget());

        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        expect(find.textContaining('cannot be empty'), findsOneWidget);
        verifyNever(() => authService.sendOtp(any()));
      });
    });

    group('otpVerification step', () {
      Future<void> advanceToOtp(WidgetTester tester) async {
        when(() => authService.sendOtp(any()))
            .thenAnswer((_) async {});

        await tester.pumpWidget(buildTestWidget());

        // phone → OTP (enter local number, picker provides +1)
        await tester.enterText(find.byType(TextField).last, '5550001000');
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
      }

      testWidgets('renders verification code field and Verify button',
          (tester) async {
        await advanceToOtp(tester);

        expect(find.text('Enter verification code'), findsOneWidget);
        expect(find.text('+15550001000'), findsOneWidget);
        expect(find.text('Verify'), findsOneWidget);
        expect(find.text('Resend code'), findsOneWidget);
        expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      });

      testWidgets('tapping back returns to phoneEntry', (tester) async {
        await advanceToOtp(tester);

        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();

        expect(find.text('roger'), findsOneWidget);
        expect(find.text('Phone number'), findsOneWidget);
      });

      testWidgets('tapping Resend code calls sendOtp again',
          (tester) async {
        await advanceToOtp(tester);

        reset(authService);
        when(() => authService.sendOtp(any()))
            .thenAnswer((_) async {});

        await tester.tap(find.text('Resend code'));
        await tester.pumpAndSettle();

        verify(() => authService.sendOtp('+15550001000')).called(1);
      });

      testWidgets('tapping Verify with valid code calls verifyOtp',
          (tester) async {
        await advanceToOtp(tester);

        when(() => authService.verifyOtp(
              phoneNumber: any(named: 'phoneNumber'),
              otpCode: any(named: 'otpCode'),
            )).thenAnswer((_) async => AuthResponse(
              session: null,
              user: null,
            ));
        when(() => authService.getCurrentUser())
            .thenAnswer((_) async => null);
        when(() => authService.createAccount(
              phoneNumber: any(named: 'phoneNumber'),
              avatarColor: any(named: 'avatarColor'),
            )).thenAnswer((_) async => User(
              id: 'new-id',
              phoneNumber: '+15550001000',
              avatarColor: 'Deep Ember',
              createdAt: DateTime.now(),
            ));

        await tester.enterText(find.byType(TextField), '123456');
        await tester.tap(find.text('Verify'));
        await tester.pumpAndSettle();

        verify(() => authService.verifyOtp(
              phoneNumber: '+15550001000',
              otpCode: '123456',
            )).called(1);
      });

      testWidgets('invalid OTP shows error', (tester) async {
        await advanceToOtp(tester);

        when(() => authService.verifyOtp(
              phoneNumber: any(named: 'phoneNumber'),
              otpCode: any(named: 'otpCode'),
            )).thenThrow(Exception('Invalid OTP'));

        await tester.enterText(find.byType(TextField), '000000');
        await tester.tap(find.text('Verify'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Invalid or expired'), findsOneWidget);
      });
    });

    group('contactsPermission step', () {
      Future<void> advanceToContacts(WidgetTester tester) async {
        when(() => authService.sendOtp(any()))
            .thenAnswer((_) async {});
        when(() => authService.verifyOtp(
              phoneNumber: any(named: 'phoneNumber'),
              otpCode: any(named: 'otpCode'),
            )).thenAnswer((_) async => AuthResponse(
              session: null,
              user: null,
            ));
        when(() => authService.getCurrentUser())
            .thenAnswer((_) async => null);
        when(() => authService.createAccount(
              phoneNumber: any(named: 'phoneNumber'),
              avatarColor: any(named: 'avatarColor'),
            )).thenAnswer((_) async => User(
              id: 'new-id',
              phoneNumber: '+15550001000',
              avatarColor: 'Deep Ember',
              createdAt: DateTime.now(),
            ));

        await tester.pumpWidget(buildTestWidget());

        // phone → OTP
        await tester.enterText(find.byType(TextField), '+15550001000');
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        // OTP → contacts
        await tester.enterText(find.byType(TextField), '123456');
        await tester.tap(find.text('Verify'));
        await tester.pumpAndSettle();
      }

      testWidgets('renders Allow contacts and Not now buttons',
          (tester) async {
        await advanceToContacts(tester);

        expect(find.text('Find your people'), findsOneWidget);
        expect(find.text('Allow contacts'), findsOneWidget);
        expect(find.text('Not now'), findsOneWidget);
      });

      testWidgets('tapping back returns to OTP verification', (tester) async {
        await advanceToContacts(tester);

        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();

        expect(find.text('Enter verification code'), findsOneWidget);
      });
    });
  });
}
