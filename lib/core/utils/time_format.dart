/// "active 5m ago", "active now", "active 1h ago", "active yesterday", "active 3d ago"
/// Used for last-active displays throughout the app.
String formatLastActive(DateTime lastActive) {
  final diff = DateTime.now().difference(lastActive);
  if (diff.inMinutes < 1) return 'active now';
  if (diff.inMinutes < 60) return 'active ${diff.inMinutes}m ago';
  if (diff.inHours < 24) return 'active ${diff.inHours}h ago';
  if (diff.inDays == 1) return 'active yesterday';
  return 'active ${diff.inDays}d ago';
}

/// "now", "5m", "2h", "yesterday", "3d" — compact labels for conversation row timestamps.
String formatShortAge(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays == 1) return 'yesterday';
  return '${diff.inDays}d';
}
