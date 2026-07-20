import 'package:flutter_test/flutter_test.dart';
import 'package:roger/core/utils/name_resolution.dart';

// Pure name-resolution rules per spec §10. Free functions (like routerRedirect)
// so the resolution order is unit-testable without a Supabase round-trip — the
// gap that let the display-name "?" bug go uncaught.
//
// Resolution order:
//   1. captured name — you picked this person (their userId is in the map)
//   2. "?" — an active member you never picked yourself
//   3. "Deleted user" — account deleted (server nulled the userId). All deleted
//      accounts resolve the same way; roger does not retain a deleted user's name.

void main() {
  group('resolveMemberName', () {
    test('a picked active member resolves to the captured name', () {
      final name = resolveMemberName(
        userId: 'u1',
        addedNames: {'u1': 'Jordan'},
      );
      expect(name, 'Jordan');
    });

    test('an active member you never picked resolves to "?"', () {
      final name = resolveMemberName(
        userId: 'u1',
        addedNames: const {},
      );
      expect(name, '?');
    });

    test('a deleted member (null userId) resolves to "Deleted user"', () {
      // userId null = account deleted (ON DELETE SET NULL). roger keeps no name
      // for deleted accounts, so this holds whether or not you'd added them.
      final name = resolveMemberName(
        userId: null,
        addedNames: const {'whoever': 'Jordan'},
      );
      expect(name, 'Deleted user');
    });
  });

  group('resolveConversationName', () {
    test('uses the group name when one is set', () {
      final name = resolveConversationName(
        conversationName: 'Trip crew',
        memberNames: ['Jordan', 'Casey'],
      );
      expect(name, 'Trip crew');
    });

    test('falls back to joined member names when no group name', () {
      final name = resolveConversationName(
        conversationName: null,
        memberNames: ['Jordan', 'Casey'],
      );
      expect(name, 'Jordan, Casey');
    });

    test('resolves to "?" when there is no name and no members', () {
      final name = resolveConversationName(
        conversationName: null,
        memberNames: const [],
      );
      expect(name, '?');
    });
  });
}
