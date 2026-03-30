import 'search_state.dart';

class SearchNotifier {
  SearchState state = const SearchState();

  Future<void> loadInitialContacts() async {}
  Future<void> search(String query) async {}
  Future<void> startChat(String userId) async {}
  Future<void> sendInvite(String phoneNumber) async {}
}
