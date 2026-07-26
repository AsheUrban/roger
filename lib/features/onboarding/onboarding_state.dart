enum OnboardingStep {
  phoneEntry,
  otpVerification,
}

class OnboardingState {
  final OnboardingStep step;
  final String phoneNumber;
  final String avatarColor;
  final bool isLoading;
  final String? error;
  final bool onboardingComplete;
  // Seconds until Resend re-enables (spec §18: available after 30 seconds).
  // 0 = resend allowed.
  final int resendCooldown;

  const OnboardingState({
    this.step = OnboardingStep.phoneEntry,
    this.phoneNumber = '',
    this.avatarColor = '',
    this.isLoading = false,
    this.error,
    this.onboardingComplete = false,
    this.resendCooldown = 0,
  });

  OnboardingState copyWith({
    OnboardingStep? step,
    String? phoneNumber,
    String? avatarColor,
    bool? isLoading,
    String? Function()? error,
    bool? onboardingComplete,
    int? resendCooldown,
  }) {
    return OnboardingState(
      step: step ?? this.step,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      avatarColor: avatarColor ?? this.avatarColor,
      isLoading: isLoading ?? this.isLoading,
      error: error != null ? error() : this.error,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      resendCooldown: resendCooldown ?? this.resendCooldown,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OnboardingState &&
        other.step == step &&
        other.phoneNumber == phoneNumber &&
        other.avatarColor == avatarColor &&
        other.isLoading == isLoading &&
        other.error == error &&
        other.onboardingComplete == onboardingComplete &&
        other.resendCooldown == resendCooldown;
  }

  @override
  int get hashCode => Object.hash(
        step,
        phoneNumber,
        avatarColor,
        isLoading,
        error,
        onboardingComplete,
        resendCooldown,
      );
}
