import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user.dart' as app;

class AuthService {
  final SupabaseClient _client;

  AuthService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  Future<void> sendOtp(String phoneNumber) async {
    await _client.auth.signInWithOtp(phone: phoneNumber);
  }

  Future<AuthResponse> verifyOtp({
    required String phoneNumber,
    required String otpCode,
  }) async {
    return await _client.auth.verifyOTP(
      phone: phoneNumber,
      token: otpCode,
      type: OtpType.sms,
    );
  }

  Future<app.User> createAccount({
    required String phoneNumber,
    required String avatarColor,
  }) async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      throw Exception('Not authenticated.');
    }

    final now = DateTime.now().toUtc().toIso8601String();

    final userRow = {
      'id': authUser.id,
      'phone_number': phoneNumber,
      'avatar_color': avatarColor,
      'created_at': now,
    };

    final settingsRow = {
      'user_id': authUser.id,
      'created_at': now,
      'updated_at': now,
    };

    final insertedUser = await _client
        .from('users')
        .insert(userRow)
        .select()
        .single();

    await _client.from('user_settings').insert(settingsRow);

    return _userFromRow(insertedUser);
  }

  Future<app.User?> getCurrentUser() async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) return null;

    final row = await _client
        .from('users')
        .select()
        .eq('id', authUser.id)
        .maybeSingle();

    if (row == null) return null;
    return _userFromRow(row);
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<void> deleteAccount() async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) return;

    // Delete public.users row — cascades to settings, keys, device tokens
    await _client.from('users').delete().eq('id', authUser.id);

    // TODO: auth.users entry requires service_role key to delete.
    // Add a Supabase Edge Function or database trigger to clean up
    // auth.users when the public.users row is deleted.
    await _client.auth.signOut();
  }

  Future<void> updatePhoneNumber(String newNumber) async {
    // TODO: Phone is now the auth identity. Changing it requires updating
    // both public.users AND auth.users. auth.users update requires
    // service_role key — needs Edge Function or database trigger,
    // same pattern as deleteAccount. Must also verify OTP to new number
    // before updating (spec: Settings → phone number change).
    await _client
        .from('users')
        .update({'phone_number': newNumber})
        .eq('id', _client.auth.currentUser!.id);
  }

  Future<void> updateAvatarColor(String color) async {
    await _client
        .from('users')
        .update({'avatar_color': color})
        .eq('id', _client.auth.currentUser!.id);
  }

  Future<void> updateRecoveryEmail(String email) async {
    await _client
        .from('users')
        .update({'recovery_email': email})
        .eq('id', _client.auth.currentUser!.id);
  }

  app.User _userFromRow(Map<String, dynamic> row) {
    return app.User(
      id: row['id'] as String,
      phoneNumber: row['phone_number'] as String,
      avatarColor: row['avatar_color'] as String,
      recoveryEmail: row['recovery_email'] as String?,
      lastActiveAt: row['last_active_at'] != null
          ? DateTime.parse(row['last_active_at'] as String)
          : null,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}
