class ReactionVideo {
  final String id;
  final String parentMessageId;
  final String senderId;
  final String r2Key;
  final DateTime createdAt;

  const ReactionVideo({
    required this.id,
    required this.parentMessageId,
    required this.senderId,
    required this.r2Key,
    required this.createdAt,
  });
}
