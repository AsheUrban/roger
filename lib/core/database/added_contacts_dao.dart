import 'package:drift/drift.dart';

import 'added_contacts.dart';
import 'app_database.dart';

part 'added_contacts_dao.g.dart';

@DriftAccessor(tables: [AddedContacts])
class AddedContactsDao extends DatabaseAccessor<AppDatabase>
    with _$AddedContactsDaoMixin {
  AddedContactsDao(super.db);

  /// Records a picked contact that resolved on roger, or refreshes an existing
  /// one (re-pick → same userId → row updated in place per spec §10).
  Future<void> upsertAddedContact({
    required String userId,
    required String contactName,
    required String avatarColor,
  }) {
    return into(addedContacts).insertOnConflictUpdate(
      AddedContactsCompanion.insert(
        userId: userId,
        contactName: contactName,
        avatarColor: avatarColor,
      ),
    );
  }

  Future<List<AddedContact>> getAddedContacts() {
    return select(addedContacts).get();
  }
}
