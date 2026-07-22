import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roger/features/camera/camera_notifier.dart';
import 'package:roger/features/camera/camera_state.dart';

// Camera 6a (shell): the record button toggles recording mode and flip toggles
// the camera. Real capture / upload / encryption is 6c; note send is 6b; those
// groups stay skipped, scoped to their slice.

void main() {
  group('CameraNotifier', () {
    group('recording (6a — mode toggle only)', () {
      test('startRecording switches mode to recording', () async {
        final container = ProviderContainer.test();
        await container.read(cameraProvider('conv-1').notifier).startRecording();

        expect(container.read(cameraProvider('conv-1')).mode,
            CameraMode.recording);
      });

      test('stopRecording returns to preview mode', () async {
        final container = ProviderContainer.test();
        final notifier = container.read(cameraProvider('conv-1').notifier);
        await notifier.startRecording();
        await notifier.stopRecording();

        expect(
            container.read(cameraProvider('conv-1')).mode, CameraMode.preview);
      });

      test('recording caps at 15 minutes with continuation prompt', () {},
          skip: 'Camera 6c — real capture');

      test('tracks elapsed recording time', () {},
          skip: 'Camera 6c — real capture');
    });

    group('camera', () {
      test('initial state is preview mode, front camera, scoped to conversation',
          () {
        final container = ProviderContainer.test();
        final state = container.read(cameraProvider('conv-1'));

        expect(state.mode, CameraMode.preview);
        expect(state.isFrontCamera, true);
        expect(state.conversationId, 'conv-1');
      });

      test('flipCamera toggles between front and rear', () {
        final container = ProviderContainer.test();
        final notifier = container.read(cameraProvider('conv-1').notifier);

        expect(container.read(cameraProvider('conv-1')).isFrontCamera, true);
        notifier.flipCamera();
        expect(container.read(cameraProvider('conv-1')).isFrontCamera, false);
        notifier.flipCamera();
        expect(container.read(cameraProvider('conv-1')).isFrontCamera, true);
      });
    });

    group('photo', () {
      test('takePhoto captures and uploads encrypted photo', () {},
          skip: 'Camera 6c — photo capture + R2');
    });

    group('note', () {
      test('enterNoteComposer switches mode to noteComposer', () {},
          skip: 'Camera 6b — note composer');

      test('sendNote encrypts text and sends', () {},
          skip: 'Camera 6b — note E2EE + send');
    });

    group('playback', () {
      test('selectThumbnail switches mode to playback', () {},
          skip: 'Camera 6c — playback');

      test('setPlaybackSpeed accepts 0.5x, 1x, 1.5x, 2x', () {},
          skip: 'Camera 6c — playback');

      test('toggleMute flips mute state', () {}, skip: 'Camera 6c — playback');

      test('toggleCaptions triggers on-device transcription', () {},
          skip: 'Camera 6c — playback');
    });

    group('presence and video call', () {
      test('isOtherUserActive updates via Realtime stream', () {},
          skip: 'step 9 — video call presence');

      test('video call pill only appears when other user is active', () {},
          skip: 'step 9 — video call');
    });

    group('content actions', () {
      test('long press own thumbnail shows download/delete/forward menu', () {},
          skip: 'Camera 6c — content actions');

      test('long press other user thumbnail does nothing', () {},
          skip: 'Camera 6c — content actions');

      test('delete purges R2 and notifies all members immediately', () {},
          skip: 'step 11 — R2 purge');

      test('delete interrupts active playback if message is playing', () {},
          skip: 'Camera 6c — content actions');
    });
  });
}
