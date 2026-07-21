import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roger/core/added_contacts_notifier.dart';
import 'package:roger/core/database/app_database.dart';
import 'package:roger/core/providers.dart';

// addedContactsProvider exposes the userId→capturedName map used for name
// resolution (spec §10), hydrated from the AddedContacts drift store. Exposing
// it as reactive Riverpod state is what lets ConversationsNotifier / SearchNotifier
// re-resolve when a newly-picked contact lands — the display-name "?" fix.

void main() {
  late AppDatabase appDatabase;

  setUp(() {
    appDatabase = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async => appDatabase.close());

  ProviderContainer makeContainer() {
    return ProviderContainer.test(
      overrides: [
        appDatabaseProvider.overrideWithValue(appDatabase),
      ],
    );
  }

  group('AddedContactsNotifier', () {
    test('map is empty when nothing has been added', () {
      final container = makeContainer();
      expect(container.read(addedContactsProvider), isEmpty);
    });

    test('refresh hydrates the userId→name map from the drift store', () async {
      await appDatabase.addedContactsDao.upsertAddedContact(
        userId: 'u1',
        contactName: 'Jordan',
        avatarColor: 'Rust',
      );
      await appDatabase.addedContactsDao.upsertAddedContact(
        userId: 'u2',
        contactName: 'Casey',
        avatarColor: 'Olive',
      );

      final container = makeContainer();
      await container.read(addedContactsProvider.notifier).refresh();

      final map = container.read(addedContactsProvider);
      expect(map['u1'], 'Jordan');
      expect(map['u2'], 'Casey');
    });

    test('addContact persists to drift and updates the in-memory map',
        () async {
      final container = makeContainer();

      await container.read(addedContactsProvider.notifier).addContact(
            userId: 'u1',
            contactName: 'Jordan',
            avatarColor: 'Rust',
          );

      // In-memory map updated immediately (drives the reactive re-resolve).
      expect(container.read(addedContactsProvider)['u1'], 'Jordan');

      // And persisted to drift so it survives a restart.
      final stored = await appDatabase.addedContactsDao.getAddedContacts();
      expect(
        stored.any((c) => c.userId == 'u1' && c.contactName == 'Jordan'),
        isTrue,
      );
    });

    test('re-adding the same person updates their name in the map', () async {
      final container = makeContainer();
      final notifier = container.read(addedContactsProvider.notifier);

      await notifier.addContact(
        userId: 'u1',
        contactName: 'Jordan',
        avatarColor: 'Rust',
      );
      await notifier.addContact(
        userId: 'u1',
        contactName: 'Jordan Lee',
        avatarColor: 'Cornflower',
      );

      final map = container.read(addedContactsProvider);
      expect(map['u1'], 'Jordan Lee');
      expect(map.length, 1);
    });
  });
}
