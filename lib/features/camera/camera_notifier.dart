import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'camera_state.dart';

final cameraProvider =
    NotifierProvider.family<CameraNotifier, CameraState, String>(
  CameraNotifier.new,
);

class CameraNotifier extends Notifier<CameraState> {
  CameraNotifier(this.arg);
  final String arg;

  @override
  CameraState build() => CameraState(conversationId: arg);

  // 6a — shell transitions. Real capture (device camera, timer, 15-min cap,
  // compression, encrypt, R2) lands in 6c; these just drive the UI state.
  Future<void> startRecording() async {
    state = state.copyWith(mode: CameraMode.recording);
  }

  Future<void> stopRecording() async {
    state = state.copyWith(mode: CameraMode.preview);
  }

  Future<void> takePhoto() async {}

  void flipCamera() {
    state = state.copyWith(isFrontCamera: !state.isFrontCamera);
  }
  void selectThumbnail(String messageId) {}
  void setPlaybackSpeed(double speed) {}
  void toggleMute() {}
  void toggleCaptions() {}
  void enterNoteComposer() {}
  Future<void> sendNote({
    required String text,
    required String backgroundColor,
    required String textColor,
  }) async {}
}
