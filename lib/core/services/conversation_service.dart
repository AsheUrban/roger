import 'package:supabase_flutter/supabase_flutter.dart';

/// Owns conversation creation against Supabase.
///
/// All conversation creation flows (1:1 chat, group chat, invite-pending)
/// route through [createConversation], which calls the `create_conversation`
/// Postgres function. The function performs the
/// `conversations` and `conversation_members` inserts atomically under
/// `security definer`, avoiding the RLS chicken-and-egg where `.select()`
/// on the conversation insert would otherwise fail before the caller is
/// a member.
class ConversationService {
  final SupabaseClient _client;

  ConversationService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Creates a conversation with the given member ids and returns the new
  /// conversation id. The caller's user id must be present in [memberIds];
  /// the RPC enforces this server-side.
  Future<String> createConversation({
    String? name,
    required List<String> memberIds,
  }) async {
    final result = await _client.rpc(
      'create_conversation',
      params: {
        'p_name': name,
        'p_member_ids': memberIds,
      },
    );
    return result as String;
  }

  /// Returns the id of the existing 1:1 conversation between [currentUserId]
  /// and [otherUserId], or creates a new one and returns its id. Never
  /// creates duplicates — spec §9 (Search): tapping Chat must open the
  /// existing conversation when one exists.
  Future<String> findOrCreate1to1({
    required String currentUserId,
    required String otherUserId,
  }) async {
    final myMemberships = await _client
        .from('conversation_members')
        .select('conversation_id')
        .eq('user_id', currentUserId)
        .isFilter('left_at', null);

    final theirMemberships = await _client
        .from('conversation_members')
        .select('conversation_id')
        .eq('user_id', otherUserId)
        .isFilter('left_at', null);

    final mine =
        (myMemberships as List).map((r) => r['conversation_id']).toSet();
    final theirs =
        (theirMemberships as List).map((r) => r['conversation_id']).toSet();
    final shared = mine.intersection(theirs);

    if (shared.isNotEmpty) return shared.first as String;

    return createConversation(memberIds: [currentUserId, otherUserId]);
  }

  /// Leave a group conversation (spec §9): sets `left_at` on the caller's own
  /// membership row so future messages no longer reach them. Their prior
  /// messages stay for the remaining members and roll off naturally. The
  /// "update own" RLS policy (`user_id = auth.uid()`) permits exactly this.
  Future<void> leaveGroup({
    required String conversationId,
    required String currentUserId,
  }) async {
    await _client
        .from('conversation_members')
        .update({'left_at': DateTime.now().toUtc().toIso8601String()})
        .eq('conversation_id', conversationId)
        .eq('user_id', currentUserId);
  }
}
