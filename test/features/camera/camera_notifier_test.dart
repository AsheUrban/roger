import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CameraNotifier', skip: 'feature not built — step 6', () {
    group('recording', () {
      test('startRecording switches mode to recording', () {});

      test('stopRecording uploads encrypted video and returns to preview',
          () {});

      test('recording caps at 15 minutes with continuation prompt', () {});

      test('tracks elapsed recording time', () {});
    });

    group('photo', () {
      test('takePhoto captures and uploads encrypted photo', () {});
    });

    group('note', () {
      test('enterNoteComposer switches mode to noteComposer', () {});

      test('sendNote encrypts text and sends', () {});
    });

    group('playback', () {
      test('selectThumbnail switches mode to playback', () {});

      test('setPlaybackSpeed accepts 0.5x, 1x, 1.5x, 2x', () {});

      test('toggleMute flips mute state', () {});

      test('toggleCaptions triggers on-device transcription', () {});
    });

    group('camera', () {
      test('defaults to front-facing camera', () {});

      test('flipCamera toggles between front and rear', () {});
    });

    group('presence and video call', () {
      test('isOtherUserActive updates via Realtime stream', () {});

      test('video call pill only appears when other user is active', () {});
    });

    group('content actions', () {
      test('long press own thumbnail shows download/delete/forward menu', () {});

      test('long press other user thumbnail does nothing', () {});

      test('delete purges R2 and notifies all members immediately', () {});

      test('delete interrupts active playback if message is playing', () {});
    });
  });
}
