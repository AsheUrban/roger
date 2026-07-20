import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../../core/added_contacts_notifier.dart';
import '../../core/models/conversation.dart';
import '../../core/models/user.dart';
import '../../core/providers.dart';
import '../../core/utils/name_resolution.dart';
import 'conversations_state.dart';

final conversationsProvider =
    NotifierProvider<ConversationsNotifier, ConversationsState>(
  ConversationsNotifier.new,
);

class ConversationsNotifier extends Notifier<ConversationsState> {
  late final SupabaseClient _client;
  RealtimeChannel? _channel;

  @override
  ConversationsState build() {
    _client = ref.read(supabaseClientProvider);

    ref.onDispose(() {
      if (_channel != null) {
        _client.removeChannel(_channel!);
      }
    });

    // Re-resolve names live when a freshly-picked contact lands in the map —
    // the display-name "?" reactivity fix (spec §10).
    ref.listen(addedContactsProvider, (_, next) => reresolveNames(next));

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

    final addedNames = ref.read(addedContactsProvider);

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

        // Other active members + null-user (deleted) rows. .or() over .neq()
        // because SQL evaluates NULL != x as NULL (not true), which silently
        // drops rows where user_id IS NULL after account deletion. The join no
        // longer returns phone_number — that column is gone server-side; names
        // resolve from the addedContacts map by user_id (spec §10).
        final otherRows = await _client
            .from('conversation_members')
            .select(
                'id, users(id, avatar_color, last_active_at, created_at)')
            .eq('conversation_id', convId)
            .or('user_id.neq.$currentUserId,user_id.is.null')
            .isFilter('left_at', null);

        final members = <User>[];
        final memberContactNames = <String>[];
        final deletedNames = <String>[];

        for (final row in otherRows as List) {
          final ud = row['users'];

          if (ud != null) {
            final userId = ud['id'] as String;
            final avatarColor = ud['avatar_color'] as String;

            members.add(User(
              id: userId,
              // Transitional: the join no longer carries a phone, and the
              // User.phoneNumber field is removed in the auth slice (tracked).
              phoneNumber: '',
              avatarColor: avatarColor,
              lastActiveAt: ud['last_active_at'] != null
                  ? DateTime.parse(ud['last_active_at'] as String)
                  : null,
              createdAt: DateTime.parse(ud['created_at'] as String),
            ));
            memberContactNames.add(resolveMemberName(
              userId: userId,
              addedNames: addedNames,
            ));
          } else {
            // Deleted user — roger keeps no name, so this always resolves to
            // "Deleted user". The cached row (avatar color) is left untouched.
            deletedNames.add(resolveMemberName(
              userId: null,
              addedNames: addedNames,
            ));
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
          displayName: resolveConversationName(
            conversationName: conversation.name,
            memberNames: [...memberContactNames, ...deletedNames],
          ),
          members: members,
          memberContactNames: memberContactNames,
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

  /// Re-resolve every summary's member and display names against an updated
  /// `userId → name` map. Driven by `ref.listen(addedContactsProvider, ...)`,
  /// so a name a member resolved as "?" fills in the moment you pick them — the
  /// display-name "?" reactivity fix (spec §10).
  void reresolveNames(Map<String, String> addedNames) {
    final updated = state.conversations.map((summary) {
      final names = summary.members
          .map((member) => resolveMemberName(
                userId: member.id,
                addedNames: addedNames,
              ))
          .toList();
      return summary.copyWith(
        memberContactNames: names,
        displayName: resolveConversationName(
          conversationName: summary.conversation.name,
          memberNames: names,
        ),
      );
    }).toList();

    state = state.copyWith(conversations: updated);
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
