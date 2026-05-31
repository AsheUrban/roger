import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth_notifier.dart';
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
      if (!ref.mounted) return;
      state = state.copyWith(
        phoneNumber: trimmed,
        step: OnboardingStep.otpVerification,
        isLoading: false,
      );
    } catch (e) {
      if (!ref.mounted) return;
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
      if (!ref.mounted) return;
      state = state.copyWith(isLoading: false);
    } catch (e) {
      if (!ref.mounted) return;
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

    // Phase 1: verify the OTP code. Skipped on retry — if a session already
    // exists, the code was consumed by a previous successful verify and the
    // retry is only about finishing account creation. Re-submitting the
    // consumed code would fail at the provider and surface as a misleading
    // "invalid code" error.
    if (_authService.currentSession == null) {
      try {
        await _authService.verifyOtp(
          phoneNumber: state.phoneNumber,
          otpCode: trimmed,
        );
        if (!ref.mounted) return;
      } catch (_) {
        if (!ref.mounted) return;
        state = state.copyWith(
          isLoading: false,
          error: () => 'Invalid or expired code. Please try again.',
        );
        return;
      }
    }

    // Phase 2 + 3: look up the existing public.users row (if any), or create
    // one for a new user. Bundled under a single catch — both lookup and
    // write failures present the same "setup failed" face to the user since
    // the cause doesn't change what they do next (tap Verify again).
    //
    // Account creation lives here, not at the contacts step, so abandoning
    // mid-onboarding after this point still leaves a complete account on
    // the server and the user lands in-app on relaunch (per spec §18).
    try {
      final existing = await _authService.getCurrentUser();
      if (!ref.mounted) return;

      if (existing != null) {
        // Existing user — already onboarded. Flip cached auth state to
        // Onboarded before the screen's `context.go('/search')` so the
        // synchronous redirect sees the new state and doesn't bounce.
        ref.read(authProvider.notifier).markOnboarded();
        state = state.copyWith(
          isLoading: false,
          onboardingComplete: true,
        );
        return;
      }

      // New user — pick avatar color (reuse the one already in state if a
      // prior attempt picked it; keeps retries on the same color) and
      // create the public.users row. Persist the color BEFORE the await so
      // a failure mid-write still leaves it in state for the retry path.
      final color = state.avatarColor.isNotEmpty
          ? state.avatarColor
          : avatarColors[_random.nextInt(avatarColors.length)];
      state = state.copyWith(avatarColor: color);

      await _authService.createAccount(
        phoneNumber: state.phoneNumber,
        avatarColor: color,
      );
      if (!ref.mounted) return;
      state = state.copyWith(
        step: OnboardingStep.contactsPermission,
        isLoading: false,
      );
    } catch (_) {
      if (!ref.mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: () =>
            "Couldn't finish setting up your account. Please try again.",
      );
    }
  }

  Future<void> requestContactsPermission() async {
    final granted = await _contactsService.requestPermission();
    if (!ref.mounted) return;

    if (granted) {
      // Fire and forget — hashed batch check runs in background,
      // must not block landing on Search (spec AC)
      _contactsService.refreshBatchCheck();
    }

    await completeOnboarding();
  }

  Future<void> skipContactsPermission() async {
    ref.read(contactsDeclinedProvider.notifier).setDeclined(true);
    await completeOnboarding();
  }

  Future<void> completeOnboarding() async {
    // Account creation moved to verifyOtp (spec §18). This is now just the
    // post-permission handoff: flip cached auth state to Onboarded before
    // the screen's `context.go('/search')` so the synchronous redirect sees
    // the new state and doesn't bounce.
    ref.read(authProvider.notifier).markOnboarded();
    state = state.copyWith(onboardingComplete: true);
  }
}
