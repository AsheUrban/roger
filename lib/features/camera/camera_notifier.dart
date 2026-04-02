import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'camera_state.dart';

final cameraProvider =
    NotifierProvider.family<CameraNotifier, CameraState, String>(
  CameraNotifier.new,
);

class CameraNotifier extends FamilyNotifier<CameraState, String> {
  @override
  CameraState build(String arg) => CameraState(conversationId: arg);

  Future<void> startRecording() async {}
  Future<void> stopRecording() async {}
  Future<void> takePhoto() async {}
  void flipCamera() {}
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
