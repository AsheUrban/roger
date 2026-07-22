import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/message.dart';
import '../models/message_view.dart';
import '../models/reaction_emoji.dart';
import '../models/reaction_video.dart';

/// Message rows against Supabase. Content arrives here ALREADY encrypted —
/// encryption happens a layer up (spec §7: encryption before any network
/// activity), so this service never sees plaintext.
///
/// 6b builds the note spine (send / fetch / watch). Video and photo sends land
/// in 6c; content actions, views, reactions, and the rolling window follow
/// their build-order steps.
class MessageService {
  final SupabaseClient _client;

  MessageService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  Future<Message> sendVideo({
    required String conversationId,
    required Uint8List encryptedData,
  }) async =>
      throw UnimplementedError(); // Camera 6c

  Future<Message> sendPhoto({
    required String conversationId,
    required Uint8List encryptedData,
    Uint8List? encryptedVoiceOverlay,
  }) async =>
      throw UnimplementedError(); // Camera 6c

  /// Stores an (already encrypted) note. Notes go straight to Postgres — no
  /// R2, no expiry (spec §5).
  Future<Message> sendNote({
    required String conversationId,
    required String encryptedText,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw StateError('Not authenticated.');
    }
    final row = await _client
        .from('messages')
        .insert({
          'conversation_id': conversationId,
          'sender_id': uid,
          'type': MessageType.note.dbValue,
          'encrypted_text': encryptedText,
        })
        .select()
        .single();
    return Message.fromRow(row);
  }

  Future<List<Message>> getMessages({required String conversationId}) async {
    final rows = await _client
        .from('messages')
        .select()
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true) as List;
    return rows
        .map((r) => Message.fromRow(r as Map<String, dynamic>))
        .toList();
  }

  /// The conversation's messages as a live stream — emits the current list
  /// immediately, then again on every change (Supabase realtime; RLS applies).
  /// Ascending by created_at, so the newest message renders rightmost (§3).
  Stream<List<Message>> watchMessages({required String conversationId}) {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true)
        .map((rows) => rows.map(Message.fromRow).toList());
  }

  Future<void> deleteMessage({required String messageId}) async {}
  Future<void> forwardMessage({
    required String messageId,
    required String targetConversationId,
  }) async {}
  Future<Uint8List> downloadDecrypted({required String messageId}) async =>
      throw UnimplementedError();
  Future<MessageView> markDownloaded({required String messageId}) async =>
      throw UnimplementedError();
  Future<MessageView> markViewed({required String messageId}) async =>
      throw UnimplementedError();
  Future<ReactionEmoji> sendEmojiReaction({
    required String messageId,
    required String emoji,
  }) async =>
      throw UnimplementedError();
  Future<ReactionVideo> sendVideoReaction({
    required String parentMessageId,
    required Uint8List encryptedData,
  }) async =>
      throw UnimplementedError();
  Future<List<ReactionEmoji>> getEmojiReactions({
    required String messageId,
  }) async =>
      throw UnimplementedError();
  Future<List<ReactionVideo>> getVideoReactions({
    required String messageId,
  }) async =>
      throw UnimplementedError();
  Future<void> enforceRollingWindow({required int messageLimit}) async {}
}
