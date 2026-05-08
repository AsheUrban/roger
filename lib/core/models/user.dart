class User {
  final String id;
  final String phoneNumber;
  final String avatarColor;
  final String? recoveryEmail;
  final DateTime? lastActiveAt;
  final DateTime createdAt;

  const User({
    required this.id,
    required this.phoneNumber,
    required this.avatarColor,
    this.recoveryEmail,
    this.lastActiveAt,
    required this.createdAt,
  });
}
