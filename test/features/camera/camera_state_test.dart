import 'package:flutter_test/flutter_test.dart';
import 'package:roger/core/models/message.dart';
import 'package:roger/core/models/note_payload.dart';
import 'package:roger/features/camera/camera_state.dart';

// Camera 6a added copyWith (the notifier's record/flip transitions need it).
// Camera 6b-3 adds `notePayloads` (decrypted note content per message id) and
// completes the deferred content-equality contract: `Message.==` now exists, so
// `thumbnails` compares by listEquals and `notePayloads` by mapEquals — same
// treatment the other state classes got in the Riverpod 3 cleanup.

CameraState _state({
  String conversationId = 'conv-1',
  CameraMode mode = CameraMode.preview,
  bool isFrontCamera = true,
  bool isOtherUserActive = false,
  bool isCallActive = false,
  List<Message>? thumbnails,
  Map<String, NotePayload>? notePayloads,
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
    notePayloads: notePayloads ?? const <String, NotePayload>{},
    activeMessage: activeMessage,
    playbackSpeed: playbackSpeed,
    isMuted: isMuted,
    showCaptions: showCaptions,
    recordingElapsed: recordingElapsed,
    isLoading: isLoading,
    error: error,
  );
}

Message _note(String id) => Message(
      id: id,
      conversationId: 'conv-1',
      senderId: 'u-1',
      type: MessageType.note,
      encryptedText: 'cipher-$id',
      createdAt: DateTime(2026, 7, 22),
    );

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

    test('not equal when thumbnails differ in content', () {
      expect(
        _state(thumbnails: const []),
        isNot(equals(_state(thumbnails: [_note('m-1')]))),
      );
    });

    test('equal when thumbnails have the same content but different list '
        'identity (Message.== + listEquals)', () {
      final a = _state(thumbnails: [_note('m-1'), _note('m-2')]);
      final b = _state(thumbnails: [_note('m-1'), _note('m-2')]);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('not equal when notePayloads differ in content', () {
      const payload = NotePayload(
          text: 'hi', backgroundColor: 0xFF000000, textColor: 0xFFFFFFFF);
      expect(
        _state(notePayloads: const {}),
        isNot(equals(_state(notePayloads: const {'m-1': payload}))),
      );
    });

    test('equal when notePayloads have the same content but different map '
        'identity', () {
      const payload = NotePayload(
          text: 'hi', backgroundColor: 0xFF000000, textColor: 0xFFFFFFFF);
      final a = _state(notePayloads: {'m-1': payload});
      final b = _state(notePayloads: {'m-1': payload});
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('not equal when activeMessage differs', () {
      expect(_state(activeMessage: null),
          isNot(equals(_state(activeMessage: _note('m-1')))));
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
