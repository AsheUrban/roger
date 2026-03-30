import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user.dart' as app;

class AuthService {
  final SupabaseClient _client;

  AuthService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  Future<void> sendOtp(String phoneNumber) async {
    await _client.auth.signInWithOtp(phone: phoneNumber);
  }

  /// Verifies OTP. Returns existing [app.User] if account exists,
  /// or null if this is a new user who needs to complete onboarding.
  Future<app.User?> verifyOtp(String phoneNumber, String otp) async {
    final response = await _client.auth.verifyOTP(
      phone: phoneNumber,
      token: otp,
      type: OtpType.sms,
    );

    if (response.user == null) {
      throw Exception('Verification failed.');
    }

    // Check if this user already has a public.users row
    final existing = await _client
        .from('users')
        .select()
        .eq('id', response.user!.id)
        .maybeSingle();

    if (existing != null) {
      return _userFromRow(existing);
    }

    // New user — no public.users row yet
    return null;
  }

  Future<app.User> createAccount({
    required String phoneNumber,
    required String displayName,
    required String avatarColor,
    String? recoveryEmail,
  }) async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      throw Exception('Not authenticated.');
    }

    final now = DateTime.now().toUtc().toIso8601String();

    // Insert user row and default settings in parallel
    final userRow = {
      'id': authUser.id,
      'phone_number': phoneNumber,
      'display_name': displayName,
      'avatar_color': avatarColor,
      'email': recoveryEmail,
      'recovery_email_verified': false,
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

  Future<void> updatePhoneNumber(String newNumber, String otp) async {
    await _client.auth.verifyOTP(
      phone: newNumber,
      token: otp,
      type: OtpType.sms,
    );
    await _client
        .from('users')
        .update({'phone_number': newNumber})
        .eq('id', _client.auth.currentUser!.id);
  }

  Future<void> updateDisplayName(String name) async {
    await _client
        .from('users')
        .update({'display_name': name})
        .eq('id', _client.auth.currentUser!.id);
  }

  Future<void> updateAvatarColor(String color) async {
    await _client
        .from('users')
        .update({'avatar_color': color})
        .eq('id', _client.auth.currentUser!.id);
  }

  Future<void> setRecoveryEmail(String email) async {
    await _client.from('users').update({
      'email': email,
      'recovery_email_verified': false,
    }).eq('id', _client.auth.currentUser!.id);
  }

  app.User _userFromRow(Map<String, dynamic> row) {
    return app.User(
      id: row['id'] as String,
      phoneNumber: row['phone_number'] as String,
      displayName: row['display_name'] as String,
      avatarColor: row['avatar_color'] as String,
      email: row['email'] as String?,
      recoveryEmailVerified: row['recovery_email_verified'] as bool? ?? false,
      lastActiveAt: row['last_active_at'] != null
          ? DateTime.parse(row['last_active_at'] as String)
          : null,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}
