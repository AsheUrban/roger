class ReactionEmoji {
  final String id;
  final String messageId;
  final String userId;
  final String emoji;
  final DateTime createdAt;

  const ReactionEmoji({
    required this.id,
    required this.messageId,
    required this.userId,
    required this.emoji,
    required this.createdAt,
  });
}
