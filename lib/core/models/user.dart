class User {
  final String id;
  final String phoneNumber;
  final String displayName;
  final String avatarColor;
  final String? email;
  final bool recoveryEmailVerified;
  final DateTime? lastActiveAt;
  final DateTime createdAt;

  const User({
    required this.id,
    required this.phoneNumber,
    required this.displayName,
    required this.avatarColor,
    this.email,
    this.recoveryEmailVerified = false,
    this.lastActiveAt,
    required this.createdAt,
  });
}
