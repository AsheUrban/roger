import 'package:flutter_test/flutter_test.dart';
import 'package:roger/core/models/user.dart';
import 'package:roger/features/search/search_state.dart';

void main() {
  group('SearchState equality', () {
    test('two default instances are equal', () {
      final a = SearchState();
      final b = SearchState();
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('two instances with same field values are equal (shared list refs)',
        () {
      // Reference equality on List<T> means the two instances must point at
      // the same list. const [] is canonicalized to a single instance, so the
      // two default fields below share identity.
      final results = const <SearchResult>[];
      final selected = const <String>[];
      final a = SearchState(
        query: 'jordan',
        results: results,
        hasContactsPermission: true,
        isLoading: false,
        error: 'oops',
        isGroupMode: true,
        selectedUserIds: selected,
      );
      final b = SearchState(
        query: 'jordan',
        results: results,
        hasContactsPermission: true,
        isLoading: false,
        error: 'oops',
        isGroupMode: true,
        selectedUserIds: selected,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('not equal when query differs', () {
      final a = SearchState();
      final b = SearchState(query: 'jordan');
      expect(a, isNot(equals(b)));
    });

    test('not equal when results differ (different list identity)', () {
      final a = SearchState(results: const []);
      final b = SearchState(results: [
        SearchResult(
          contactName: 'Jordan',
          phoneNumber: '+15551111111',
          isOnRoger: false,
        ),
      ]);
      expect(a, isNot(equals(b)));
    });

    test('not equal when hasContactsPermission differs', () {
      final a = SearchState();
      final b = SearchState(hasContactsPermission: true);
      expect(a, isNot(equals(b)));
    });

    test('not equal when isLoading differs', () {
      final a = SearchState();
      final b = SearchState(isLoading: true);
      expect(a, isNot(equals(b)));
    });

    test('not equal when error differs', () {
      final a = SearchState();
      final b = SearchState(error: 'oops');
      expect(a, isNot(equals(b)));
    });

    test('not equal when isGroupMode differs', () {
      final a = SearchState();
      final b = SearchState(isGroupMode: true);
      expect(a, isNot(equals(b)));
    });

    test('not equal when selectedUserIds differ (different list identity)',
        () {
      final a = SearchState(selectedUserIds: const []);
      final b = SearchState(selectedUserIds: const ['u-1']);
      expect(a, isNot(equals(b)));
    });

    test('copyWith with no changes produces an equal instance', () {
      final a = SearchState(
        query: 'jordan',
        hasContactsPermission: true,
        isGroupMode: true,
      );
      final b = a.copyWith();
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('equal when results have same content but different list identity',
        () {
      final a = SearchState(
        results: [
          SearchResult(
            contactName: 'Jordan',
            phoneNumber: '+15551111111',
            isOnRoger: false,
          ),
        ],
      );
      final b = SearchState(
        results: [
          SearchResult(
            contactName: 'Jordan',
            phoneNumber: '+15551111111',
            isOnRoger: false,
          ),
        ],
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test(
        'equal when selectedUserIds have same content but different list identity',
        () {
      final a = SearchState(selectedUserIds: ['u-1', 'u-2']);
      final b = SearchState(selectedUserIds: ['u-1', 'u-2']);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('not equal when results have different SearchResult content', () {
      final a = SearchState(results: [
        SearchResult(
            contactName: 'Jordan',
            phoneNumber: '+15551111111',
            isOnRoger: false),
      ]);
      final b = SearchState(results: [
        SearchResult(
            contactName: 'Alex',
            phoneNumber: '+15551111111',
            isOnRoger: false),
      ]);
      expect(a, isNot(equals(b)));
    });
  });

  group('SearchResult equality', () {
    test('two instances with the same field values are equal', () {
      final a = SearchResult(
        contactName: 'Jordan',
        phoneNumber: '+15551111111',
        isOnRoger: true,
        hasPendingInvite: true,
      );
      final b = SearchResult(
        contactName: 'Jordan',
        phoneNumber: '+15551111111',
        isOnRoger: true,
        hasPendingInvite: true,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('two instances with minimum fields and null rogerUser are equal', () {
      final a = SearchResult(
        contactName: 'Jordan',
        phoneNumber: '+15551111111',
        isOnRoger: false,
      );
      final b = SearchResult(
        contactName: 'Jordan',
        phoneNumber: '+15551111111',
        isOnRoger: false,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('equal when rogerUser instances are different but field-equal', () {
      final userA = User(
        id: 'u-1',
        phoneNumber: '+15551111111',
        avatarColor: 'Rust',
        createdAt: DateTime(2026, 1, 1),
      );
      final userB = User(
        id: 'u-1',
        phoneNumber: '+15551111111',
        avatarColor: 'Rust',
        createdAt: DateTime(2026, 1, 1),
      );
      final a = SearchResult(
        rogerUser: userA,
        contactName: 'Jordan',
        phoneNumber: '+15551111111',
        isOnRoger: true,
      );
      final b = SearchResult(
        rogerUser: userB,
        contactName: 'Jordan',
        phoneNumber: '+15551111111',
        isOnRoger: true,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('not equal when contactName differs', () {
      expect(
        SearchResult(
            contactName: 'Jordan',
            phoneNumber: '+15551111111',
            isOnRoger: false),
        isNot(equals(SearchResult(
            contactName: 'Alex',
            phoneNumber: '+15551111111',
            isOnRoger: false))),
      );
    });

    test('not equal when phoneNumber differs', () {
      expect(
        SearchResult(
            contactName: 'Jordan',
            phoneNumber: '+15551111111',
            isOnRoger: false),
        isNot(equals(SearchResult(
            contactName: 'Jordan',
            phoneNumber: '+15552222222',
            isOnRoger: false))),
      );
    });

    test('not equal when isOnRoger differs', () {
      expect(
        SearchResult(
            contactName: 'Jordan',
            phoneNumber: '+15551111111',
            isOnRoger: false),
        isNot(equals(SearchResult(
            contactName: 'Jordan',
            phoneNumber: '+15551111111',
            isOnRoger: true))),
      );
    });

    test('not equal when hasPendingInvite differs', () {
      expect(
        SearchResult(
            contactName: 'Jordan',
            phoneNumber: '+15551111111',
            isOnRoger: false),
        isNot(equals(SearchResult(
            contactName: 'Jordan',
            phoneNumber: '+15551111111',
            isOnRoger: false,
            hasPendingInvite: true))),
      );
    });

    test('not equal when one has rogerUser set and the other is null', () {
      final user = User(
        id: 'u-1',
        phoneNumber: '+15551111111',
        avatarColor: 'Rust',
        createdAt: DateTime(2026, 1, 1),
      );
      expect(
        SearchResult(
            contactName: 'Jordan',
            phoneNumber: '+15551111111',
            isOnRoger: false),
        isNot(equals(SearchResult(
            rogerUser: user,
            contactName: 'Jordan',
            phoneNumber: '+15551111111',
            isOnRoger: true))),
      );
    });
  });
}
