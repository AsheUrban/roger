import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/user.dart';
import '../../core/providers.dart';
import '../../core/services/contacts_service.dart';
import '../../core/services/conversation_service.dart';
import '../../core/services/invite_service.dart';
import 'search_state.dart';

final searchProvider =
    NotifierProvider<SearchNotifier, SearchState>(SearchNotifier.new);

class SearchNotifier extends Notifier<SearchState> {
  late final ContactsService _contactsService;
  late final ConversationService _conversationService;
  late final InviteService _inviteService;
  late final String? _currentUserId;
  Timer? _debounceTimer;
  bool _refreshInFlight = false;

  @override
  SearchState build() {
    _contactsService = ref.read(contactsServiceProvider);
    _conversationService = ref.read(conversationServiceProvider);
    _inviteService = ref.read(inviteServiceProvider);
    _currentUserId = ref.read(currentUserIdProvider);

    ref.onDispose(() {
      _debounceTimer?.cancel();
    });

    // Check permission and load contacts if granted
    _initAsync();

    return const SearchState();
  }

  Future<void> _initAsync() async {
    // Respect user's choice to skip contacts during onboarding,
    // even if OS permission was already granted from a previous install
    final declined = ref.read(contactsDeclinedProvider);
    if (declined) return;

    final granted = await _contactsService.hasPermission();
    if (!ref.mounted) return;
    if (granted) {
      state = state.copyWith(hasContactsPermission: true);
      loadInitialContacts();
    }
  }

  Future<void> loadInitialContacts() async {
    state = state.copyWith(isLoading: true, error: () => null);

    try {
      await _contactsService.refreshBatchCheck();
      state = state.copyWith(
        hasContactsPermission: true,
        results: _buildResults(),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: () => e.toString(),
      );
    }
  }

  /// Triggered on app foreground and by pull-to-refresh on Search.
  /// Re-runs the hashed batch check and updates results. No-op if the user
  /// declined contacts during onboarding, has not granted OS permission, or
  /// a refresh is already in flight.
  Future<void> refreshContacts() async {
    if (_refreshInFlight) return;
    if (ref.read(contactsDeclinedProvider)) return;
    if (!state.hasContactsPermission) return;
    _refreshInFlight = true;
    try {
      await _contactsService.refreshBatchCheck();
      state = state.copyWith(results: _buildResults(filter: state.query));
    } finally {
      _refreshInFlight = false;
    }
  }

  Future<void> requestContactsPermission() async {
    final granted = await _contactsService.requestPermission();
    if (granted) {
      // Clear the declined flag — user has now explicitly granted permission
      ref.read(contactsDeclinedProvider.notifier).setDeclined(false);
      state = state.copyWith(hasContactsPermission: true);
      await loadInitialContacts();
    }
  }

  Future<void> search(String query) async {
    state = state.copyWith(query: query, error: () => null);

    if (query.isEmpty) {
      state = state.copyWith(results: _buildResults());
      return;
    }

    // Immediate local filter
    state = state.copyWith(results: _buildResults(filter: query));

    // Debounced server check to catch new signups
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final serverResult = await _contactsService.onDemandSearch(query);
        if (serverResult != null) {
          // Re-filter with updated data
          state = state.copyWith(results: _buildResults(filter: query));
        }
      } catch (_) {
        // Network failure on server check — fall back to local only
      }
    });
  }

  /// Open the existing 1:1 with this user, or create one if none exists.
  Future<String> startChat(String userId) {
    return _conversationService.findOrCreate1to1(
      currentUserId: _currentUserId!,
      otherUserId: userId,
    );
  }

  /// Create the pending conversation + invite for a non-roger contact, and
  /// reflect the pending state in the search results.
  Future<void> sendInvite(String phoneNumber) async {
    try {
      await _inviteService.sendInvite(
        phoneNumber: phoneNumber,
        currentUserId: _currentUserId!,
      );
      state = state.copyWith(
        results: state.results
            .map((r) => r.phoneNumber == phoneNumber
                ? SearchResult(
                    rogerUser: r.rogerUser,
                    contactName: r.contactName,
                    phoneNumber: r.phoneNumber,
                    isOnRoger: r.isOnRoger,
                    hasPendingInvite: true,
                  )
                : r)
            .toList(),
      );
    } catch (e) {
      state = state.copyWith(error: () => e.toString());
    }
  }

  /// Build SearchResult list from cached contacts + roger users.
  /// Sorted alphabetically by contact name.
  List<SearchResult> _buildResults({String? filter}) {
    final contacts = _contactsService.cachedContacts;
    final rogerUsers = _contactsService.cachedRogerUsers;

    // Build phone → roger user lookup
    final rogerByPhone = <String, User>{};
    for (final user in rogerUsers) {
      rogerByPhone[user.phoneNumber] = user;
    }

    final results = <SearchResult>[];
    final seenPhones = <String>{};

    for (final contact in contacts) {
      if (seenPhones.contains(contact.phoneNumber)) continue;
      seenPhones.add(contact.phoneNumber);

      final rogerUser = rogerByPhone[contact.phoneNumber];

      // Skip showing yourself
      if (rogerUser != null && rogerUser.id == _currentUserId) continue;

      // Apply local text filter — contact name only
      if (filter != null && filter.isNotEmpty) {
        final q = filter.toLowerCase();
        final nameMatch = contact.name.toLowerCase().contains(q);
        if (!nameMatch) continue;
      }

      results.add(SearchResult(
        rogerUser: rogerUser,
        contactName: contact.name,
        phoneNumber: contact.phoneNumber,
        isOnRoger: rogerUser != null,
      ));
    }

    // Sort alphabetically by contact name
    results.sort((a, b) {
      return a.contactName.toLowerCase().compareTo(b.contactName.toLowerCase());
    });

    return results;
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
      // Groups capped at 5 — you + 4 others
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
