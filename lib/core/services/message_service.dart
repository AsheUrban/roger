import 'dart:typed_data';

import '../models/message.dart';
import '../models/message_view.dart';
import '../models/reaction_emoji.dart';
import '../models/reaction_video.dart';

class MessageService {
  Future<Message> sendVideo({
    required String conversationId,
    required Uint8List encryptedData,
  }) async =>
      throw UnimplementedError();
  Future<Message> sendPhoto({
    required String conversationId,
    required Uint8List encryptedData,
    Uint8List? encryptedVoiceOverlay,
  }) async =>
      throw UnimplementedError();
  Future<Message> sendNote({
    required String conversationId,
    required String encryptedText,
  }) async =>
      throw UnimplementedError();
  Future<List<Message>> getMessages({required String conversationId}) async =>
      throw UnimplementedError();
  Stream<List<Message>> watchMessages({required String conversationId}) =>
      throw UnimplementedError();
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
