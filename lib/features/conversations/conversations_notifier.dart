import 'conversations_state.dart';

class ConversationsNotifier {
  ConversationsState state = const ConversationsState();

  Future<void> loadConversations() async {}
  Future<void> refreshConversations() async {}
}
