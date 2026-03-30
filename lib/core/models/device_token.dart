class DeviceToken {
  final String id;
  final String userId;
  final String token;
  final String platform;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DeviceToken({
    required this.id,
    required this.userId,
    required this.token,
    required this.platform,
    required this.createdAt,
    required this.updatedAt,
  });
}
