enum MessageType { video, photo, note, callChunk }

class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final MessageType type;
  final String? r2Key;
  final String? voiceOverlayR2Key;
  final String? encryptedText;
  final String? callSessionId;
  final DateTime r2ExpiresAt;
  final DateTime? nudgeSentAt;
  final DateTime createdAt;

  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.type,
    this.r2Key,
    this.voiceOverlayR2Key,
    this.encryptedText,
    this.callSessionId,
    required this.r2ExpiresAt,
    this.nudgeSentAt,
    required this.createdAt,
  });
}
