import 'package:supabase_flutter/supabase_flutter.dart';

/// Builds the caller's 1:1 partner map from the raw member rows of every
/// conversation they belong to. Pure — extracted (like `routerRedirect` /
/// `name_resolution`) so the true-1:1 rule is unit-testable without Supabase.
///
/// A **true 1:1** is a conversation with exactly two member rows total — the
/// caller and one other real user. Total rows, not active rows: leaving sets
/// `left_at` but keeps the row, so a group never collapses into a "1:1", and
/// membership is fixed at creation so a 1:1 can never grow into a group.
/// `hasReplied` is whether the PARTNER has sent a message there
/// (`first_message_at` set) — the §9 group-eligibility signal. Duplicate 1:1s
/// with the same partner merge, preferring a replied one, so eligibility is
/// never understated and Chat opens the live thread.
Map<String, ({String conversationId, bool hasReplied})>
    oneToOnePartnersFromRows(
  List<Map<String, dynamic>> memberRows,
  String currentUserId,
) {
  final byConversation = <String, List<Map<String, dynamic>>>{};
  for (final row in memberRows) {
    byConversation
        .putIfAbsent(row['conversation_id'] as String, () => [])
        .add(row);
  }

  final partners = <String, ({String conversationId, bool hasReplied})>{};
  for (final entry in byConversation.entries) {
    final rows = entry.value;
    if (rows.length != 2) continue; // groups are never 1:1s
    final mine = rows.where((r) => r['user_id'] == currentUserId);
    if (mine.length != 1) continue; // defensive: conversation isn't mine
    final other = rows.firstWhere((r) => r['user_id'] != currentUserId);
    final otherId = other['user_id'] as String?;
    if (otherId == null) continue; // partner deleted their account

    final hasReplied = other['first_message_at'] != null;
    final existing = partners[otherId];
    if (existing == null || (hasReplied && !existing.hasReplied)) {
      partners[otherId] =
          (conversationId: entry.key, hasReplied: hasReplied);
    }
  }
  return partners;
}

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

  /// The caller's true-1:1 partner map: `userId → (conversationId,
  /// hasReplied)`. One shape, two consumers — [findOrCreate1to1] resolves
  /// Chat through it, and the Search group picker reads `hasReplied` for §9
  /// eligibility. RLS already scopes both queries to conversations the caller
  /// belongs to.
  Future<Map<String, ({String conversationId, bool hasReplied})>>
      getOneToOnePartners({required String currentUserId}) async {
    final myMemberships = await _client
        .from('conversation_members')
        .select('conversation_id')
        .eq('user_id', currentUserId)
        .isFilter('left_at', null);

    final conversationIds = (myMemberships as List)
        .map((r) => r['conversation_id'] as String)
        .toList();
    if (conversationIds.isEmpty) return const {};

    final memberRows = await _client
        .from('conversation_members')
        .select('conversation_id, user_id, first_message_at')
        .inFilter('conversation_id', conversationIds);

    return oneToOnePartnersFromRows(
      (memberRows as List).cast<Map<String, dynamic>>(),
      currentUserId,
    );
  }

  /// Returns the id of the existing **true 1:1** conversation between
  /// [currentUserId] and [otherUserId], or creates a new one and returns its
  /// id. Never creates duplicates, and never resolves to a shared group —
  /// spec §18 (Search): Chat resolves strictly to a 1:1, a conversation whose
  /// membership is exactly the two users. (The old id-intersection version
  /// could open a group both happened to be in.)
  Future<String> findOrCreate1to1({
    required String currentUserId,
    required String otherUserId,
  }) async {
    final partners = await getOneToOnePartners(currentUserId: currentUserId);
    final existing = partners[otherUserId];
    if (existing != null) return existing.conversationId;

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
