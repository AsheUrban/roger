enum MessageType {
  video,
  photo,
  note,
  callChunk;

  /// The value stored in `messages.type` — snake_case for callChunk, verbatim
  /// for the rest (DB CHECK: 'video' | 'photo' | 'note' | 'call_chunk').
  String get dbValue => switch (this) {
        MessageType.video => 'video',
        MessageType.photo => 'photo',
        MessageType.note => 'note',
        MessageType.callChunk => 'call_chunk',
      };
}

MessageType messageTypeFromDb(String value) {
  return MessageType.values.firstWhere(
    (t) => t.dbValue == value,
    orElse: () => throw ArgumentError('Unknown message type: $value'),
  );
}

class Message {
  final String id;
  final String conversationId;
  // Null when the sender deleted their account (sender_id SET NULL) — their
  // messages persist until they roll off (spec §10).
  final String? senderId;
  final MessageType type;
  final String? r2Key;
  final String? voiceOverlayR2Key;
  final String? encryptedText;
  final String? callSessionId;
  // Null for notes — they go straight to Postgres and never touch R2 (spec §5).
  final DateTime? r2ExpiresAt;
  final DateTime? nudgeSentAt;
  final DateTime createdAt;

  const Message({
    required this.id,
    required this.conversationId,
    this.senderId,
    required this.type,
    this.r2Key,
    this.voiceOverlayR2Key,
    this.encryptedText,
    this.callSessionId,
    this.r2ExpiresAt,
    this.nudgeSentAt,
    required this.createdAt,
  });

  factory Message.fromRow(Map<String, dynamic> row) {
    DateTime? parseOptional(String key) {
      final value = row[key] as String?;
      return value != null ? DateTime.parse(value) : null;
    }

    return Message(
      id: row['id'] as String,
      conversationId: row['conversation_id'] as String,
      senderId: row['sender_id'] as String?,
      type: messageTypeFromDb(row['type'] as String),
      r2Key: row['r2_key'] as String?,
      voiceOverlayR2Key: row['voice_overlay_r2_key'] as String?,
      encryptedText: row['encrypted_text'] as String?,
      callSessionId: row['call_session_id'] as String?,
      r2ExpiresAt: parseOptional('r2_expires_at'),
      nudgeSentAt: parseOptional('nudge_sent_at'),
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Message &&
        other.id == id &&
        other.conversationId == conversationId &&
        other.senderId == senderId &&
        other.type == type &&
        other.r2Key == r2Key &&
        other.voiceOverlayR2Key == voiceOverlayR2Key &&
        other.encryptedText == encryptedText &&
        other.callSessionId == callSessionId &&
        other.r2ExpiresAt == r2ExpiresAt &&
        other.nudgeSentAt == nudgeSentAt &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode => Object.hash(
        id,
        conversationId,
        senderId,
        type,
        r2Key,
        voiceOverlayR2Key,
        encryptedText,
        callSessionId,
        r2ExpiresAt,
        nudgeSentAt,
        createdAt,
      );
}
