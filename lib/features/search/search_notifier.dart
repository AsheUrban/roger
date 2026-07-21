import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/added_contacts_notifier.dart';
import '../../core/providers.dart';
import '../../core/services/contacts_service.dart';
import '../../core/services/conversation_service.dart';
import 'search_state.dart';

final searchProvider =
    NotifierProvider<SearchNotifier, SearchState>(SearchNotifier.new);

class SearchNotifier extends Notifier<SearchState> {
  late final ContactsService _contactsService;
  late final ConversationService _conversationService;
  late final String? _currentUserId;

  @override
  SearchState build() {
    _contactsService = ref.read(contactsServiceProvider);
    _conversationService = ref.read(conversationServiceProvider);
    _currentUserId = ref.read(currentUserIdProvider);

    // Re-load the added-contacts list whenever the store changes (e.g. a fresh
    // pick lands), so the list stays in sync without a manual refresh.
    ref.listen(addedContactsProvider, (_, _) => _loadAddedContacts());

    Future.microtask(_loadAddedContacts);
    return const SearchState();
  }

  /// Loads the "people you've added" list from the AddedContacts drift store,
  /// applying the current name filter. Everyone in the store is on roger
  /// (they only land there when `discover_user` matched).
  Future<void> _loadAddedContacts() async {
    final rows =
        await ref.read(appDatabaseProvider).addedContactsDao.getAddedContacts();
    if (!ref.mounted) return;
    state = state.copyWith(results: _buildResults(rows, filter: state.query));
  }

  List<AddedContactResult> _buildResults(
    List<dynamic> rows, {
    String? filter,
  }) {
    final q = (filter ?? '').toLowerCase();
    final results = rows
        .where((r) => q.isEmpty || (r.contactName as String).toLowerCase().contains(q))
        .map((r) => AddedContactResult(
              userId: r.userId as String,
              contactName: r.contactName as String,
              avatarColor: r.avatarColor as String,
            ))
        .toList();
    results.sort((a, b) =>
        a.contactName.toLowerCase().compareTo(b.contactName.toLowerCase()));
    return results;
  }

  /// Filters the added-contacts list by name. Local only — there is no server
  /// search under single-pick (finding someone new is an explicit pick).
  Future<void> search(String query) async {
    state = state.copyWith(query: query, error: () => null);
    await _loadAddedContacts();
  }

  /// Opens the OS contact picker for one contact, checks it against roger via
  /// `discover_user`, and — if matched — records it in AddedContacts (which
  /// re-loads the list). A non-roger pick sets [SearchState.notOnRogerName]
  /// (inviting them is a later slice). A cancelled pick is a no-op.
  Future<void> addSomeone() async {
    state = state.copyWith(notOnRogerName: () => null, error: () => null);

    final picked = await _contactsService.pickContact();
    if (!ref.mounted || picked == null) return;

    try {
      final match = await _contactsService.discover(picked.phoneNumber);
      if (!ref.mounted) return;

      if (match == null) {
        state = state.copyWith(notOnRogerName: () => picked.name);
        return;
      }

      // A roger match — record the picked name + discovered color. The
      // addedContactsProvider listener re-loads the list.
      await ref.read(addedContactsProvider.notifier).addContact(
            userId: match.userId,
            contactName: picked.name,
            avatarColor: match.avatarColor,
          );
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(error: () => e.toString());
    }
  }

  /// Open the existing 1:1 with this user, or create one if none exists.
  Future<String> startChat(String userId) {
    return _conversationService.findOrCreate1to1(
      currentUserId: _currentUserId!,
      otherUserId: userId,
    );
  }

  // ── Group mode ──────────────────────────────────────────────────────────

  void enterGroupMode() {
    state = state.copyWith(isGroupMode: true, selectedUserIds: []);
  }

  void enterGroupModeWithContact(String userId) {
    state = state.copyWith(isGroupMode: true, selectedUserIds: [userId]);
  }

  void exitGroupMode() {
    state = state.copyWith(isGroupMode: false, selectedUserIds: []);
  }

  void toggleContactSelection(String userId) {
    final current = List<String>.from(state.selectedUserIds);
    if (current.contains(userId)) {
      current.remove(userId);
    } else {
      // Groups capped at 5 — you + 4 others.
      if (current.length >= 4) return;
      current.add(userId);
    }
    state = state.copyWith(selectedUserIds: current);
  }

  /// Create a group conversation with the selected members.
  Future<String> createGroupConversation({String? name}) async {
    final currentUserId = _currentUserId!;
    final convId = await _conversationService.createConversation(
      name: name,
      memberIds: [currentUserId, ...state.selectedUserIds],
    );
    exitGroupMode();
    return convId;
  }
}
