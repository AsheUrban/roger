// Per-(adder, addee) daily add cap (spec §9) against REAL Supabase.
//
// create_conversation caps how many times one person can add a specific other
// person to a conversation — 5 per pair per rolling 12h window. This blunts
// single-account add-harassment — someone with your number can't bury you in
// unwanted conversations. The pair is stored only as a peppered hash in
// conversation_add_limit, a table with RLS on and NO client policies.
//
// Run (emulator only — always pass -d):
//   flutter test integration_test/security/add_limit_test.dart \
//     -d emulator-5554 --dart-define-from-file=.env
//
// Uses test users A (adder) + B (target). STATE CAVEAT: this burns A→B's 12h
// add allowance and leaves ~5 A+B conversations behind (clients can't delete
// conversations — no DELETE policy, by design). conversation_add_limit is
// RLS-denied to clients, so a re-run within the 12h window needs an out-of-band
// reset in the SQL editor:
//   delete from conversation_add_limit;
// Flagged, not hidden.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'harness.dart';

const _cap = 5;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late SupabaseClient a;
  late String aId;
  late String bId;

  setUpAll(() async {
    final ra = await signIn(phoneA, 'Deep Red');
    final rb = await signIn(phoneB, 'Cornflower');
    a = ra.client;
    aId = ra.userId;
    bId = rb.userId;
    await rb.client.auth.signOut(); // B only needs to exist
  });

  tearDownAll(() async {
    await a.auth.signOut();
  });

  Future<String> createWithB() => a.rpc('create_conversation', params: {
        'p_name': null,
        'p_member_ids': [aId, bId],
      }).then((r) => r as String);

  group('per-(adder, addee) daily add cap', () {
    test('A can add B up to the cap, and the (cap+1)th is rejected', () async {
      // Note: shares the day's A→B counter with any prior run today — see the
      // reset caveat in the header. On a clean counter this is exactly `_cap`
      // successes then a rejection.
      for (var i = 0; i < _cap; i++) {
        final id = await createWithB();
        expect(id, isNotEmpty);
      }
      await expectLater(
        createWithB(),
        throwsA(isA<PostgrestException>()),
        reason: 'the 6th add of B by A in a day must be rejected',
      );
    });

    test('the counter table is not client-readable (no policies)', () async {
      final rows = await a.from('conversation_add_limit').select() as List;
      expect(rows, isEmpty,
          reason: 'RLS is on with no client policy — a client select returns '
              'nothing, never the peppered pair counters');
    });

    test('the counter table is not client-writable', () async {
      await expectLater(
        a.from('conversation_add_limit').insert({
          'pair_hash': 'forged',
          'window_start': DateTime.now().toUtc().toIso8601String(),
          'count': 0,
        }),
        throwsA(isA<PostgrestException>()),
      );
    });
  });
}
