import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../../core/models/user.dart';
import '../../core/providers.dart';
import '../../core/services/contacts_service.dart';
import 'search_state.dart';

final searchProvider =
    NotifierProvider<SearchNotifier, SearchState>(SearchNotifier.new);

class SearchNotifier extends Notifier<SearchState> {
  late final ContactsService _contactsService;
  late final SupabaseClient _client;
  late final String? _currentUserId;
  Timer? _debounceTimer;

  @override
  SearchState build() {
    _contactsService = ref.read(contactsServiceProvider);
    _client = ref.read(supabaseClientProvider);
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

  Future<void> requestContactsPermission() async {
    final granted = await _contactsService.requestPermission();
    if (granted) {
      // Clear the declined flag — user has now explicitly granted permission
      ref.read(contactsDeclinedProvider.notifier).state = false;
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

  /// Check if a 1:1 conversation already exists with this user.
  /// If yes, return its ID. If no, create one. Never create duplicates.
  Future<String> startChat(String userId) async {
    final currentUserId = _currentUserId!;

    // Find existing 1:1 conversation
    final myMemberships = await _client
        .from('conversation_members')
        .select('conversation_id')
        .eq('user_id', currentUserId)
        .isFilter('left_at', null);

    final theirMemberships = await _client
        .from('conversation_members')
        .select('conversation_id')
        .eq('user_id', userId)
        .isFilter('left_at', null);

    final myConvIds =
        (myMemberships as List).map((r) => r['conversation_id']).toSet();
    final theirConvIds =
        (theirMemberships as List).map((r) => r['conversation_id']).toSet();
    final shared = myConvIds.intersection(theirConvIds);

    if (shared.isNotEmpty) {
      return shared.first as String;
    }

    // Create new conversation
    final conv = await _client
        .from('conversations')
        .insert({'created_at': DateTime.now().toUtc().toIso8601String()})
        .select('id')
        .single();

    final convId = conv['id'] as String;
    final now = DateTime.now().toUtc().toIso8601String();

    await _client.from('conversation_members').insert([
      {
        'conversation_id': convId,
        'user_id': currentUserId,
        'joined_at': now,
      },
      {
        'conversation_id': convId,
        'user_id': userId,
        'joined_at': now,
      },
    ]);

    return convId;
  }

  /// Create pending conversation + invite row for a non-roger contact.
  // TODO: SMS invite via deep link (step 5 full implementation)
  Future<void> sendInvite(String phoneNumber) async {
    final currentUserId = _currentUserId!;
    final now = DateTime.now().toUtc();

    try {
      // Create conversation
      final conv = await _client
          .from('conversations')
          .insert({'created_at': now.toIso8601String()})
          .select('id')
          .single();

      final convId = conv['id'] as String;

      // Add current user as member
      await _client.from('conversation_members').insert({
        'conversation_id': convId,
        'user_id': currentUserId,
        'joined_at': now.toIso8601String(),
      });

      // Create a placeholder message for the invite
      final msg = await _client
          .from('messages')
          .insert({
            'conversation_id': convId,
            'sender_id': currentUserId,
            'type': 'note',
            'encrypted_text': '', // placeholder
            'created_at': now.toIso8601String(),
          })
          .select('id')
          .single();

      // Create pending invite with 7-day expiry
      await _client.from('pending_invites').insert({
        'phone_number': phoneNumber,
        'inviting_user_id': currentUserId,
        'conversation_id': convId,
        'message_id': msg['id'] as String,
        'expires_at': now.add(const Duration(days: 7)).toIso8601String(),
        'created_at': now.toIso8601String(),
      });

      // Update local state to show pending
      final updatedResults = state.results.map((r) {
        if (r.phoneNumber == phoneNumber) {
          return SearchResult(
            rogerUser: r.rogerUser,
            contactName: r.contactName,
            phoneNumber: r.phoneNumber,
            isOnRoger: r.isOnRoger,
            hasPendingInvite: true,
          );
        }
        return r;
      }).toList();

      state = state.copyWith(results: updatedResults);
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
}
