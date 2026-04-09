import 'package:drift/drift.dart';

import 'app_database.dart';
import 'local_conversation_member.dart';

part 'local_conversation_member_dao.g.dart';

@DriftAccessor(tables: [LocalConversationMembers])
class LocalConversationMemberDao extends DatabaseAccessor<AppDatabase>
    with _$LocalConversationMemberDaoMixin {
  LocalConversationMemberDao(super.db);

  Future<void> upsertMember({
    required String memberId,
    required String conversationId,
    String? userId,
    required String phoneNumber,
    required String avatarColor,
  }) {
    return into(localConversationMembers).insertOnConflictUpdate(
      LocalConversationMembersCompanion.insert(
        memberId: memberId,
        conversationId: conversationId,
        userId: Value(userId),
        phoneNumber: phoneNumber,
        avatarColor: avatarColor,
      ),
    );
  }

  Future<String?> getPhoneNumber(String memberId) async {
    final row = await (select(localConversationMembers)
          ..where((t) => t.memberId.equals(memberId)))
        .getSingleOrNull();
    return row?.phoneNumber;
  }

  Future<List<LocalConversationMember>> getMembersForConversation(
      String conversationId) {
    return (select(localConversationMembers)
          ..where((t) => t.conversationId.equals(conversationId)))
        .get();
  }
}
