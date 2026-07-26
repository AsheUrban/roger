import 'package:flutter_test/flutter_test.dart';
import 'package:roger/core/services/conversation_service.dart';

// True-1:1 resolution + the §9 group prerequisite (replied 1:1), 2026-07-25.
//
// The old findOrCreate1to1 intersected both users' conversation ids and took
// the first — which could return a shared GROUP instead of the 1:1 (§18 Search
// invariant: Chat resolves strictly to a 1:1). The fix routes through one pure
// function, oneToOnePartnersFromRows, which reads the raw member rows of the
// caller's conversations and keeps only true 1:1s: conversations with exactly
// two member rows — the caller and one other real user. The same map carries
// hasReplied (the partner's first_message_at is set), which backs the group
// picker's eligibility (spec §9: you can only group people who have replied to
// you in a 1:1).
//
// Row shape mirrors the Supabase select:
//   {conversation_id, user_id, first_message_at}

List<Map<String, dynamic>> _conv(
  String convId,
  List<({String? userId, String? firstMessageAt})> members,
) {
  return [
    for (final m in members)
      {
        'conversation_id': convId,
        'user_id': m.userId,
        'first_message_at': m.firstMessageAt,
      },
  ];
}

const _me = 'me';

void main() {
  group('oneToOnePartnersFromRows', () {
    test('a two-member conversation with me + one other is a 1:1 partner', () {
      final rows = _conv('c1', [
        (userId: _me, firstMessageAt: '2026-07-01T00:00:00Z'),
        (userId: 'u-1', firstMessageAt: null),
      ]);

      final partners = oneToOnePartnersFromRows(rows, _me);

      expect(partners.keys, ['u-1']);
      expect(partners['u-1']!.conversationId, 'c1');
    });

    test('hasReplied is true only when the PARTNER has a first_message_at — '
        'my own messages do not count', () {
      final onlyISpoke = _conv('c1', [
        (userId: _me, firstMessageAt: '2026-07-01T00:00:00Z'),
        (userId: 'u-1', firstMessageAt: null),
      ]);
      final theyReplied = _conv('c2', [
        (userId: _me, firstMessageAt: '2026-07-01T00:00:00Z'),
        (userId: 'u-2', firstMessageAt: '2026-07-02T00:00:00Z'),
      ]);

      final partners =
          oneToOnePartnersFromRows([...onlyISpoke, ...theyReplied], _me);

      expect(partners['u-1']!.hasReplied, isFalse);
      expect(partners['u-2']!.hasReplied, isTrue);
    });

    test('a group (three member rows) is never a 1:1 — even though both users '
        'are in it', () {
      final rows = _conv('g1', [
        (userId: _me, firstMessageAt: '2026-07-01T00:00:00Z'),
        (userId: 'u-1', firstMessageAt: '2026-07-01T00:00:00Z'),
        (userId: 'u-2', firstMessageAt: null),
      ]);

      final partners = oneToOnePartnersFromRows(rows, _me);

      expect(partners, isEmpty,
          reason: 'the shared-group-instead-of-1:1 bug: a group must never '
              'satisfy "existing 1:1"');
    });

    test('a group stays a group even when a member has left — total member '
        'rows, not active ones, define the shape', () {
      // Leaving sets left_at but the row remains; a 3-person group with one
      // leaver must not collapse into a "1:1".
      final rows = _conv('g1', [
        (userId: _me, firstMessageAt: null),
        (userId: 'u-1', firstMessageAt: '2026-07-01T00:00:00Z'),
        (userId: 'u-2', firstMessageAt: null), // left, row persists
      ]);

      final partners = oneToOnePartnersFromRows(rows, _me);

      expect(partners, isEmpty);
    });

    test('a 1:1 whose other party deleted their account (user_id null) is '
        'skipped — no partner to chat with', () {
      final rows = _conv('c1', [
        (userId: _me, firstMessageAt: '2026-07-01T00:00:00Z'),
        (userId: null, firstMessageAt: '2026-07-01T00:00:00Z'),
      ]);

      final partners = oneToOnePartnersFromRows(rows, _me);

      expect(partners, isEmpty);
    });

    test('duplicate 1:1s with the same partner merge — a replied one wins so '
        'eligibility is never understated', () {
      final unreplied = _conv('c1', [
        (userId: _me, firstMessageAt: '2026-07-01T00:00:00Z'),
        (userId: 'u-1', firstMessageAt: null),
      ]);
      final replied = _conv('c2', [
        (userId: _me, firstMessageAt: '2026-07-01T00:00:00Z'),
        (userId: 'u-1', firstMessageAt: '2026-07-02T00:00:00Z'),
      ]);

      // Order shouldn't matter.
      final a = oneToOnePartnersFromRows([...unreplied, ...replied], _me);
      final b = oneToOnePartnersFromRows([...replied, ...unreplied], _me);

      for (final partners in [a, b]) {
        expect(partners.length, 1);
        expect(partners['u-1']!.hasReplied, isTrue);
        expect(partners['u-1']!.conversationId, 'c2',
            reason: 'the replied conversation is the one Chat should open');
      }
    });

    test('a conversation not containing me at all contributes nothing', () {
      // Defensive: RLS should make this impossible, but the pure function
      // must not misattribute rows if it ever happens.
      final rows = _conv('c1', [
        (userId: 'u-1', firstMessageAt: null),
        (userId: 'u-2', firstMessageAt: null),
      ]);

      expect(oneToOnePartnersFromRows(rows, _me), isEmpty);
    });

    test('empty input yields an empty map', () {
      expect(oneToOnePartnersFromRows(const [], _me), isEmpty);
    });
  });

  group('ConversationService — Supabase paths',
      skip: 'Integration test — needs real Supabase '
          '(see integration_test/security/group_gate_test.dart)', () {
    test('findOrCreate1to1 opens the existing true 1:1, never a shared group',
        () {});

    test('findOrCreate1to1 creates a new 1:1 when only a group is shared',
        () {});

    test('getOneToOnePartners returns the replied map for the group picker',
        () {});

    test('create_conversation rejects a group containing a member who has '
        'not replied in a 1:1 with the caller (server-side gate)', () {});

    test('first_message_at is stamped by trigger and not client-writable',
        () {});
  });
}
