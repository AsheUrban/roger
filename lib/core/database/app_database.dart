import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'local_conversation_member.dart';
import 'local_conversation_member_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [LocalConversationMembers], daos: [LocalConversationMemberDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;
}

/// Opens the encrypted database. Called once in main() after the key is ready.
///
/// Encryption is provided by SQLite3MultipleCiphers (`sqlite3mc`), selected
/// via the `hooks.user_defines.sqlite3.source` block in pubspec.yaml. The
/// hook ships prebuilt native binaries for every supported platform, so no
/// runtime `open.overrideFor(...)` plumbing is needed. `PRAGMA key` is
/// honored by sqlite3mc out of the box.
Future<AppDatabase> openAppDatabase(String key) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File(p.join(dir.path, 'roger.db'));

  return AppDatabase(
    NativeDatabase.createInBackground(
      file,
      setup: (db) {
        db.execute("PRAGMA key = '$key'");
      },
    ),
  );
}
