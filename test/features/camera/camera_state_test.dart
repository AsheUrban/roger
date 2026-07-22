import 'package:flutter_test/flutter_test.dart';
import 'package:roger/core/models/message.dart';
import 'package:roger/features/camera/camera_state.dart';

// Camera 6a adds copyWith (the notifier's record/flip transitions need it).
// Equality contracts (equal-when-fields-match, not-equal-when-any-differs)
// were already covered; the copyWith contract is added below.

CameraState _state({
  String conversationId = 'conv-1',
  CameraMode mode = CameraMode.preview,
  bool isFrontCamera = true,
  bool isOtherUserActive = false,
  bool isCallActive = false,
  List<Message>? thumbnails,
  Message? activeMessage,
  double playbackSpeed = 1.0,
  bool isMuted = false,
  bool showCaptions = false,
  Duration recordingElapsed = Duration.zero,
  bool isLoading = false,
  String? error,
}) {
  return CameraState(
    conversationId: conversationId,
    mode: mode,
    isFrontCamera: isFrontCamera,
    isOtherUserActive: isOtherUserActive,
    isCallActive: isCallActive,
    thumbnails: thumbnails ?? const <Message>[],
    activeMessage: activeMessage,
    playbackSpeed: playbackSpeed,
    isMuted: isMuted,
    showCaptions: showCaptions,
    recordingElapsed: recordingElapsed,
    isLoading: isLoading,
    error: error,
  );
}

void main() {
  group('CameraState equality', () {
    test('two instances with same field values are equal (shared list ref)',
        () {
      final thumbnails = const <Message>[];
      final a = CameraState(
        conversationId: 'conv-1',
        mode: CameraMode.recording,
        isFrontCamera: false,
        isOtherUserActive: true,
        isCallActive: true,
        thumbnails: thumbnails,
        activeMessage: null,
        playbackSpeed: 1.5,
        isMuted: true,
        showCaptions: true,
        recordingElapsed: const Duration(seconds: 7),
        isLoading: true,
        error: 'oops',
      );
      final b = CameraState(
        conversationId: 'conv-1',
        mode: CameraMode.recording,
        isFrontCamera: false,
        isOtherUserActive: true,
        isCallActive: true,
        thumbnails: thumbnails,
        activeMessage: null,
        playbackSpeed: 1.5,
        isMuted: true,
        showCaptions: true,
        recordingElapsed: const Duration(seconds: 7),
        isLoading: true,
        error: 'oops',
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('two default-ish instances are equal', () {
      final a = _state();
      final b = _state();
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('not equal when conversationId differs', () {
      expect(_state(conversationId: 'conv-1'),
          isNot(equals(_state(conversationId: 'conv-2'))));
    });

    test('not equal when mode differs', () {
      expect(_state(mode: CameraMode.preview),
          isNot(equals(_state(mode: CameraMode.recording))));
    });

    test('not equal when isFrontCamera differs', () {
      expect(_state(isFrontCamera: true),
          isNot(equals(_state(isFrontCamera: false))));
    });

    test('not equal when isOtherUserActive differs', () {
      expect(_state(isOtherUserActive: false),
          isNot(equals(_state(isOtherUserActive: true))));
    });

    test('not equal when isCallActive differs', () {
      expect(_state(isCallActive: false),
          isNot(equals(_state(isCallActive: true))));
    });

    test('not equal when thumbnails differ (different list identity)', () {
      final later = DateTime(2026, 4, 8);
      final message = Message(
        id: 'm-1',
        conversationId: 'conv-1',
        senderId: 'u-1',
        type: MessageType.note,
        r2ExpiresAt: later,
        createdAt: later,
      );
      expect(
        _state(thumbnails: const []),
        isNot(equals(_state(thumbnails: [message]))),
      );
    });

    test('not equal when activeMessage differs (different identity)', () {
      final later = DateTime(2026, 4, 8);
      final message = Message(
        id: 'm-1',
        conversationId: 'conv-1',
        senderId: 'u-1',
        type: MessageType.note,
        r2ExpiresAt: later,
        createdAt: later,
      );
      expect(_state(activeMessage: null),
          isNot(equals(_state(activeMessage: message))));
    });

    test('not equal when playbackSpeed differs', () {
      expect(_state(playbackSpeed: 1.0),
          isNot(equals(_state(playbackSpeed: 2.0))));
    });

    test('not equal when isMuted differs', () {
      expect(_state(isMuted: false), isNot(equals(_state(isMuted: true))));
    });

    test('not equal when showCaptions differs', () {
      expect(_state(showCaptions: false),
          isNot(equals(_state(showCaptions: true))));
    });

    test('not equal when recordingElapsed differs', () {
      expect(
        _state(recordingElapsed: Duration.zero),
        isNot(equals(_state(recordingElapsed: const Duration(seconds: 5)))),
      );
    });

    test('not equal when isLoading differs', () {
      expect(
          _state(isLoading: false), isNot(equals(_state(isLoading: true))));
    });

    test('not equal when error differs', () {
      expect(_state(), isNot(equals(_state(error: 'oops'))));
    });
  });

  group('CameraState copyWith', () {
    test('overrides only the given fields, leaving the rest intact', () {
      final base = _state(conversationId: 'conv-9', playbackSpeed: 1.5);
      final updated =
          base.copyWith(mode: CameraMode.recording, isFrontCamera: false);

      expect(updated.mode, CameraMode.recording);
      expect(updated.isFrontCamera, false);
      // Untouched fields carry over.
      expect(updated.conversationId, 'conv-9');
      expect(updated.playbackSpeed, 1.5);
    });

    test('returns an equal state when nothing is overridden', () {
      final base = _state(mode: CameraMode.recording, isFrontCamera: false);
      expect(base.copyWith(), equals(base));
    });

    test('can set and clear the nullable error via the wrapper', () {
      final withError = _state().copyWith(error: () => 'boom');
      expect(withError.error, 'boom');

      final cleared = withError.copyWith(error: () => null);
      expect(cleared.error, isNull);
    });
  });
}
