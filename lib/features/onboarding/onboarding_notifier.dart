import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/contacts_service.dart';
import '../../core/theme/colors.dart';
import 'onboarding_state.dart';

// Single source of truth — derived from the avatar color map so the random
// pick can never include a color that isn't actually defined.
final avatarColors = avatarColorMap.keys.toList();

final onboardingProvider =
    NotifierProvider<OnboardingNotifier, OnboardingState>(
  OnboardingNotifier.new,
);

class OnboardingNotifier extends Notifier<OnboardingState> {
  late final AuthService _authService;
  late final ContactsService _contactsService;
  late final Random _random;

  @override
  OnboardingState build() {
    _authService = ref.read(authServiceProvider);
    _contactsService = ref.read(contactsServiceProvider);
    _random = ref.read(randomProvider);
    return const OnboardingState();
  }

  void goBack() {
    final previous = switch (state.step) {
      OnboardingStep.phoneEntry => OnboardingStep.phoneEntry,
      OnboardingStep.otpVerification => OnboardingStep.phoneEntry,
      OnboardingStep.contactsPermission => OnboardingStep.otpVerification,
    };

    state = state.copyWith(step: previous, error: () => null);
  }

  Future<void> sendOtp(String phone) async {
    final trimmed = phone.trim();
    if (trimmed.isEmpty) {
      state = state.copyWith(
        error: () => 'Phone number cannot be empty.',
      );
      return;
    }

    state = state.copyWith(
      isLoading: true,
      error: () => null,
    );

    try {
      await _authService.sendOtp(trimmed);
      state = state.copyWith(
        phoneNumber: trimmed,
        step: OnboardingStep.otpVerification,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: () => e.toString(),
      );
    }
  }

  Future<void> resendOtp() async {
    state = state.copyWith(
      isLoading: true,
      error: () => null,
    );

    try {
      await _authService.sendOtp(state.phoneNumber);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: () => e.toString(),
      );
    }
  }

  Future<void> verifyOtp(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) {
      state = state.copyWith(
        error: () => 'Please enter the verification code.',
      );
      return;
    }

    state = state.copyWith(
      isLoading: true,
      error: () => null,
    );

    try {
      await _authService.verifyOtp(
        phoneNumber: state.phoneNumber,
        otpCode: trimmed,
      );

      // Check if this phone number already has an account
      final existingUser = await _authService.getCurrentUser();

      if (existingUser != null) {
        // Existing user — skip onboarding
        state = state.copyWith(
          isLoading: false,
          onboardingComplete: true,
        );
      } else {
        // New user — assign random avatar color, continue onboarding
        final defaultColor = avatarColors[_random.nextInt(avatarColors.length)];
        state = state.copyWith(
          avatarColor: defaultColor,
          step: OnboardingStep.contactsPermission,
          isLoading: false,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: () => 'Invalid or expired code. Please try again.',
      );
    }
  }

  Future<void> requestContactsPermission() async {
    final granted = await _contactsService.requestPermission();

    if (granted) {
      // Fire and forget — hashed batch check runs in background,
      // must not block landing on Search (spec AC)
      _contactsService.refreshBatchCheck();
    }

    await completeOnboarding();
  }

  Future<void> skipContactsPermission() async {
    ref.read(contactsDeclinedProvider.notifier).state = true;
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
        avatarColor: state.avatarColor,
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
