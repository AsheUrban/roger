class ConversationMember {
  final String id;
  final String conversationId;
  final String? userId; // null when user has deleted their account (ON DELETE SET NULL)
  final DateTime joinedAt;
  final DateTime? leftAt;
  final List<String>? customEmoji;
  final String? wildcardEmoji;
  final bool muted;

  const ConversationMember({
    required this.id,
    required this.conversationId,
    this.userId,
    required this.joinedAt,
    this.leftAt,
    this.customEmoji,
    this.wildcardEmoji,
    this.muted = false,
  });
}
