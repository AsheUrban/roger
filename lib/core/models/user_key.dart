class UserKey {
  final String id;
  final String userId;
  final String publicKey;
  final DateTime createdAt;
  final DateTime? retiredAt;

  const UserKey({
    required this.id,
    required this.userId,
    required this.publicKey,
    required this.createdAt,
    this.retiredAt,
  });
}
