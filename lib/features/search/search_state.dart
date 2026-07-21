import 'package:flutter/foundation.dart';

/// A person you've added via single-pick who is on roger. Sourced from the
/// AddedContacts drift store (spec §10) — name captured at add-time, avatar
/// color from discovery. No phone number is held.
class AddedContactResult {
  final String userId;
  final String contactName;
  final String avatarColor;

  const AddedContactResult({
    required this.userId,
    required this.contactName,
    required this.avatarColor,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AddedContactResult &&
        other.userId == userId &&
        other.contactName == contactName &&
        other.avatarColor == avatarColor;
  }

  @override
  int get hashCode => Object.hash(userId, contactName, avatarColor);
}

class SearchState {
  final String query;
  final List<AddedContactResult> results;
  final bool isLoading;
  final String? error;
  // Set after a pick when the number isn't on roger. Cleared on the next pick
  // or search.
  final String? notOnRogerName;
  // True once the current non-roger pick has been invited — the notice shows
  // "Invited" instead of the Invite action.
  final bool notOnRogerInvited;
  final bool isGroupMode;
  final List<String> selectedUserIds;

  const SearchState({
    this.query = '',
    this.results = const [],
    this.isLoading = false,
    this.error,
    this.notOnRogerName,
    this.notOnRogerInvited = false,
    this.isGroupMode = false,
    this.selectedUserIds = const [],
  });

  SearchState copyWith({
    String? query,
    List<AddedContactResult>? results,
    bool? isLoading,
    String? Function()? error,
    String? Function()? notOnRogerName,
    bool? notOnRogerInvited,
    bool? isGroupMode,
    List<String>? selectedUserIds,
  }) {
    return SearchState(
      query: query ?? this.query,
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      error: error != null ? error() : this.error,
      notOnRogerName:
          notOnRogerName != null ? notOnRogerName() : this.notOnRogerName,
      notOnRogerInvited: notOnRogerInvited ?? this.notOnRogerInvited,
      isGroupMode: isGroupMode ?? this.isGroupMode,
      selectedUserIds: selectedUserIds ?? this.selectedUserIds,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SearchState &&
        other.query == query &&
        listEquals(other.results, results) &&
        other.isLoading == isLoading &&
        other.error == error &&
        other.notOnRogerName == notOnRogerName &&
        other.notOnRogerInvited == notOnRogerInvited &&
        other.isGroupMode == isGroupMode &&
        listEquals(other.selectedUserIds, selectedUserIds);
  }

  @override
  int get hashCode => Object.hash(
        query,
        Object.hashAll(results),
        isLoading,
        error,
        notOnRogerName,
        notOnRogerInvited,
        isGroupMode,
        Object.hashAll(selectedUserIds),
      );
}
