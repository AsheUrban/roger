import '../../core/models/conversation.dart';
import '../../core/models/user.dart';

class ConversationSummary {
  final Conversation conversation;
  final String displayName;
  final List<User> members;
  final List<String> memberContactNames; // parallel to members — contact name for each
  final DateTime? lastMessageAt;
  final bool hasUnread;
  final bool isOtherUserActive;
  final DateTime? otherUserLastActiveAt;

  const ConversationSummary({
    required this.conversation,
    required this.displayName,
    required this.members,
    this.memberContactNames = const [],
    this.lastMessageAt,
    this.hasUnread = false,
    this.isOtherUserActive = false,
    this.otherUserLastActiveAt,
  });

  ConversationSummary copyWith({
    Conversation? conversation,
    String? displayName,
    List<User>? members,
    List<String>? memberContactNames,
    DateTime? Function()? lastMessageAt,
    bool? hasUnread,
    bool? isOtherUserActive,
    DateTime? Function()? otherUserLastActiveAt,
  }) {
    return ConversationSummary(
      conversation: conversation ?? this.conversation,
      displayName: displayName ?? this.displayName,
      members: members ?? this.members,
      memberContactNames: memberContactNames ?? this.memberContactNames,
      lastMessageAt:
          lastMessageAt != null ? lastMessageAt() : this.lastMessageAt,
      hasUnread: hasUnread ?? this.hasUnread,
      isOtherUserActive: isOtherUserActive ?? this.isOtherUserActive,
      otherUserLastActiveAt: otherUserLastActiveAt != null
          ? otherUserLastActiveAt()
          : this.otherUserLastActiveAt,
    );
  }
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

  ConversationsState copyWith({
    List<ConversationSummary>? conversations,
    bool? isLoading,
    String? Function()? error,
  }) {
    return ConversationsState(
      conversations: conversations ?? this.conversations,
      isLoading: isLoading ?? this.isLoading,
      error: error != null ? error() : this.error,
    );
  }
}
