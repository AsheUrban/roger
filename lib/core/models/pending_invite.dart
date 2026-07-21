/// A pending invite (spec §10). Holds an opaque `inviteToken` (in the shared
/// link) and the peppered `invitedPhoneHash` — never a raw phone number. On the
/// invitee's signup, their own `phone_hash` matches `invitedPhoneHash` to surface
/// this invite in-app.
class PendingInvite {
  final String id;
  final String inviteToken;
  final String invitedPhoneHash;
  final String invitingUserId;
  final String conversationId;
  final String messageId;
  final DateTime expiresAt;
  final DateTime? nudgeSentAt;
  final DateTime createdAt;

  const PendingInvite({
    required this.id,
    required this.inviteToken,
    required this.invitedPhoneHash,
    required this.invitingUserId,
    required this.conversationId,
    required this.messageId,
    required this.expiresAt,
    this.nudgeSentAt,
    required this.createdAt,
  });
}
