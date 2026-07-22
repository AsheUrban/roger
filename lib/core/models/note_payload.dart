import 'dart:convert';

/// The decrypted content of a note message (Camera 6b).
///
/// A note's background and text colors are content, not metadata, so they ride
/// inside the encrypted payload — `messages.encrypted_text` stores the
/// ciphertext of this JSON envelope, and the server never sees any of it
/// (spec §18 invariant 1). Colors are ARGB ints so the viewer renders exactly
/// what was composed, with no palette-name lookup between devices.
class NotePayload {
  final String text;
  final int backgroundColor;
  final int textColor;

  const NotePayload({
    required this.text,
    required this.backgroundColor,
    required this.textColor,
  });

  String toJsonString() => jsonEncode({
        'text': text,
        'backgroundColor': backgroundColor,
        'textColor': textColor,
      });

  /// Throws on malformed input — a note that can't be decoded must surface as
  /// an error, never render silently broken.
  factory NotePayload.fromJsonString(String source) {
    final map = jsonDecode(source) as Map<String, dynamic>;
    return NotePayload(
      text: map['text'] as String,
      backgroundColor: map['backgroundColor'] as int,
      textColor: map['textColor'] as int,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NotePayload &&
        other.text == text &&
        other.backgroundColor == backgroundColor &&
        other.textColor == textColor;
  }

  @override
  int get hashCode => Object.hash(text, backgroundColor, textColor);
}
