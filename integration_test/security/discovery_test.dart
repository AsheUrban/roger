// Negative-property tests — privacy patch, discovery slice.
// Proves §18 Cross-Cutting Privacy Invariants 4, 5, 6 against REAL Supabase.
//
// Targets the `discover_user(p_phone text)` RPC (decided 6/4 — an RPC, not an
// Edge Function; see LOG_6_4). The RPC: rate-limit check/increment →
// peppered_phone_hash → match against user_private.phone_hash → return
// (user_id, avatar_color, last_active_at) for an exact-number match, or nothing.
// Raw number used transiently, never stored. At most one row; rate-limit
// exceeded raises.
//
// RED until discover_user is added to the schema. Ashe drives on device:
//   flutter test integration_test/security/discovery_test.dart \
//     --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
//
// Test users (LOG_5_8): A=+15550001000, B=+15550002000, C=+15550003000, OTP 123456.
// Cap: 20 lookups/day/user (Spec §18).
//
// RATE-LIMIT TEST CAVEAT (invariant 5): it deliberately burns user C's daily
// discovery counter. `discovery_rate_limit` is RLS-denied to clients, so the
// test cannot reset it. Re-running the same day needs an out-of-band reset in
// the SQL editor (dashboard/service role):
//   delete from discovery_rate_limit where user_id = '<C id>';
// Flagged, not hidden. C is used only for this test so it doesn't pollute the
// counters the other tests rely on.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:roger/core/config/env.dart';

const _otp = '123456';
const _phoneA = '+15550001000';
const _phoneB = '+15550002000';
const _phoneC = '+15550003000';
const _unknownNumber = '+15555550199'; // not a registered roger user
const _cap = 20;

/// A fresh SupabaseClient authenticated as [phone], with a guaranteed
/// public.users account (idempotent). Returns the client and its user id.
/// (Mirrors the helper in identity_privacy_test.dart — extract to a shared
/// harness if a third security test needs it.)
Future<({SupabaseClient client, String userId})> _signIn(
  String phone,
  String avatarColor,
) async {
  final client = SupabaseClient(Env.supabaseUrl, Env.supabaseAnonKey);
  await client.auth.signInWithOtp(phone: phone);
  await client.auth.verifyOTP(phone: phone, token: _otp, type: OtpType.sms);
  final uid = client.auth.currentUser!.id;

  final existing =
      await client.from('users').select('id').eq('id', uid).maybeSingle();
  if (existing == null) {
    await client.rpc('create_account', params: {'p_avatar_color': avatarColor});
  }
  return (client: client, userId: uid);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late SupabaseClient a;
  late String bId;

  setUpAll(() async {
    final ra = await _signIn(_phoneA, 'Deep Red');
    final rb = await _signIn(_phoneB, 'Cornflower');
    a = ra.client;
    bId = rb.userId;
    // Only A needs to stay authenticated to call discovery; B just needs to exist.
    await rb.client.auth.signOut();
  });

  tearDownAll(() async {
    await a.auth.signOut();
  });

  group('Invariant 4 — single-number discovery, never the address book', () {
    test('a match is returned for an exact registered number', () async {
      final res = await a.rpc('discover_user', params: {'p_phone': _phoneB});
      final rows = res as List;
      expect(rows.length, 1);
      expect(rows.first['user_id'], bId);
    });

    test('nothing is returned for a non-registered number', () async {
      final res =
          await a.rpc('discover_user', params: {'p_phone': _unknownNumber});
      expect(res as List, isEmpty);
    });

    // No array/list discovery endpoint exists: discover_user takes ONE text
    // param. The superseded find_roger_users_by_hashes(text[]) is not built —
    // an endpoint that accepts a list would violate this invariant.
  });

  group('Invariant 6 — no enumerable directory, minimal disclosure', () {
    test('a match exposes only user_id / avatar_color / last_active_at',
        () async {
      final res = await a.rpc('discover_user', params: {'p_phone': _phoneB});
      final row = (res as List).first as Map<String, dynamic>;
      expect(row.keys.toSet(), {'user_id', 'avatar_color', 'last_active_at'},
          reason: 'no phone-derived or other fields may leak through discovery');
      expect(row.containsKey('phone_hash'), isFalse);
      expect(row.containsKey('recovery_email'), isFalse);
    });

    test('an unauthenticated (anon) client cannot call discover_user', () async {
      final anon = SupabaseClient(Env.supabaseUrl, Env.supabaseAnonKey);
      await expectLater(
        anon.rpc('discover_user', params: {'p_phone': _phoneB}),
        throwsA(isA<PostgrestException>()),
        reason: 'discover_user is granted to authenticated only',
      );
    });
  });

  group('Invariant 5 — discovery is rate-limited, not an enumeration oracle',
      () {
    test('the (cap+1)th lookup in a day is rejected', () async {
      final rc = await _signIn(_phoneC, 'Olive');
      final c = rc.client;
      try {
        // Burn the day's allowance (see header caveat on resetting between runs).
        for (var i = 0; i < _cap; i++) {
          await c.rpc('discover_user', params: {'p_phone': _unknownNumber});
        }
        await expectLater(
          c.rpc('discover_user', params: {'p_phone': _unknownNumber}),
          throwsA(isA<PostgrestException>()),
          reason: 'the 21st lookup in a day must be rejected',
        );
      } finally {
        await c.auth.signOut();
      }
    });
  });
}
