import 'package:flutter_test/flutter_test.dart';
import 'package:roger/features/search/search_state.dart';

void main() {
  group('AddedContactResult equality', () {
    test('two instances with the same field values are equal', () {
      const a = AddedContactResult(
          userId: 'u-1', contactName: 'Jordan', avatarColor: 'Rust');
      const b = AddedContactResult(
          userId: 'u-1', contactName: 'Jordan', avatarColor: 'Rust');
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('not equal when userId differs', () {
      expect(
        const AddedContactResult(
            userId: 'u-1', contactName: 'Jordan', avatarColor: 'Rust'),
        isNot(equals(const AddedContactResult(
            userId: 'u-2', contactName: 'Jordan', avatarColor: 'Rust'))),
      );
    });

    test('not equal when contactName differs', () {
      expect(
        const AddedContactResult(
            userId: 'u-1', contactName: 'Jordan', avatarColor: 'Rust'),
        isNot(equals(const AddedContactResult(
            userId: 'u-1', contactName: 'Alex', avatarColor: 'Rust'))),
      );
    });

    test('not equal when avatarColor differs', () {
      expect(
        const AddedContactResult(
            userId: 'u-1', contactName: 'Jordan', avatarColor: 'Rust'),
        isNot(equals(const AddedContactResult(
            userId: 'u-1', contactName: 'Jordan', avatarColor: 'Olive'))),
      );
    });
  });

  group('SearchState equality', () {
    test('two default instances are equal', () {
      const a = SearchState();
      const b = SearchState();
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('not equal when query differs', () {
      expect(const SearchState(),
          isNot(equals(const SearchState(query: 'jordan'))));
    });

    test('not equal when results differ', () {
      const a = SearchState(results: []);
      const b = SearchState(results: [
        AddedContactResult(
            userId: 'u-1', contactName: 'Jordan', avatarColor: 'Rust'),
      ]);
      expect(a, isNot(equals(b)));
    });

    test('equal when results have same content, different list identity', () {
      final a = SearchState(results: [
        const AddedContactResult(
            userId: 'u-1', contactName: 'Jordan', avatarColor: 'Rust'),
      ]);
      final b = SearchState(results: [
        const AddedContactResult(
            userId: 'u-1', contactName: 'Jordan', avatarColor: 'Rust'),
      ]);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('not equal when notOnRogerName differs', () {
      expect(const SearchState(),
          isNot(equals(const SearchState(notOnRogerName: 'Dana'))));
    });

    test('not equal when isGroupMode differs', () {
      expect(const SearchState(),
          isNot(equals(const SearchState(isGroupMode: true))));
    });

    test('not equal when selectedUserIds differ', () {
      expect(const SearchState(selectedUserIds: []),
          isNot(equals(const SearchState(selectedUserIds: ['u-1']))));
    });

    test('copyWith with no changes produces an equal instance', () {
      const a = SearchState(query: 'jordan', isGroupMode: true);
      final b = a.copyWith();
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
