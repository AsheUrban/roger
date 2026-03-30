class ConversationKey {
  final String id;
  final String conversationId;
  final String userId;
  final String encryptedConversationKey;
  final DateTime createdAt;
  final DateTime? retiredAt;

  const ConversationKey({
    required this.id,
    required this.conversationId,
    required this.userId,
    required this.encryptedConversationKey,
    required this.createdAt,
    this.retiredAt,
  });
}
