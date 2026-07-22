import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:roger/core/models/message.dart';
import 'package:roger/core/models/note_payload.dart';
import 'package:roger/core/providers.dart';
import 'package:roger/core/services/encryption_service.dart';
import 'package:roger/core/services/key_service.dart';
import 'package:roger/core/services/message_service.dart';
import 'package:roger/features/camera/camera_notifier.dart';
import 'package:roger/features/camera/camera_state.dart';

// Camera 6b-3: the notifier owns the note spine — watch + decrypt incoming
// messages into thumbnails/payloads, and the encrypted send path
// (payload → conversation key → encrypt → MessageService). Recording/flip are
// 6a shell transitions; real capture stays 6c.

class MockMessageService extends Mock implements MessageService {}

class MockKeyService extends Mock implements KeyService {}

class MockEncryptionService extends Mock implements EncryptionService {}

const _convId = 'conv-1';

Message _note(String id, {String? senderId = 'u-other'}) => Message(
      id: id,
      conversationId: _convId,
      senderId: senderId,
      type: MessageType.note,
      encryptedText: 'cipher-$id',
      createdAt: DateTime(2026, 7, 22),
    );

void main() {
  late MockMessageService messageService;
  late MockKeyService keyService;
  late MockEncryptionService encryptionService;
  late StreamController<List<Message>> messages;

  const payload = NotePayload(
    text: 'hello',
    backgroundColor: 0xFF1E1D18,
    textColor: 0xFFFAFAF5,
  );

  setUp(() {
    messageService = MockMessageService();
    keyService = MockKeyService();
    encryptionService = MockEncryptionService();
    messages = StreamController<List<Message>>.broadcast();

    when(() => messageService.watchMessages(conversationId: _convId))
        .thenAnswer((_) => messages.stream);
    when(() => keyService.getConversationKey(_convId))
        .thenAnswer((_) async => 'conv-key');
    when(() => encryptionService.decryptText(
          ciphertext: any(named: 'ciphertext'),
          conversationKey: any(named: 'conversationKey'),
        )).thenAnswer((_) async => payload.toJsonString());
  });

  tearDown(() async {
    await messages.close();
  });

  ProviderContainer makeContainer() {
    return ProviderContainer.test(overrides: [
      messageServiceProvider.overrideWithValue(messageService),
      keyServiceProvider.overrideWithValue(keyService),
      encryptionServiceProvider.overrideWithValue(encryptionService),
    ]);
  }

  group('CameraNotifier', () {
    group('recording (6a — mode toggle only)', () {
      test('startRecording switches mode to recording', () async {
        final container = makeContainer();
        await container.read(cameraProvider(_convId).notifier).startRecording();

        expect(
            container.read(cameraProvider(_convId)).mode, CameraMode.recording);
      });

      test('stopRecording returns to preview mode', () async {
        final container = makeContainer();
        final notifier = container.read(cameraProvider(_convId).notifier);
        await notifier.startRecording();
        await notifier.stopRecording();

        expect(
            container.read(cameraProvider(_convId)).mode, CameraMode.preview);
      });

      test('recording caps at 15 minutes with continuation prompt', () {},
          skip: 'Camera 6c — real capture');

      test('tracks elapsed recording time', () {},
          skip: 'Camera 6c — real capture');
    });

    group('camera', () {
      test('initial state is preview mode, front camera, scoped to conversation',
          () {
        final container = makeContainer();
        final state = container.read(cameraProvider(_convId));

        expect(state.mode, CameraMode.preview);
        expect(state.isFrontCamera, true);
        expect(state.conversationId, _convId);
      });

      test('flipCamera toggles between front and rear', () {
        final container = makeContainer();
        final notifier = container.read(cameraProvider(_convId).notifier);

        expect(container.read(cameraProvider(_convId)).isFrontCamera, true);
        notifier.flipCamera();
        expect(container.read(cameraProvider(_convId)).isFrontCamera, false);
        notifier.flipCamera();
        expect(container.read(cameraProvider(_convId)).isFrontCamera, true);
      });
    });

    group('incoming messages (watch + decrypt)', () {
      test('subscribes to the conversation message stream and decrypts notes '
          'into notePayloads', () async {
        final container = makeContainer();
        container.read(cameraProvider(_convId));
        await pumpEventQueue();

        messages.add([_note('m-1')]);
        await pumpEventQueue();

        final state = container.read(cameraProvider(_convId));
        expect(state.thumbnails.length, 1);
        expect(state.thumbnails.first.id, 'm-1');
        expect(state.notePayloads['m-1'], payload);
        verify(() => encryptionService.decryptText(
              ciphertext: 'cipher-m-1',
              conversationKey: 'conv-key',
            )).called(1);
      });

      test('an undecryptable note stays in thumbnails but out of notePayloads',
          () async {
        when(() => encryptionService.decryptText(
              ciphertext: any(named: 'ciphertext'),
              conversationKey: any(named: 'conversationKey'),
            )).thenThrow(Exception('bad key'));

        final container = makeContainer();
        container.read(cameraProvider(_convId));
        await pumpEventQueue();

        messages.add([_note('m-1')]);
        await pumpEventQueue();

        final state = container.read(cameraProvider(_convId));
        expect(state.thumbnails.length, 1);
        expect(state.notePayloads, isEmpty);
      });

      test('already-decrypted notes are not decrypted again on the next emit',
          () async {
        final container = makeContainer();
        container.read(cameraProvider(_convId));
        await pumpEventQueue();

        messages.add([_note('m-1')]);
        await pumpEventQueue();
        messages.add([_note('m-1'), _note('m-2')]);
        await pumpEventQueue();

        verify(() => encryptionService.decryptText(
              ciphertext: 'cipher-m-1',
              conversationKey: any(named: 'conversationKey'),
            )).called(1);
        verify(() => encryptionService.decryptText(
              ciphertext: 'cipher-m-2',
              conversationKey: any(named: 'conversationKey'),
            )).called(1);
      });
    });

    group('note composer', () {
      test('enterNoteComposer switches mode; exitNoteComposer returns to '
          'preview', () {
        final container = makeContainer();
        final notifier = container.read(cameraProvider(_convId).notifier);

        notifier.enterNoteComposer();
        expect(container.read(cameraProvider(_convId)).mode,
            CameraMode.noteComposer);

        notifier.exitNoteComposer();
        expect(
            container.read(cameraProvider(_convId)).mode, CameraMode.preview);
      });
    });

    group('sendNote', () {
      setUp(() {
        when(() => encryptionService.encryptText(
              plaintext: any(named: 'plaintext'),
              conversationKey: any(named: 'conversationKey'),
            )).thenAnswer((_) async => 'note-ciphertext');
        when(() => messageService.sendNote(
              conversationId: _convId,
              encryptedText: 'note-ciphertext',
            )).thenAnswer((_) async => _note('m-new', senderId: 'u-me'));
      });

      test('encrypts the payload with the conversation key and sends it',
          () async {
        final container = makeContainer();
        final notifier = container.read(cameraProvider(_convId).notifier);
        notifier.enterNoteComposer();

        await notifier.sendNote(
          text: 'hello',
          backgroundColor: 0xFF1E1D18,
          textColor: 0xFFFAFAF5,
        );

        final plaintext = verify(() => encryptionService.encryptText(
              plaintext: captureAny(named: 'plaintext'),
              conversationKey: 'conv-key',
            )).captured.single as String;
        expect(NotePayload.fromJsonString(plaintext), payload);
        verify(() => messageService.sendNote(
              conversationId: _convId,
              encryptedText: 'note-ciphertext',
            )).called(1);

        // Thumbnail appears immediately (spec §5); payload cached; back to
        // preview.
        final state = container.read(cameraProvider(_convId));
        expect(state.thumbnails.map((m) => m.id), contains('m-new'));
        expect(state.notePayloads['m-new'], payload);
        expect(state.mode, CameraMode.preview);
        expect(state.isLoading, false);
      });

      test('never sends an empty or whitespace-only note (spec §5 invariant)',
          () async {
        final container = makeContainer();
        final notifier = container.read(cameraProvider(_convId).notifier);

        await notifier.sendNote(
            text: '', backgroundColor: 0, textColor: 0);
        await notifier.sendNote(
            text: '   \n ', backgroundColor: 0, textColor: 0);

        verifyNever(() => messageService.sendNote(
              conversationId: any(named: 'conversationId'),
              encryptedText: any(named: 'encryptedText'),
            ));
        verifyNever(() => encryptionService.encryptText(
              plaintext: any(named: 'plaintext'),
              conversationKey: any(named: 'conversationKey'),
            ));
      });

      test('a second Send while one is in flight is ignored — impatient '
          'tapping must not duplicate the note', () async {
        final firstSend = Completer<Message>();
        when(() => messageService.sendNote(
              conversationId: _convId,
              encryptedText: 'note-ciphertext',
            )).thenAnswer((_) => firstSend.future);

        final container = makeContainer();
        final notifier = container.read(cameraProvider(_convId).notifier);
        notifier.enterNoteComposer();

        final f1 = notifier.sendNote(
            text: 'hello', backgroundColor: 0xFF1E1D18, textColor: 0xFFFAFAF5);
        final f2 = notifier.sendNote(
            text: 'hello', backgroundColor: 0xFF1E1D18, textColor: 0xFFFAFAF5);
        firstSend.complete(_note('m-new', senderId: 'u-me'));
        await f1;
        await f2;

        verify(() => messageService.sendNote(
              conversationId: any(named: 'conversationId'),
              encryptedText: any(named: 'encryptedText'),
            )).called(1);
        expect(
          container
              .read(cameraProvider(_convId))
              .thumbnails
              .where((m) => m.id == 'm-new')
              .length,
          1,
        );
      });

      test('a failed send keeps the composer open with an error — the text is '
          'not lost (spec §18)', () async {
        when(() => messageService.sendNote(
              conversationId: any(named: 'conversationId'),
              encryptedText: any(named: 'encryptedText'),
            )).thenThrow(Exception('network'));

        final container = makeContainer();
        final notifier = container.read(cameraProvider(_convId).notifier);
        notifier.enterNoteComposer();

        await notifier.sendNote(
          text: 'hello',
          backgroundColor: 0xFF1E1D18,
          textColor: 0xFFFAFAF5,
        );

        final state = container.read(cameraProvider(_convId));
        expect(state.mode, CameraMode.noteComposer);
        expect(state.error, isNotNull);
        expect(state.isLoading, false);
      });
    });

    group('playback (note viewer)', () {
      test('selectThumbnail enters playback with that message active', () async {
        final container = makeContainer();
        container.read(cameraProvider(_convId));
        await pumpEventQueue();
        messages.add([_note('m-1')]);
        await pumpEventQueue();

        container.read(cameraProvider(_convId).notifier).selectThumbnail('m-1');

        final state = container.read(cameraProvider(_convId));
        expect(state.mode, CameraMode.playback);
        expect(state.activeMessage?.id, 'm-1');
      });

      test('selectThumbnail for an unknown id is a no-op', () {
        final container = makeContainer();
        container.read(cameraProvider(_convId).notifier).selectThumbnail('nope');

        expect(
            container.read(cameraProvider(_convId)).mode, CameraMode.preview);
      });

      test('closePlayback returns to preview and clears the active message',
          () async {
        final container = makeContainer();
        container.read(cameraProvider(_convId));
        await pumpEventQueue();
        messages.add([_note('m-1')]);
        await pumpEventQueue();

        final notifier = container.read(cameraProvider(_convId).notifier);
        notifier.selectThumbnail('m-1');
        notifier.closePlayback();

        final state = container.read(cameraProvider(_convId));
        expect(state.mode, CameraMode.preview);
        expect(state.activeMessage, isNull);
      });

      test('setPlaybackSpeed accepts 0.5x, 1x, 1.5x, 2x', () {},
          skip: 'Camera 6c — video playback');

      test('toggleMute flips mute state', () {},
          skip: 'Camera 6c — video playback');

      test('toggleCaptions triggers on-device transcription', () {},
          skip: 'Camera 6c — video playback');
    });

    group('photo', () {
      test('takePhoto captures and uploads encrypted photo', () {},
          skip: 'Camera 6c — photo capture + R2');
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
