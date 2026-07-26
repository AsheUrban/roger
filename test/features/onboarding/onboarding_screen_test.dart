import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:roger/core/models/user.dart';
import 'package:roger/core/providers.dart';
import 'package:roger/core/services/auth_service.dart';
import 'package:roger/core/services/key_service.dart';
import 'package:roger/features/onboarding/onboarding_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

class MockAuthService extends Mock implements AuthService {}

class MockKeyService extends Mock implements KeyService {}

class MockRandom extends Mock implements Random {}

void main() {
  late MockAuthService authService;
  late MockKeyService keyService;
  late MockRandom random;

  setUp(() {
    authService = MockAuthService();
    keyService = MockKeyService();
    random = MockRandom();
    when(() => random.nextInt(any())).thenReturn(2);
    when(() => authService.currentSession).thenReturn(null);
    when(() => authService.authEvents)
        .thenAnswer((_) => Stream<AuthChangeEvent>.empty());
    when(() => keyService.ensureOwnKeyPair())
        .thenAnswer((_) async => (publicKey: 'pub', privateKey: 'priv'));
  });

  Widget buildTestWidget() {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const OnboardingScreen()),
        GoRoute(path: '/search', builder: (_, _) => const SizedBox.shrink()),
      ],
    );
    return ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(authService),
        keyServiceProvider.overrideWithValue(keyService),
        randomProvider.overrideWithValue(random),
      ],
      child: MaterialApp.router(routerConfig: router),
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
        when(() => authService.sendOtp(any())).thenAnswer((_) async {});

        await tester.pumpWidget(buildTestWidget());
        await tester.enterText(find.byType(TextField).last, '5550001000');
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
        when(() => authService.sendOtp(any())).thenAnswer((_) async {});
        await tester.pumpWidget(buildTestWidget());
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

        // Drain the resend-cooldown timer so the test ends cleanly.
        await tester.pump(const Duration(seconds: 31));
      });

      testWidgets('Resend is disabled for 30 seconds after the send, then '
          'enabled (spec §18)', (tester) async {
        await advanceToOtp(tester);

        // During cooldown: tapping does nothing beyond the initial send.
        await tester.tap(find.text('Resend code'));
        await tester.pumpAndSettle();
        verify(() => authService.sendOtp(any())).called(1);

        // After 30s the button re-enables and resends.
        await tester.pump(const Duration(seconds: 31));
        await tester.tap(find.text('Resend code'));
        await tester.pumpAndSettle();
        verify(() => authService.sendOtp(any())).called(1);

        await tester.pump(const Duration(seconds: 31));
      });

      testWidgets('tapping back returns to phoneEntry', (tester) async {
        await advanceToOtp(tester);

        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();

        expect(find.text('roger'), findsOneWidget);
        expect(find.text('Phone number'), findsOneWidget);
      });

      testWidgets('tapping Verify with valid code calls verifyOtp',
          (tester) async {
        await advanceToOtp(tester);

        when(() => authService.verifyOtp(
              phoneNumber: any(named: 'phoneNumber'),
              otpCode: any(named: 'otpCode'),
            )).thenAnswer((_) async => AuthResponse(session: null, user: null));
        when(() => authService.getCurrentUser()).thenAnswer((_) async => null);
        when(() => authService.createAccount(
              avatarColor: any(named: 'avatarColor'),
            )).thenAnswer((_) async => User(
              id: 'new-id',
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

        // Drain the resend-cooldown timer so the test ends cleanly.
        await tester.pump(const Duration(seconds: 31));
      });
    });
  });
}
