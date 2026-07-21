// Negative-property tests — privacy patch, schema baseline (00001_init).
// Proves §18 Cross-Cutting Privacy Invariants 2, 3, 7 against REAL Supabase.
//
// Layer-3 integration tests (real Supabase + two authenticated test users).
// RED against the old pre-patch schema; GREEN once the consolidated 00001_init
// baseline (hardened schema + narrowed RLS) is applied. Ashe drives them on
// device:
//
//   flutter test integration_test/security/identity_privacy_test.dart \
//     --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
//
// Test users (Supabase dashboard, per LOG_5_8): A = +15550001000,
// B = +15550002000, OTP 123456.
//
// Two requirements these tests pin, now baked into 00001_init:
//   * No `users: insert own` policy — the SECURITY DEFINER create_account RPC is
//     the only write path into public.users (invariant 7).
//   * A SECURITY DEFINER `shares_active_conversation(target)` helper backs the
//     narrowed users/user_keys SELECT (invariant 3).

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:roger/core/config/env.dart';

const _otp = '123456';
const _phoneA = '+15550001000';
const _phoneB = '+15550002000';

/// A fresh SupabaseClient authenticated as [phone], with a guaranteed
/// public.users account (idempotent). Returns the client and its user id.
Future<({SupabaseClient client, String userId})> _signIn(
  String phone,
  String avatarColor,
) async {
  final client = SupabaseClient(Env.supabaseUrl, Env.supabaseAnonKey);
  await client.auth.signInWithOtp(phone: phone);
  await client.auth.verifyOTP(phone: phone, token: _otp, type: OtpType.sms);
  final uid = client.auth.currentUser!.id;

  // Self-read survives the narrowed RLS (the "self" clause). Create the account
  // through the RPC only if it doesn't exist yet.
  final existing =
      await client.from('users').select('id').eq('id', uid).maybeSingle();
  if (existing == null) {
    // create_account reads the verified phone from auth.users itself; the
    // client only supplies the avatar color.
    await client.rpc('create_account', params: {
      'p_avatar_color': avatarColor,
    });
  }
  return (client: client, userId: uid);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late SupabaseClient a;
  late SupabaseClient b;
  late String aId;
  late String bId;

  setUpAll(() async {
    final ra = await _signIn(_phoneA, 'Deep Red');
    final rb = await _signIn(_phoneB, 'Cornflower');
    a = ra.client;
    aId = ra.userId;
    b = rb.client;
    bId = rb.userId;
    // Precondition for invariant 3: A and B must share NO active conversation.
    // These are dedicated test users; harness state-isolation (clearing any
    // shared conversation a prior run left behind) is firmed up with Ashe on
    // the first real run.
  });

  tearDownAll(() async {
    await a.auth.signOut();
    await b.auth.signOut();
  });

  group('Invariant 2 — no raw phone in application data', () {
    test('own users row exposes phone_hash, never phone_number', () async {
      final row = await a.from('users').select().eq('id', aId).single();
      expect(row.containsKey('phone_number'), isFalse,
          reason: 'users.phone_number must not exist — never created by 00001_init');
      expect(row.containsKey('phone_hash'), isTrue,
          reason: 'users.phone_hash must exist and be populated');
    });
  });

  group('Invariant 3 — no cross-user identity reads', () {
    test('A (no shared conversation) cannot read B via users select', () async {
      final rows = await a.from('users').select().eq('id', bId);
      expect(rows, isEmpty,
          reason: 'narrowed RLS: A may read B only when they share an active '
              'conversation');
    });

    test("A cannot read B's user_keys", () async {
      final rows = await a.from('user_keys').select().eq('user_id', bId);
      expect(rows, isEmpty,
          reason: 'user_keys SELECT narrowed to self-or-shares-conversation');
    });

    test('A CAN read its own row (positive control — must not over-restrict)',
        () async {
      final row = await a.from('users').select().eq('id', aId).maybeSingle();
      expect(row, isNotNull);
    });
  });

  group('Invariant 7 — account creation is atomic and RPC-only', () {
    test('create_account wrote both users and user_settings', () async {
      final user =
          await a.from('users').select('id').eq('id', aId).maybeSingle();
      final settings = await a
          .from('user_settings')
          .select('user_id')
          .eq('user_id', aId)
          .maybeSingle();
      expect(user, isNotNull);
      expect(settings, isNotNull,
          reason: 'RPC writes users + user_settings in one transaction');
    });

    test(
      'a direct client insert into users is rejected by RLS',
      () async {
        // Needs a disposable authenticated user with no account, so the direct
        // insert is the only write path being exercised. Requires a third test
        // number + per-run cleanup; fills in with the harness work. 00001_init
        // already has no users:insert-own policy, so create_account is the sole
        // write path.
      },
      skip: 'feature not built — needs a disposable test user (no account) to '
          'exercise the rejected direct insert. 00001_init already has no '
          'users:insert-own policy; this fills in with the harness work.',
    );
  });
}
