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
  final bool isGroupMode;
  final List<String> selectedUserIds;

  const SearchState({
    this.query = '',
    this.results = const [],
    this.hasContactsPermission = false,
    this.isLoading = false,
    this.error,
    this.isGroupMode = false,
    this.selectedUserIds = const [],
  });

  SearchState copyWith({
    String? query,
    List<SearchResult>? results,
    bool? hasContactsPermission,
    bool? isLoading,
    String? Function()? error,
    bool? isGroupMode,
    List<String>? selectedUserIds,
  }) {
    return SearchState(
      query: query ?? this.query,
      results: results ?? this.results,
      hasContactsPermission:
          hasContactsPermission ?? this.hasContactsPermission,
      isLoading: isLoading ?? this.isLoading,
      error: error != null ? error() : this.error,
      isGroupMode: isGroupMode ?? this.isGroupMode,
      selectedUserIds: selectedUserIds ?? this.selectedUserIds,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SearchState &&
        other.query == query &&
        other.results == results &&
        other.hasContactsPermission == hasContactsPermission &&
        other.isLoading == isLoading &&
        other.error == error &&
        other.isGroupMode == isGroupMode &&
        other.selectedUserIds == selectedUserIds;
  }

  @override
  int get hashCode => Object.hash(
        query,
        results,
        hasContactsPermission,
        isLoading,
        error,
        isGroupMode,
        selectedUserIds,
      );
}
