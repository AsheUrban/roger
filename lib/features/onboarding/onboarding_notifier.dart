import 'dart:math';

import '../../core/services/auth_service.dart';
import '../../core/services/contacts_service.dart';
import 'onboarding_state.dart';

const avatarColors = [
  'Deep Red',
  'Rust',
  'Deep Ember',
  'Burnt Orange',
  'Salmon',
  'Rose',
  'Olive',
  'Cornflower',
  'Charcoal',
];

class OnboardingNotifier {
  final AuthService _authService;
  final ContactsService _contactsService;
  final Random _random;
  OnboardingState state = const OnboardingState();

  OnboardingNotifier({
    required AuthService authService,
    required ContactsService contactsService,
    Random? random,
  })  : _authService = authService,
        _contactsService = contactsService,
        _random = random ?? Random();

  void goBack() {
    final previous = switch (state.step) {
      OnboardingStep.phoneEntry => OnboardingStep.phoneEntry,
      OnboardingStep.otpVerification => OnboardingStep.phoneEntry,
      OnboardingStep.displayName => OnboardingStep.otpVerification,
      OnboardingStep.avatarColor => OnboardingStep.displayName,
      OnboardingStep.recoveryEmail => OnboardingStep.avatarColor,
      OnboardingStep.contactsPermission => OnboardingStep.recoveryEmail,
    };
    state = state.copyWith(step: previous, error: () => null);
  }

  Future<void> submitPhoneNumber(String phoneNumber) async {
    state = state.copyWith(
      isLoading: true,
      error: () => null,
    );

    try {
      await _authService.sendOtp(phoneNumber);
      state = state.copyWith(
        phoneNumber: phoneNumber,
        step: OnboardingStep.otpVerification,
        isLoading: false,
        canResendOtp: false,
      );

      // 30-second cooldown before resend is available
      Future.delayed(const Duration(seconds: 30), () {
        if (state.step == OnboardingStep.otpVerification) {
          state = state.copyWith(canResendOtp: true);
        }
      });
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: () => e.toString(),
      );
    }
  }

  Future<void> verifyOtp(String otp) async {
    if (state.otpAttemptsRemaining <= 0) {
      state = state.copyWith(
        error: () => 'Too many attempts. Please request a new code.',
        step: OnboardingStep.phoneEntry,
        otpAttemptsRemaining: 5,
      );
      return;
    }

    state = state.copyWith(
      isLoading: true,
      error: () => null,
    );

    try {
      final user = await _authService.verifyOtp(state.phoneNumber, otp);

      if (user != null) {
        // Existing user — log them in, skip onboarding
        state = state.copyWith(
          isLoading: false,
          onboardingComplete: true,
        );
      } else {
        // New user — continue onboarding
        final defaultColor = avatarColors[_random.nextInt(avatarColors.length)];
        state = state.copyWith(
          otp: otp,
          step: OnboardingStep.displayName,
          avatarColor: defaultColor,
          isLoading: false,
        );
      }
    } catch (e) {
      final remaining = state.otpAttemptsRemaining - 1;
      if (remaining <= 0) {
        state = state.copyWith(
          isLoading: false,
          otpAttemptsRemaining: 5,
          step: OnboardingStep.phoneEntry,
          error: () => 'Too many attempts. Please request a new code.',
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          otpAttemptsRemaining: remaining,
          error: () => 'Incorrect code. $remaining attempts remaining.',
        );
      }
    }
  }

  Future<void> resendOtp() async {
    if (!state.canResendOtp) return;

    state = state.copyWith(canResendOtp: false);

    try {
      await _authService.sendOtp(state.phoneNumber);

      Future.delayed(const Duration(seconds: 30), () {
        if (state.step == OnboardingStep.otpVerification) {
          state = state.copyWith(canResendOtp: true);
        }
      });
    } catch (e) {
      state = state.copyWith(
        error: () => e.toString(),
        canResendOtp: true,
      );
    }
  }

  void setDisplayName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      state = state.copyWith(
        error: () => 'Display name cannot be empty.',
      );
      return;
    }
    if (trimmed.length > 50) {
      state = state.copyWith(
        error: () => 'Display name must be 50 characters or less.',
      );
      return;
    }

    state = state.copyWith(
      displayName: trimmed,
      step: OnboardingStep.avatarColor,
      error: () => null,
    );
  }

  /// Preview a color without advancing. User can browse freely.
  void setAvatarColor(String color) {
    if (!avatarColors.contains(color)) return;

    state = state.copyWith(
      avatarColor: color,
      error: () => null,
    );
  }

  /// Confirm the selected color and advance to recovery email.
  void confirmAvatarColor() {
    state = state.copyWith(
      step: OnboardingStep.recoveryEmail,
      error: () => null,
    );
  }

  void setRecoveryEmail(String email) {
    state = state.copyWith(
      recoveryEmail: () => email,
      step: OnboardingStep.contactsPermission,
      error: () => null,
    );
  }

  void skipRecoveryEmail() {
    state = state.copyWith(
      recoveryEmail: () => null,
      step: OnboardingStep.contactsPermission,
      error: () => null,
    );
  }

  Future<void> requestContactsPermission() async {
    final granted = await _contactsService.requestPermission();

    if (granted) {
      // Fire and forget — hashed batch check runs in background,
      // must not block landing on Search (spec AC)
      _contactsService.refreshBatchCheck();
    }

    // Whether granted or denied, onboarding continues
    await completeOnboarding();
  }

  Future<void> skipContactsPermission() async {
    await completeOnboarding();
  }

  Future<void> completeOnboarding() async {
    state = state.copyWith(
      isLoading: true,
      error: () => null,
    );

    try {
      await _authService.createAccount(
        phoneNumber: state.phoneNumber,
        displayName: state.displayName,
        avatarColor: state.avatarColor,
        recoveryEmail: state.recoveryEmail,
      );

      state = state.copyWith(
        isLoading: false,
        onboardingComplete: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: () => e.toString(),
      );
    }
  }
}
