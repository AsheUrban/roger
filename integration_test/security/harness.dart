// Shared harness for the security integration tests (real cloud Supabase).
//
// Test users (Supabase dashboard, per LOG_5_8): A = +15550001000,
// B = +15550002000, C = +15550003000, all OTP 123456. Each test file documents
// which users it touches and any state it leaves behind.

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:roger/core/config/env.dart';

const otp = '123456';
const phoneA = '+15550001000';
const phoneB = '+15550002000';
const phoneC = '+15550003000';

/// A fresh SupabaseClient authenticated as [phone], with a guaranteed
/// public.users account (idempotent). Returns the client and its user id.
Future<({SupabaseClient client, String userId})> signIn(
  String phone,
  String avatarColor,
) async {
  final client = SupabaseClient(Env.supabaseUrl, Env.supabaseAnonKey);
  await client.auth.signInWithOtp(phone: phone);
  await client.auth.verifyOTP(phone: phone, token: otp, type: OtpType.sms);
  final uid = client.auth.currentUser!.id;

  // Self-read survives the narrowed RLS (the "self" clause). Create the account
  // through the RPC only if it doesn't exist yet — create_account reads the
  // verified phone from auth.users itself; the client only supplies the color.
  final existing =
      await client.from('users').select('id').eq('id', uid).maybeSingle();
  if (existing == null) {
    await client.rpc('create_account', params: {'p_avatar_color': avatarColor});
  }
  return (client: client, userId: uid);
}
