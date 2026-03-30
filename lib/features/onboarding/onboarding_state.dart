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
  });
}
