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
