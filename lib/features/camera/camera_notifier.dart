import 'camera_state.dart';

class CameraNotifier {
  CameraState state = const CameraState(conversationId: '');

  Future<void> loadConversation(String conversationId) async {}
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
