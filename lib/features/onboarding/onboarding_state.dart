enum OnboardingStep {
  phoneEntry,
  otpVerification,
  displayName,
  avatarColor,
  recoveryEmail,
  contactsPermission,
}

class OnboardingState {
  final OnboardingStep step;
  final String phoneNumber;
  final String otp;
  final String displayName;
  final String avatarColor;
  final String? recoveryEmail;
  final int otpAttemptsRemaining;
  final bool isLoading;
  final String? error;
  final bool canResendOtp;
  final bool onboardingComplete;

  const OnboardingState({
    this.step = OnboardingStep.phoneEntry,
    this.phoneNumber = '',
    this.otp = '',
    this.displayName = '',
    this.avatarColor = '',
    this.recoveryEmail,
    this.otpAttemptsRemaining = 5,
    this.isLoading = false,
    this.error,
    this.canResendOtp = false,
    this.onboardingComplete = false,
  });

  OnboardingState copyWith({
    OnboardingStep? step,
    String? phoneNumber,
    String? otp,
    String? displayName,
    String? avatarColor,
    String? Function()? recoveryEmail,
    int? otpAttemptsRemaining,
    bool? isLoading,
    String? Function()? error,
    bool? canResendOtp,
    bool? onboardingComplete,
  }) {
    return OnboardingState(
      step: step ?? this.step,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      otp: otp ?? this.otp,
      displayName: displayName ?? this.displayName,
      avatarColor: avatarColor ?? this.avatarColor,
      recoveryEmail: recoveryEmail != null ? recoveryEmail() : this.recoveryEmail,
      otpAttemptsRemaining: otpAttemptsRemaining ?? this.otpAttemptsRemaining,
      isLoading: isLoading ?? this.isLoading,
      error: error != null ? error() : this.error,
      canResendOtp: canResendOtp ?? this.canResendOtp,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
    );
  }
}
