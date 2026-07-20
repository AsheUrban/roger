import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'added_contacts.dart';
import 'added_contacts_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [AddedContacts],
  daos: [AddedContactsDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 3;

  // The drift DB is a rebuildable local cache (the people you've picked who are
  // on roger), not a source of truth — everything here is re-derived from a
  // re-pick. Pre-launch, with no data worth migrating, schema changes are
  // handled by a destructive recreate: drop everything and rebuild. Avoids
  // hand-written column migrations for a cache that costs nothing to repopulate.
  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // Dropped in v3. It is no longer in `allTables`, so the loop below
          // cannot reach it — a device coming from v1/v2 would keep it forever
          // without this explicit drop. Deleted members now render a fixed
          // treatment (spec §4), so nothing needs its cached avatar color.
          await customStatement(
            'DROP TABLE IF EXISTS local_conversation_members',
          );

          for (final table in allTables) {
            await m.deleteTable(table.actualTableName);
          }
          await m.createAll();
        },
      );
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
