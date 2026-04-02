import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'services/auth_service.dart';
import 'services/contacts_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final contactsServiceProvider = Provider<ContactsService>((ref) => ContactsService());
final randomProvider = Provider<Random>((ref) => Random());

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final currentUserIdProvider = Provider<String?>((ref) {
  return Supabase.instance.client.auth.currentUser?.id;
});

/// Stream of Supabase auth state changes. Override in tests to provide a mock stream.
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});
