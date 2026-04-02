import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'conversations_state.dart';

final conversationsProvider =
    NotifierProvider<ConversationsNotifier, ConversationsState>(
  ConversationsNotifier.new,
);

class ConversationsNotifier extends Notifier<ConversationsState> {
  @override
  ConversationsState build() => const ConversationsState();

  Future<void> loadConversations() async {}
  Future<void> refreshConversations() async {}
}
