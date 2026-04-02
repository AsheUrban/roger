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

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  void goBack() {
    final previous = switch (state.step) {
      OnboardingStep.emailEntry => OnboardingStep.emailEntry,
      OnboardingStep.awaitingEmail => OnboardingStep.emailEntry,
      OnboardingStep.phoneNumber => OnboardingStep.awaitingEmail,
      OnboardingStep.displayName => OnboardingStep.phoneNumber,
      OnboardingStep.contactsPermission => OnboardingStep.displayName,
    };
    state = state.copyWith(step: previous, error: () => null);
  }

  Future<void> sendMagicLink(String email) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty || !_emailPattern.hasMatch(trimmed)) {
      state = state.copyWith(
        error: () => 'Please enter a valid email address.',
      );
      return;
    }

    state = state.copyWith(
      isLoading: true,
      error: () => null,
    );

    try {
      await _authService.sendMagicLink(trimmed);
      state = state.copyWith(
        email: trimmed,
        step: OnboardingStep.awaitingEmail,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: () => e.toString(),
      );
    }
  }

  Future<void> resendMagicLink() async {
    state = state.copyWith(
      isLoading: true,
      error: () => null,
    );

    try {
      await _authService.sendMagicLink(state.email);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: () => e.toString(),
      );
    }
  }

  /// Called when Supabase auth state changes to signed-in (magic link callback).
  /// Checks if the user already has a public.users row.
  Future<void> onAuthStateChanged() async {
    state = state.copyWith(isLoading: true, error: () => null);

    try {
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
          step: OnboardingStep.phoneNumber,
          avatarColor: defaultColor,
          isLoading: false,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: () => e.toString(),
      );
    }
  }

  Future<void> submitPhoneNumber(String phone) async {
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
      final taken = await _authService.isPhoneNumberTaken(trimmed);
      if (taken) {
        state = state.copyWith(
          isLoading: false,
          error: () => 'This phone number is already in use. '
              'Please enter a different number.',
        );
        return;
      }

      state = state.copyWith(
        phoneNumber: trimmed,
        step: OnboardingStep.displayName,
        isLoading: false,
      );
    } catch (e) {
      // Network failure — allow through, createAccount will catch duplicates
      state = state.copyWith(
        phoneNumber: trimmed,
        step: OnboardingStep.displayName,
        isLoading: false,
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
        email: state.email,
        phoneNumber: state.phoneNumber,
        displayName: state.displayName,
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
