import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/message.dart';
import '../../core/models/note_payload.dart';
import '../../core/providers.dart';
import '../../core/services/encryption_service.dart';
import '../../core/services/key_service.dart';
import '../../core/services/message_service.dart';
import 'camera_state.dart';

final cameraProvider =
    NotifierProvider.family<CameraNotifier, CameraState, String>(
  CameraNotifier.new,
);

class CameraNotifier extends Notifier<CameraState> {
  CameraNotifier(this.arg);
  final String arg;

  late final MessageService _messageService;
  late final KeyService _keyService;
  late final EncryptionService _encryptionService;
  StreamSubscription<List<Message>>? _messagesSub;

  @override
  CameraState build() {
    _messageService = ref.read(messageServiceProvider);
    _keyService = ref.read(keyServiceProvider);
    _encryptionService = ref.read(encryptionServiceProvider);

    ref.onDispose(() {
      _messagesSub?.cancel();
    });

    // microtask ensures build() returns before any state mutations.
    Future.microtask(_subscribe);
    return CameraState(conversationId: arg);
  }

  void _subscribe() {
    if (!ref.mounted) return;
    _messagesSub = _messageService
        .watchMessages(conversationId: arg)
        .listen(_onMessages, onError: (Object e) {
      if (!ref.mounted) return;
      state = state.copyWith(error: () => e.toString());
    });
  }

  /// Applies a fresh message list from the stream: decrypts any note not yet
  /// in the payload map, then swaps the list in. An undecryptable note stays
  /// in the thumbnails (the strip shows it) but out of the payload map (the
  /// viewer shows an error state instead of content).
  Future<void> _onMessages(List<Message> messages) async {
    final payloads = Map<String, NotePayload>.from(state.notePayloads);
    String? conversationKey;

    for (final message in messages) {
      if (message.type != MessageType.note) continue;
      if (payloads.containsKey(message.id)) continue;
      final ciphertext = message.encryptedText;
      if (ciphertext == null) continue;
      try {
        conversationKey ??= await _keyService.getConversationKey(arg);
        final clear = await _encryptionService.decryptText(
          ciphertext: ciphertext,
          conversationKey: conversationKey,
        );
        payloads[message.id] = NotePayload.fromJsonString(clear);
      } catch (_) {
        // Wrong/missing key or corrupt payload — leave it out of the map.
      }
    }

    if (!ref.mounted) return;
    state = state.copyWith(thumbnails: messages, notePayloads: payloads);
  }

  // ── 6a shell transitions — real capture lands in 6c ──────────────────────

  Future<void> startRecording() async {
    state = state.copyWith(mode: CameraMode.recording);
  }

  Future<void> stopRecording() async {
    state = state.copyWith(mode: CameraMode.preview);
  }

  Future<void> takePhoto() async {} // Camera 6c

  void flipCamera() {
    state = state.copyWith(isFrontCamera: !state.isFrontCamera);
  }

  // ── Note composer (6b) ───────────────────────────────────────────────────

  void enterNoteComposer() {
    state = state.copyWith(mode: CameraMode.noteComposer);
  }

  void exitNoteComposer() {
    state = state.copyWith(mode: CameraMode.preview);
  }

  /// Encrypts and sends a note: payload (text + colors) → conversation key →
  /// AES-GCM → Postgres. Encryption always precedes the network call (§7).
  Future<void> sendNote({
    required String text,
    required int backgroundColor,
    required int textColor,
  }) async {
    // Never send an empty note (spec §5 invariant). Whitespace-only counts as
    // empty; the original text (with any deliberate whitespace) is what sends.
    if (text.trim().isEmpty) return;
    // Re-entry guard: a send is already in flight — impatient re-taps must not
    // duplicate the note. (The Send pill also disables off isLoading.)
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, error: () => null);

    try {
      final conversationKey = await _keyService.getConversationKey(arg);
      final payload = NotePayload(
        text: text,
        backgroundColor: backgroundColor,
        textColor: textColor,
      );
      final ciphertext = await _encryptionService.encryptText(
        plaintext: payload.toJsonString(),
        conversationKey: conversationKey,
      );
      final message = await _messageService.sendNote(
        conversationId: arg,
        encryptedText: ciphertext,
      );
      if (!ref.mounted) return;

      // Thumbnail appears immediately (spec §5); the stream will deliver the
      // same row shortly and simply replace the list.
      final thumbnails = [
        ...state.thumbnails.where((m) => m.id != message.id),
        message,
      ];
      state = state.copyWith(
        thumbnails: thumbnails,
        notePayloads: {...state.notePayloads, message.id: payload},
        mode: CameraMode.preview,
        isLoading: false,
      );
    } catch (e) {
      if (!ref.mounted) return;
      // Stay in the composer so the text is not lost (spec §18: "Do not lose
      // the text"); an automatic retry queue is future work (tracked with the
      // upload-retry open question).
      state = state.copyWith(isLoading: false, error: () => e.toString());
    }
  }

  // ── Playback / note viewer (6b: notes; 6c adds video) ────────────────────

  void selectThumbnail(String messageId) {
    final matches = state.thumbnails.where((m) => m.id == messageId);
    if (matches.isEmpty) return;
    state = state.copyWith(
      mode: CameraMode.playback,
      activeMessage: () => matches.first,
    );
  }

  void closePlayback() {
    state = state.copyWith(
      mode: CameraMode.preview,
      activeMessage: () => null,
    );
  }

  void setPlaybackSpeed(double speed) {} // Camera 6c
  void toggleMute() {} // Camera 6c
  void toggleCaptions() {} // Camera 6c
}
