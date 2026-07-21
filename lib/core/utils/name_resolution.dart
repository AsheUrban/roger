/// Pure name-resolution rules per spec §10. Free functions (like routerRedirect)
/// so the resolution order is unit-testable without a Supabase round-trip — the
/// gap that let the display-name "?" bug go uncaught.
library;

/// Resolves the display name for a single conversation member.
///
/// Resolution order:
///   1. captured name — you picked this person (their [userId] is in [addedNames])
///   2. "?" — an active member you never picked yourself
///   3. "Deleted user" — account deleted (server nulled the userId). All deleted
///      accounts resolve the same way; roger retains no name for them.
String resolveMemberName({
  required String? userId,
  required Map<String, String> addedNames,
}) {
  if (userId == null) return 'Deleted user';
  return addedNames[userId] ?? '?';
}

/// Resolves a conversation's display name: the explicit group name if set,
/// otherwise the joined member names (or "?" when there are none).
String resolveConversationName({
  required String? conversationName,
  required List<String> memberNames,
}) {
  if (conversationName != null) return conversationName;
  return memberNames.isEmpty ? '?' : memberNames.join(', ');
}
