import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roger/core/database/app_database.dart';

// Tests use NativeDatabase.memory() — no encryption needed for in-memory test
// databases. sqlite3mc encryption is exercised on real devices. DAO logic only.
//
// AddedContacts is the drift store for single-pick contact discovery: the people
// you've deliberately picked who resolved on roger via `discover_user`. It is the
// single source for the Search "people you've added" list and for name resolution
// (spec §10). Names are captured from the OS picker at add-time and refreshed by
// re-picking — there is no address-book re-scan and no raw phone number here.

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('AddedContactsDao', () {
    group('upsertAddedContact', () {
      test('inserts a new added contact with all fields', () async {
        await db.addedContactsDao.upsertAddedContact(
          userId: 'user-1',
          contactName: 'Jordan',
          avatarColor: 'Rust',
        );

        final contacts = await db.addedContactsDao.getAddedContacts();
        expect(contacts.length, 1);
        expect(contacts.first.userId, 'user-1');
        expect(contacts.first.contactName, 'Jordan');
        expect(contacts.first.avatarColor, 'Rust');
      });

      test(
        're-picking the same person overwrites the captured name and color',
        () async {
          // First pick captures "Jordan" / Rust.
          await db.addedContactsDao.upsertAddedContact(
            userId: 'user-1',
            contactName: 'Jordan',
            avatarColor: 'Rust',
          );

          // Re-pick after the contact was renamed in the phone, and the user's
          // avatar color changed server-side. Spec §10: re-picking refreshes the
          // captured name. Same userId → one row, updated in place.
          await db.addedContactsDao.upsertAddedContact(
            userId: 'user-1',
            contactName: 'Jordan Lee',
            avatarColor: 'Cornflower',
          );

          final contacts = await db.addedContactsDao.getAddedContacts();
          expect(contacts.length, 1);
          expect(contacts.first.contactName, 'Jordan Lee');
          expect(contacts.first.avatarColor, 'Cornflower');
        },
      );

      test('stores multiple distinct added contacts', () async {
        await db.addedContactsDao.upsertAddedContact(
          userId: 'user-1',
          contactName: 'Jordan',
          avatarColor: 'Rust',
        );
        await db.addedContactsDao.upsertAddedContact(
          userId: 'user-2',
          contactName: 'Casey',
          avatarColor: 'Olive',
        );

        final contacts = await db.addedContactsDao.getAddedContacts();
        expect(contacts.length, 2);
        expect(
          contacts.map((c) => c.userId).toSet(),
          {'user-1', 'user-2'},
        );
      });
    });

    group('getAddedContacts', () {
      test('returns an empty list when nothing has been added', () async {
        final contacts = await db.addedContactsDao.getAddedContacts();
        expect(contacts, isEmpty);
      });
    });
  });
}
