import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user.dart' as app;

class AuthService {
  final SupabaseClient _client;

  AuthService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  Future<void> sendMagicLink(String email) async {
    await _client.auth.signInWithOtp(
      email: email,
      emailRedirectTo: 'com.rogermessaging.app://login',
    );
  }

  Future<app.User> createAccount({
    required String email,
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
      'email': email,
      'phone_number': phoneNumber,
      'avatar_color': avatarColor,
      'phone_verified': false,
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

  /// Checks if a phone number is already claimed by another account.
  Future<bool> isPhoneNumberTaken(String phoneNumber) async {
    final row = await _client
        .from('users')
        .select('id')
        .eq('phone_number', phoneNumber)
        .maybeSingle();
    return row != null;
  }

  Future<void> updatePhoneNumber(String newNumber) async {
    await _client
        .from('users')
        .update({'phone_number': newNumber, 'phone_verified': false})
        .eq('id', _client.auth.currentUser!.id);
  }

  Future<void> updateAvatarColor(String color) async {
    await _client
        .from('users')
        .update({'avatar_color': color})
        .eq('id', _client.auth.currentUser!.id);
  }

  app.User _userFromRow(Map<String, dynamic> row) {
    return app.User(
      id: row['id'] as String,
      email: row['email'] as String,
      phoneNumber: row['phone_number'] as String,
      avatarColor: row['avatar_color'] as String,
      phoneVerified: row['phone_verified'] as bool? ?? false,
      lastActiveAt: row['last_active_at'] != null
          ? DateTime.parse(row['last_active_at'] as String)
          : null,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}
