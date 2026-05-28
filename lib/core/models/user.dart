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

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User &&
        other.id == id &&
        other.phoneNumber == phoneNumber &&
        other.avatarColor == avatarColor &&
        other.recoveryEmail == recoveryEmail &&
        other.lastActiveAt == lastActiveAt &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode => Object.hash(
        id,
        phoneNumber,
        avatarColor,
        recoveryEmail,
        lastActiveAt,
        createdAt,
      );
}
