import 'package:flutter/foundation.dart';

import '../../core/models/message.dart';
import '../../core/models/note_payload.dart';

enum CameraMode { preview, recording, playback, noteComposer }

class CameraState {
  final String conversationId;
  final CameraMode mode;
  final bool isFrontCamera;
  final bool isOtherUserActive;
  final bool isCallActive;
  // The conversation's messages, ascending by created_at (newest renders
  // rightmost in the strip, per §3).
  final List<Message> thumbnails;
  // Decrypted note content per message id. Decryption happens once as messages
  // arrive; a note missing from this map failed to decrypt (viewer shows an
  // error state instead of content).
  final Map<String, NotePayload> notePayloads;
  final Message? activeMessage;
  final double playbackSpeed;
  final bool isMuted;
  final bool showCaptions;
  final Duration recordingElapsed;
  final bool isLoading;
  final String? error;

  const CameraState({
    required this.conversationId,
    this.mode = CameraMode.preview,
    this.isFrontCamera = true,
    this.isOtherUserActive = false,
    this.isCallActive = false,
    this.thumbnails = const [],
    this.notePayloads = const {},
    this.activeMessage,
    this.playbackSpeed = 1.0,
    this.isMuted = false,
    this.showCaptions = false,
    this.recordingElapsed = Duration.zero,
    this.isLoading = false,
    this.error,
  });

  CameraState copyWith({
    String? conversationId,
    CameraMode? mode,
    bool? isFrontCamera,
    bool? isOtherUserActive,
    bool? isCallActive,
    List<Message>? thumbnails,
    Map<String, NotePayload>? notePayloads,
    Message? Function()? activeMessage,
    double? playbackSpeed,
    bool? isMuted,
    bool? showCaptions,
    Duration? recordingElapsed,
    bool? isLoading,
    String? Function()? error,
  }) {
    return CameraState(
      conversationId: conversationId ?? this.conversationId,
      mode: mode ?? this.mode,
      isFrontCamera: isFrontCamera ?? this.isFrontCamera,
      isOtherUserActive: isOtherUserActive ?? this.isOtherUserActive,
      isCallActive: isCallActive ?? this.isCallActive,
      thumbnails: thumbnails ?? this.thumbnails,
      notePayloads: notePayloads ?? this.notePayloads,
      activeMessage:
          activeMessage != null ? activeMessage() : this.activeMessage,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      isMuted: isMuted ?? this.isMuted,
      showCaptions: showCaptions ?? this.showCaptions,
      recordingElapsed: recordingElapsed ?? this.recordingElapsed,
      isLoading: isLoading ?? this.isLoading,
      error: error != null ? error() : this.error,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CameraState &&
        other.conversationId == conversationId &&
        other.mode == mode &&
        other.isFrontCamera == isFrontCamera &&
        other.isOtherUserActive == isOtherUserActive &&
        other.isCallActive == isCallActive &&
        listEquals(other.thumbnails, thumbnails) &&
        mapEquals(other.notePayloads, notePayloads) &&
        other.activeMessage == activeMessage &&
        other.playbackSpeed == playbackSpeed &&
        other.isMuted == isMuted &&
        other.showCaptions == showCaptions &&
        other.recordingElapsed == recordingElapsed &&
        other.isLoading == isLoading &&
        other.error == error;
  }

  @override
  int get hashCode => Object.hash(
        conversationId,
        mode,
        isFrontCamera,
        isOtherUserActive,
        isCallActive,
        Object.hashAll(thumbnails),
        Object.hashAllUnordered(
            notePayloads.entries.map((e) => Object.hash(e.key, e.value))),
        activeMessage,
        playbackSpeed,
        isMuted,
        showCaptions,
        recordingElapsed,
        isLoading,
        error,
      );
}
