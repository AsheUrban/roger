class User {
  final String id;
  final String email;
  final String phoneNumber;
  final String displayName;
  final String avatarColor;
  final bool phoneVerified;
  final DateTime? lastActiveAt;
  final DateTime createdAt;

  const User({
    required this.id,
    required this.email,
    required this.phoneNumber,
    required this.displayName,
    required this.avatarColor,
    this.phoneVerified = false,
    this.lastActiveAt,
    required this.createdAt,
  });
}
