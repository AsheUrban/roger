import 'package:flutter/foundation.dart';

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
  // Count of other members whose account was deleted (server nulled user_id).
  // Not in `members` — they have no User to carry. The screen renders one
  // deleted-user avatar (spec §4) per count.
  final int deletedMemberCount;

  const ConversationSummary({
    required this.conversation,
    required this.displayName,
    required this.members,
    this.memberContactNames = const [],
    this.lastMessageAt,
    this.hasUnread = false,
    this.isOtherUserActive = false,
    this.otherUserLastActiveAt,
    this.deletedMemberCount = 0,
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
    int? deletedMemberCount,
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
      deletedMemberCount: deletedMemberCount ?? this.deletedMemberCount,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ConversationSummary &&
        other.conversation == conversation &&
        other.displayName == displayName &&
        listEquals(other.members, members) &&
        listEquals(other.memberContactNames, memberContactNames) &&
        other.lastMessageAt == lastMessageAt &&
        other.hasUnread == hasUnread &&
        other.isOtherUserActive == isOtherUserActive &&
        other.otherUserLastActiveAt == otherUserLastActiveAt &&
        other.deletedMemberCount == deletedMemberCount;
  }

  @override
  int get hashCode => Object.hash(
        conversation,
        displayName,
        Object.hashAll(members),
        Object.hashAll(memberContactNames),
        lastMessageAt,
        hasUnread,
        isOtherUserActive,
        otherUserLastActiveAt,
        deletedMemberCount,
      );
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

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ConversationsState &&
        listEquals(other.conversations, conversations) &&
        other.isLoading == isLoading &&
        other.error == error;
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(conversations),
        isLoading,
        error,
      );
}
