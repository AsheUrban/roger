import '../../core/models/message.dart';

enum CameraMode { preview, recording, playback, noteComposer }

class CameraState {
  final String conversationId;
  final CameraMode mode;
  final bool isFrontCamera;
  final bool isOtherUserActive;
  final bool isCallActive;
  final List<Message> thumbnails;
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
    this.activeMessage,
    this.playbackSpeed = 1.0,
    this.isMuted = false,
    this.showCaptions = false,
    this.recordingElapsed = Duration.zero,
    this.isLoading = false,
    this.error,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CameraState &&
        other.conversationId == conversationId &&
        other.mode == mode &&
        other.isFrontCamera == isFrontCamera &&
        other.isOtherUserActive == isOtherUserActive &&
        other.isCallActive == isCallActive &&
        other.thumbnails == thumbnails &&
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
        thumbnails,
        activeMessage,
        playbackSpeed,
        isMuted,
        showCaptions,
        recordingElapsed,
        isLoading,
        error,
      );
}
