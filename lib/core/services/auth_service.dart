import '../models/user.dart';

class AuthService {
  Future<void> sendOtp(String phoneNumber) async {}
  Future<User?> verifyOtp(String phoneNumber, String otp) async => null;
  Future<User> createAccount({
    required String phoneNumber,
    required String displayName,
    required String avatarColor,
    String? recoveryEmail,
  }) async => throw UnimplementedError();
  Future<User?> getCurrentUser() async => null;
  Future<void> signOut() async {}
  Future<void> deleteAccount() async {}
  Future<void> updatePhoneNumber(String newNumber, String otp) async {}
  Future<void> updateDisplayName(String name) async {}
  Future<void> updateAvatarColor(String color) async {}
  Future<void> setRecoveryEmail(String email) async {}
}
