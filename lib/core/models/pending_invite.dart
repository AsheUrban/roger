class PendingInvite {
  final String id;
  final String phoneNumber;
  final String invitingUserId;
  final String conversationId;
  final String messageId;
  final DateTime expiresAt;
  final DateTime? nudgeSentAt;
  final DateTime createdAt;

  const PendingInvite({
    required this.id,
    required this.phoneNumber,
    required this.invitingUserId,
    required this.conversationId,
    required this.messageId,
    required this.expiresAt,
    this.nudgeSentAt,
    required this.createdAt,
  });
}
