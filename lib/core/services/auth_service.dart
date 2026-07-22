import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user.dart' as app;

class AuthService {
  final SupabaseClient _client;

  AuthService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Synchronously available after `Supabase.initialize` — the stored session
  /// (if any) is loaded from local storage during initialize. Used by
  /// `AuthNotifier.build()` to seed `AuthState` before the first frame.
  Session? get currentSession => _client.auth.currentSession;

  /// Auth lifecycle events. `AuthNotifier` acts on `signedOut` only; the
  /// `signedIn` / `tokenRefreshed` / `initialSession` events fire on startup
  /// and reacting to them would clobber the seed / async correction.
  Stream<AuthChangeEvent> get authEvents =>
      _client.auth.onAuthStateChange.map((s) => s.event);

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
    required String avatarColor,
  }) async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      throw Exception('Not authenticated.');
    }

    // create_account (security definer) reads the verified phone from
    // auth.users, writes users + user_settings atomically, and returns the new
    // user id. The server owns identity, so we read the row back through the
    // one authoritative path (getCurrentUser) rather than constructing a User
    // client-side — the stored row carries the server's created_at and any
    // defaults.
    await _client.rpc('create_account', params: {
      'p_avatar_color': avatarColor,
    });

    final user = await getCurrentUser();
    if (user == null) {
      throw Exception('Account creation did not produce a user row.');
    }
    return user;
  }

  Future<app.User?> getCurrentUser() async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) return null;

    // recovery_email lives in the self-only user_private table. It reads null
    // here until Settings (step 8) fetches it from user_private; it's null
    // pre-Settings anyway, so no behavior change today.
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

  // Account deletion is handled server-side (delete-account Edge Function,
  // Settings slice — step 8). It must remove auth.users too, which needs
  // service_role, and there is deliberately no client DELETE policy on
  // public.users — so a client-side delete can never work.
  Future<void> deleteAccount() async {
    throw UnimplementedError(
      'Account deletion routes through the delete-account Edge Function '
      '(step 8).',
    );
  }

  // Phone-number change is handled server-side (Edge Function), not a client write.

  Future<void> updateAvatarColor(String color) async {
    await _client
        .from('users')
        .update({'avatar_color': color})
        .eq('id', _client.auth.currentUser!.id);
  }

  Future<void> updateRecoveryEmail(String email) async {
    // recovery_email lives in the self-only user_private table.
    await _client
        .from('user_private')
        .update({'recovery_email': email})
        .eq('user_id', _client.auth.currentUser!.id);
  }

  app.User _userFromRow(Map<String, dynamic> row) {
    return app.User(
      id: row['id'] as String,
      avatarColor: row['avatar_color'] as String,
      recoveryEmail: row['recovery_email'] as String?,
      lastActiveAt: row['last_active_at'] != null
          ? DateTime.parse(row['last_active_at'] as String)
          : null,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}
