import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../../core/database/local_conversation_member_dao.dart';
import '../../core/models/conversation.dart';
import '../../core/models/user.dart';
import '../../core/providers.dart';
import '../../core/services/contacts_service.dart';
import 'conversations_state.dart';

final conversationsProvider =
    NotifierProvider<ConversationsNotifier, ConversationsState>(
  ConversationsNotifier.new,
);

class ConversationsNotifier extends Notifier<ConversationsState> {
  late final ContactsService _contactsService;
  late final SupabaseClient _client;
  RealtimeChannel? _channel;

  @override
  ConversationsState build() {
    _contactsService = ref.read(contactsServiceProvider);
    _client = ref.read(supabaseClientProvider);

    ref.onDispose(() {
      if (_channel != null) {
        _client.removeChannel(_channel!);
      }
    });

    // microtask ensures build() returns before any state mutations
    Future.microtask(_initAsync);
    return const ConversationsState();
  }

  Future<void> _initAsync() async {
    await loadConversations();
    if (!ref.mounted) return;
    _setupRealtime();
  }

  void _setupRealtime() {
    try {
      _channel = _client
          .channel('public:messages')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'messages',
            callback: (payload) {
              final rec = payload.newRecord;
              final convId = rec['conversation_id'] as String?;
              final senderId = rec['sender_id'] as String?;
              final createdAtStr = rec['created_at'] as String?;
              if (convId == null || senderId == null || createdAtStr == null) {
                return;
              }
              onNewMessage(
                conversationId: convId,
                senderId: senderId,
                createdAt: DateTime.parse(createdAtStr),
              );
            },
          )
          .subscribe();
    } catch (_) {
      // Realtime unavailable (e.g. in unit tests with mock client)
    }
  }

  Future<void> loadConversations() async {
    final currentUserId = ref.read(currentUserIdProvider);
    if (currentUserId == null) return;

    final dao = LocalConversationMemberDao(ref.read(appDatabaseProvider));

    state = state.copyWith(isLoading: true, error: () => null);

    try {
      // Get active memberships with conversation data
      final memberships = await _client
          .from('conversation_members')
          .select('conversation_id, conversations!inner(id, name, created_at)')
          .eq('user_id', currentUserId)
          .isFilter('left_at', null);

      final summaries = <ConversationSummary>[];

      for (final m in memberships as List) {
        final convId = m['conversation_id'] as String;
        final convData = m['conversations'] as Map<String, dynamic>;
        final conversation = Conversation(
          id: convData['id'] as String,
          name: convData['name'] as String?,
          createdAt: DateTime.parse(convData['created_at'] as String),
        );

        // Get other active members with user data (null join = deleted user).
        // .or() instead of .neq() because SQL evaluates NULL != x as NULL (not true),
        // which silently drops rows where user_id IS NULL after account deletion.
        final otherRows = await _client
            .from('conversation_members')
            .select(
                'id, users(id, phone_number, avatar_color, recovery_email, last_active_at, created_at)')
            .eq('conversation_id', convId)
            .or('user_id.neq.$currentUserId,user_id.is.null')
            .isFilter('left_at', null);

        final members = <User>[];
        final deletedMemberIds = <String>[];

        for (final row in otherRows as List) {
          final memberId = row['id'] as String;
          final ud = row['users'];

          if (ud != null) {
            // Active user — upsert into drift so we have a cached record if they ever delete
            await dao.upsertMember(
              memberId: memberId,
              conversationId: convId,
              userId: ud['id'] as String,
              phoneNumber: ud['phone_number'] as String,
              avatarColor: ud['avatar_color'] as String,
            );
            members.add(User(
              id: ud['id'] as String,
              phoneNumber: ud['phone_number'] as String,
              avatarColor: ud['avatar_color'] as String,
              recoveryEmail: ud['recovery_email'] as String?,
              lastActiveAt: ud['last_active_at'] != null
                  ? DateTime.parse(ud['last_active_at'] as String)
                  : null,
              createdAt: DateTime.parse(ud['created_at'] as String),
            ));
          } else {
            // Deleted user — drift already holds their cached data from when they were active
            deletedMemberIds.add(memberId);
          }
        }

        // Resolve deleted member names from drift cache
        final deletedNames = <String>[];
        for (final memberId in deletedMemberIds) {
          final phone = await dao.getPhoneNumber(memberId);
          if (phone != null) {
            final contact = _contactsService.cachedContacts
                .where((c) => c.phoneNumber == phone)
                .firstOrNull;
            deletedNames.add(contact?.name ?? 'Deleted user');
          } else {
            deletedNames.add('Deleted user');
          }
        }

        // Get last message timestamp and basic unread status
        final lastMessages = await _client
            .from('messages')
            .select('created_at, sender_id')
            .eq('conversation_id', convId)
            .order('created_at', ascending: false)
            .limit(1);

        DateTime? lastMessageAt;
        bool hasUnread = false;

        if (lastMessages.isNotEmpty) {
          final lm = lastMessages.first;
          lastMessageAt = DateTime.parse(lm['created_at'] as String);
          final senderId = lm['sender_id'] as String?;
          hasUnread = senderId != null && senderId != currentUserId;
        }

        // Presence: active if any other member was active within the last 5 minutes
        final now = DateTime.now();
        bool isOtherUserActive = false;
        DateTime? otherUserLastActiveAt;

        for (final member in members) {
          final lat = member.lastActiveAt;
          if (lat != null) {
            if (now.difference(lat).inMinutes < 5) isOtherUserActive = true;
            if (otherUserLastActiveAt == null ||
                lat.isAfter(otherUserLastActiveAt)) {
              otherUserLastActiveAt = lat;
            }
          }
        }

        summaries.add(ConversationSummary(
          conversation: conversation,
          displayName: _resolveDisplayName(members, deletedNames, conversation),
          members: members,
          memberContactNames: _resolveMemberContactNames(members),
          lastMessageAt: lastMessageAt,
          hasUnread: hasUnread,
          isOtherUserActive: isOtherUserActive,
          otherUserLastActiveAt: otherUserLastActiveAt,
        ));
      }

      _sortByMostRecent(summaries);
      if (!ref.mounted) return;
      state = state.copyWith(conversations: summaries, isLoading: false);
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(isLoading: false, error: () => e.toString());
    }
  }

  Future<void> refreshConversations() => loadConversations();

  /// Pure state mutation — reads currentUserId fresh via ref so this method
  /// works correctly in unit tests without storing state from build().
  void onNewMessage({
    required String conversationId,
    required String senderId,
    required DateTime createdAt,
  }) {
    final currentUserId = ref.read(currentUserIdProvider);
    final isFromOther = senderId != currentUserId;

    final updated = state.conversations.map((summary) {
      if (summary.conversation.id != conversationId) return summary;
      return summary.copyWith(
        lastMessageAt: () => createdAt,
        hasUnread: isFromOther ? true : summary.hasUnread,
      );
    }).toList();

    _sortByMostRecent(updated);
    state = state.copyWith(conversations: updated);
  }

  // Display name: group name if set, otherwise contact names for active members
  // plus resolved names for deleted members. Falls back to '?' for unsaved numbers.
  String _resolveDisplayName(
    List<User> members,
    List<String> deletedNames,
    Conversation conversation,
  ) {
    if (conversation.name != null) return conversation.name!;
    final activeNames = members.map((m) {
      final contact = _contactsService.cachedContacts
          .where((c) => c.phoneNumber == m.phoneNumber)
          .firstOrNull;
      return contact?.name ?? '?';
    });
    final all = [...activeNames, ...deletedNames];
    if (all.isEmpty) return '?';
    return all.join(', ');
  }

  // Contact name for each member — parallel list used by the screen for avatar initials.
  List<String> _resolveMemberContactNames(List<User> members) {
    return members.map((m) {
      final contacts = _contactsService.cachedContacts
          .where((c) => c.phoneNumber == m.phoneNumber);
      return contacts.isEmpty ? '?' : contacts.first.name;
    }).toList();
  }

  void _sortByMostRecent(List<ConversationSummary> list) {
    list.sort((a, b) {
      final aTime = a.lastMessageAt;
      final bTime = b.lastMessageAt;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });
  }
}
