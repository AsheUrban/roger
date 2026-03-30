import 'onboarding_state.dart';

class OnboardingNotifier {
  OnboardingState state = const OnboardingState();

  Future<void> submitPhoneNumber(String phoneNumber) async {}
  Future<void> verifyOtp(String otp) async {}
  Future<void> resendOtp() async {}
  Future<void> setDisplayName(String name) async {}
  Future<void> setAvatarColor(String color) async {}
  Future<void> setRecoveryEmail(String email) async {}
  Future<void> skipRecoveryEmail() async {}
  Future<void> requestContactsPermission() async {}
  Future<void> completeOnboarding() async {}
}
