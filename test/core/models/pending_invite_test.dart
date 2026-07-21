import 'package:flutter_test/flutter_test.dart';
import 'package:roger/core/models/pending_invite.dart';

// Reshaped for single-pick (spec §10): the invite holds inviteToken +
// invitedPhoneHash (a peppered hash), never a raw phone number.

PendingInvite _invite({
  String id = 'inv-1',
  String inviteToken = 'tok-1',
  String invitedPhoneHash = 'hash-abc',
  String invitingUserId = 'u-1',
  String conversationId = 'conv-1',
  String messageId = 'msg-1',
  DateTime? expiresAt,
  DateTime? nudgeSentAt,
  DateTime? createdAt,
}) {
  return PendingInvite(
    id: id,
    inviteToken: inviteToken,
    invitedPhoneHash: invitedPhoneHash,
    invitingUserId: invitingUserId,
    conversationId: conversationId,
    messageId: messageId,
    expiresAt: expiresAt ?? DateTime(2026, 1, 8),
    nudgeSentAt: nudgeSentAt,
    createdAt: createdAt ?? DateTime(2026, 1, 1),
  );
}

void main() {
  group('PendingInvite model', () {
    test('holds inviteToken + invitedPhoneHash, no raw phone number', () {
      final invite = _invite();
      expect(invite.inviteToken, 'tok-1');
      expect(invite.invitedPhoneHash, 'hash-abc');
      expect(invite.invitingUserId, 'u-1');
      expect(invite.conversationId, 'conv-1');
      expect(invite.messageId, 'msg-1');
    });

    test('nudgeSentAt is nullable (optional day-3 nudge)', () {
      expect(_invite().nudgeSentAt, isNull);
      expect(_invite(nudgeSentAt: DateTime(2026, 1, 4)).nudgeSentAt,
          DateTime(2026, 1, 4));
    });

    test('expiresAt carries the 7-day window set server-side', () {
      final created = DateTime(2026, 1, 1);
      final invite = _invite(createdAt: created, expiresAt: DateTime(2026, 1, 8));
      expect(invite.expiresAt.difference(invite.createdAt).inDays, 7);
    });
  });
}
