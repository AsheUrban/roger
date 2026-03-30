class MessageView {
  final String id;
  final String messageId;
  final String userId;
  final DateTime downloadedAt;
  final DateTime? viewedAt;

  const MessageView({
    required this.id,
    required this.messageId,
    required this.userId,
    required this.downloadedAt,
    this.viewedAt,
  });
}
