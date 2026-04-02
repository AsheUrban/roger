import '../../core/models/user.dart';

class SearchResult {
  final User? rogerUser;
  final String contactName;
  final String phoneNumber;
  final bool isOnRoger;
  final bool hasPendingInvite;

  const SearchResult({
    this.rogerUser,
    required this.contactName,
    required this.phoneNumber,
    required this.isOnRoger,
    this.hasPendingInvite = false,
  });
}

class SearchState {
  final String query;
  final List<SearchResult> results;
  final bool hasContactsPermission;
  final bool isLoading;
  final String? error;

  const SearchState({
    this.query = '',
    this.results = const [],
    this.hasContactsPermission = false,
    this.isLoading = false,
    this.error,
  });

  SearchState copyWith({
    String? query,
    List<SearchResult>? results,
    bool? hasContactsPermission,
    bool? isLoading,
    String? Function()? error,
  }) {
    return SearchState(
      query: query ?? this.query,
      results: results ?? this.results,
      hasContactsPermission:
          hasContactsPermission ?? this.hasContactsPermission,
      isLoading: isLoading ?? this.isLoading,
      error: error != null ? error() : this.error,
    );
  }
}
