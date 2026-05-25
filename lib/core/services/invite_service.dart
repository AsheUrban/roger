import 'package:supabase_flutter/supabase_flutter.dart';

import 'conversation_service.dart';

/// Owns invite creation against Supabase. An invite is a pending conversation
/// (single member — the inviter) + a placeholder message + a row in
/// `pending_invites` that holds the recipient's phone number and an expiry.
///
/// Spec §10 Invites: pending conversation locked until recipient joins; invite
/// expires after 7 days.
class InviteService {
  final SupabaseClient _client;
  final ConversationService _conversations;

  InviteService({
    required ConversationService conversations,
    SupabaseClient? client,
  })  : _conversations = conversations,
        _client = client ?? Supabase.instance.client;

  /// Creates the pending conversation, placeholder message, and invite row
  /// for [phoneNumber]. Returns the new conversation id.
  // TODO: SMS invite via deep link (step 5 full implementation)
  Future<String> sendInvite({
    required String phoneNumber,
    required String currentUserId,
  }) async {
    final now = DateTime.now().toUtc();

    final convId = await _conversations.createConversation(
      memberIds: [currentUserId],
    );

    final msg = await _client
        .from('messages')
        .insert({
          'conversation_id': convId,
          'sender_id': currentUserId,
          'type': 'note',
          'encrypted_text': '', // placeholder
          'created_at': now.toIso8601String(),
        })
        .select('id')
        .single();

    await _client.from('pending_invites').insert({
      'phone_number': phoneNumber,
      'inviting_user_id': currentUserId,
      'conversation_id': convId,
      'message_id': msg['id'] as String,
      'expires_at': now.add(const Duration(days: 7)).toIso8601String(),
      'created_at': now.toIso8601String(),
    });

    return convId;
  }
}
