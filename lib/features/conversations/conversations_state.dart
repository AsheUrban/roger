import '../../core/models/conversation.dart';
import '../../core/models/user.dart';

class ConversationSummary {
  final Conversation conversation;
  final String displayName;
  final List<User> members;
  final DateTime? lastMessageAt;
  final bool hasUnread;
  final bool isOtherUserActive;
  final DateTime? otherUserLastActiveAt;

  const ConversationSummary({
    required this.conversation,
    required this.displayName,
    required this.members,
    this.lastMessageAt,
    this.hasUnread = false,
    this.isOtherUserActive = false,
    this.otherUserLastActiveAt,
  });
}

class ConversationsState {
  final List<ConversationSummary> conversations;
  final bool isLoading;
  final String? error;

  const ConversationsState({
    this.conversations = const [],
    this.isLoading = false,
    this.error,
  });
}
