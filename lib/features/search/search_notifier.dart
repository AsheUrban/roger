import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'search_state.dart';

final searchProvider =
    NotifierProvider<SearchNotifier, SearchState>(SearchNotifier.new);

class SearchNotifier extends Notifier<SearchState> {
  @override
  SearchState build() => const SearchState();

  Future<void> loadInitialContacts() async {}
  Future<void> search(String query) async {}
  Future<void> startChat(String userId) async {}
  Future<void> sendInvite(String phoneNumber) async {}
}
