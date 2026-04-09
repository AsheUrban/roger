import 'package:drift/drift.dart';

// Caches conversation member identity so deleted users can still be displayed.
// memberId is conversation_members.id from Supabase — stable even after user deletion.
class LocalConversationMembers extends Table {
  TextColumn get memberId => text()();
  TextColumn get conversationId => text()();
  TextColumn get userId => text().nullable()();
  TextColumn get phoneNumber => text()();
  TextColumn get avatarColor => text()();

  @override
  Set<Column> get primaryKey => {memberId};
}
