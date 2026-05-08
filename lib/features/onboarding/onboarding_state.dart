enum OnboardingStep {
  phoneEntry,
  otpVerification,
  contactsPermission,
}

class OnboardingState {
  final OnboardingStep step;
  final String phoneNumber;
  final String avatarColor;
  final bool isLoading;
  final String? error;
  final bool onboardingComplete;

  const OnboardingState({
    this.step = OnboardingStep.phoneEntry,
    this.phoneNumber = '',
    this.avatarColor = '',
    this.isLoading = false,
    this.error,
    this.onboardingComplete = false,
  });

  OnboardingState copyWith({
    OnboardingStep? step,
    String? phoneNumber,
    String? avatarColor,
    bool? isLoading,
    String? Function()? error,
    bool? onboardingComplete,
  }) {
    return OnboardingState(
      step: step ?? this.step,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      avatarColor: avatarColor ?? this.avatarColor,
      isLoading: isLoading ?? this.isLoading,
      error: error != null ? error() : this.error,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
    );
  }
}
