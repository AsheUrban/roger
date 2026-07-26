import 'package:flutter_test/flutter_test.dart';
import 'package:roger/features/onboarding/onboarding_state.dart';

void main() {
  group('OnboardingState equality', () {
    test('two instances with the same field values are equal', () {
      final a = OnboardingState(
        step: OnboardingStep.otpVerification,
        phoneNumber: '+15551111111',
        avatarColor: 'Rust',
        isLoading: true,
        error: 'oops',
        onboardingComplete: true,
      );
      final b = OnboardingState(
        step: OnboardingStep.otpVerification,
        phoneNumber: '+15551111111',
        avatarColor: 'Rust',
        isLoading: true,
        error: 'oops',
        onboardingComplete: true,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('two default instances are equal', () {
      final a = OnboardingState();
      final b = OnboardingState();
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('not equal when step differs', () {
      final a = OnboardingState();
      final b = OnboardingState(step: OnboardingStep.otpVerification);
      expect(a, isNot(equals(b)));
    });

    test('not equal when phoneNumber differs', () {
      final a = OnboardingState();
      final b = OnboardingState(phoneNumber: '+15551111111');
      expect(a, isNot(equals(b)));
    });

    test('not equal when avatarColor differs', () {
      final a = OnboardingState();
      final b = OnboardingState(avatarColor: 'Rust');
      expect(a, isNot(equals(b)));
    });

    test('not equal when isLoading differs', () {
      final a = OnboardingState();
      final b = OnboardingState(isLoading: true);
      expect(a, isNot(equals(b)));
    });

    test('not equal when error differs', () {
      final a = OnboardingState();
      final b = OnboardingState(error: 'oops');
      expect(a, isNot(equals(b)));
    });

    test('not equal when onboardingComplete differs', () {
      final a = OnboardingState();
      final b = OnboardingState(onboardingComplete: true);
      expect(a, isNot(equals(b)));
    });

    test('not equal when resendCooldown differs', () {
      final a = OnboardingState();
      final b = OnboardingState(resendCooldown: 30);
      expect(a, isNot(equals(b)));
    });

    test('copyWith with no changes produces an equal instance', () {
      final a = OnboardingState(
        step: OnboardingStep.otpVerification,
        phoneNumber: '+15551111111',
        avatarColor: 'Rust',
      );
      final b = a.copyWith();
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
