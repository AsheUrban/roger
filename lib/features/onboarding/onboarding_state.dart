enum OnboardingStep {
  emailEntry,
  awaitingEmail,
  phoneNumber,
  displayName,
  contactsPermission,
}

class OnboardingState {
  final OnboardingStep step;
  final String email;
  final String phoneNumber;
  final String displayName;
  final String avatarColor;
  final bool isLoading;
  final String? error;
  final bool onboardingComplete;

  const OnboardingState({
    this.step = OnboardingStep.emailEntry,
    this.email = '',
    this.phoneNumber = '',
    this.displayName = '',
    this.avatarColor = '',
    this.isLoading = false,
    this.error,
    this.onboardingComplete = false,
  });

  OnboardingState copyWith({
    OnboardingStep? step,
    String? email,
    String? phoneNumber,
    String? displayName,
    String? avatarColor,
    bool? isLoading,
    String? Function()? error,
    bool? onboardingComplete,
  }) {
    return OnboardingState(
      step: step ?? this.step,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      displayName: displayName ?? this.displayName,
      avatarColor: avatarColor ?? this.avatarColor,
      isLoading: isLoading ?? this.isLoading,
      error: error != null ? error() : this.error,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
    );
  }
}
