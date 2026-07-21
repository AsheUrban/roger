import 'package:drift/drift.dart';

// The people you've deliberately picked who resolved on roger via `discover_user`
// (spec §10 single-pick discovery). This is the single source for the Search
// "people you've added" list and for name resolution.
//
// The name is captured from the OS contact picker at add-time and refreshed by
// re-picking — there is no address-book re-scan and no raw phone number stored
// here. userId is the primary key, so re-picking the same person updates the row
// in place (refreshes the captured name and avatar color).
class AddedContacts extends Table {
  TextColumn get userId => text()();
  TextColumn get contactName => text()();
  TextColumn get avatarColor => text()();

  @override
  Set<Column> get primaryKey => {userId};
}
