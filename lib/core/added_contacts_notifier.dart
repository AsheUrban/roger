import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

/// Exposes the `userId → captured contact name` map used for name resolution
/// (spec §10), hydrated from the AddedContacts drift store. Holding it as
/// reactive Riverpod state is what lets ConversationsNotifier / SearchNotifier
/// re-resolve display names when a freshly-picked contact lands — the "?" fix.
class AddedContactsNotifier extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() {
    // Hydrate from drift after build() returns; map is empty until then.
    Future.microtask(refresh);
    return const {};
  }

  /// Reloads the map from the AddedContacts drift store.
  Future<void> refresh() async {
    final contacts = await ref.read(appDatabaseProvider).addedContactsDao.getAddedContacts();
    if (!ref.mounted) return;
    state = {for (final c in contacts) c.userId: c.contactName};
  }

  /// Records a picked contact (persists to drift) and updates the in-memory map
  /// immediately so dependents re-resolve without waiting for a reload.
  Future<void> addContact({
    required String userId,
    required String contactName,
    required String avatarColor,
  }) async {
    await ref.read(appDatabaseProvider).addedContactsDao.upsertAddedContact(
          userId: userId,
          contactName: contactName,
          avatarColor: avatarColor,
        );
    if (!ref.mounted) return;
    state = {...state, userId: contactName};
  }
}

final addedContactsProvider =
    NotifierProvider<AddedContactsNotifier, Map<String, String>>(
  AddedContactsNotifier.new,
);
