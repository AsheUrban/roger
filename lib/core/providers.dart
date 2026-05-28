import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'database/app_database.dart';
import 'services/auth_service.dart';
import 'services/contacts_service.dart';
import 'services/conversation_service.dart';
import 'services/database_key_service.dart';
import 'services/invite_service.dart';

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(client: ref.read(supabaseClientProvider)),
);
final contactsServiceProvider = Provider<ContactsService>(
  (ref) => ContactsService(client: ref.read(supabaseClientProvider)),
);
final conversationServiceProvider = Provider<ConversationService>(
  (ref) => ConversationService(client: ref.read(supabaseClientProvider)),
);
final inviteServiceProvider = Provider<InviteService>(
  (ref) => InviteService(
    conversations: ref.read(conversationServiceProvider),
    client: ref.read(supabaseClientProvider),
  ),
);
final randomProvider = Provider<Random>((ref) => Random());

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final currentUserIdProvider = Provider<String?>((ref) {
  return Supabase.instance.client.auth.currentUser?.id;
});

/// Tracks whether the user explicitly skipped contacts permission during onboarding.
/// SearchNotifier checks this before auto-loading contacts.
/// Cleared when the user later grants permission via the search bar.
class ContactsDeclinedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setDeclined(bool value) => state = value;
}

final contactsDeclinedProvider =
    NotifierProvider<ContactsDeclinedNotifier, bool>(
  ContactsDeclinedNotifier.new,
);

/// Initialized in main() via ProviderScope override after the DB key is ready.
/// Throws if accessed before initialization — this is intentional.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('appDatabaseProvider must be overridden in main()');
});

final databaseKeyServiceProvider = Provider<DatabaseKeyService>(
  (ref) => DatabaseKeyService(),
);
