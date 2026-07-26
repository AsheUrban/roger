import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:roger/core/models/conversation.dart';
import 'package:roger/core/models/message.dart';
import 'package:roger/core/models/note_payload.dart';
import 'package:roger/core/models/user.dart';
import 'package:roger/core/theme/colors.dart';
import 'package:roger/features/camera/camera_notifier.dart';
import 'package:roger/features/camera/camera_screen.dart';
import 'package:roger/features/camera/camera_state.dart';
import 'package:roger/features/conversations/conversations_notifier.dart';
import 'package:roger/features/conversations/conversations_state.dart';

// Camera 6a (shell): full-bleed layout, header (name/presence + flip + back),
// record button idle/recording states, Row 2 (photo/note/settings) that hides
// mid-record, empty thumbnail strip. Live feed stubbed; sends deferred. Sidebar
// (step 7), video call pill (step 9), playback + note composer (6c/6b) stay
// skipped.

const _convId = 'conv-1';

// A fake notifier that serves a fixed state and counts control taps.
class _FakeCameraNotifier extends CameraNotifier {
  final CameraState _state;
  _FakeCameraNotifier(this._state) : super(_state.conversationId);

  int startRecordingCalls = 0;
  int stopRecordingCalls = 0;
  int flipCalls = 0;
  int photoCalls = 0;
  int noteCalls = 0;
  int exitComposerCalls = 0;
  int closePlaybackCalls = 0;
  final List<String> selectedThumbnails = [];
  final List<({String text, int backgroundColor, int textColor})> sentNotes =
      [];

  @override
  CameraState build() => _state;

  @override
  Future<void> startRecording() async => startRecordingCalls++;

  @override
  Future<void> stopRecording() async => stopRecordingCalls++;

  @override
  void flipCamera() => flipCalls++;

  @override
  Future<void> takePhoto() async => photoCalls++;

  @override
  void enterNoteComposer() => noteCalls++;

  @override
  void exitNoteComposer() => exitComposerCalls++;

  @override
  Future<void> sendNote({
    required String text,
    required int backgroundColor,
    required int textColor,
  }) async {
    sentNotes.add(
        (text: text, backgroundColor: backgroundColor, textColor: textColor));
  }

  @override
  void selectThumbnail(String messageId) => selectedThumbnails.add(messageId);

  @override
  void closePlayback() => closePlaybackCalls++;
}

ConversationSummary _summary({
  String displayName = 'Jordan',
  bool isOtherUserActive = false,
  DateTime? otherUserLastActiveAt,
  DateTime? lastMessageAt,
}) {
  return ConversationSummary(
    conversation: Conversation(id: _convId, createdAt: DateTime(2026, 1, 1)),
    displayName: displayName,
    members: [User(id: 'u-1', avatarColor: 'Rust', createdAt: DateTime(2026, 1, 1))],
    isOtherUserActive: isOtherUserActive,
    otherUserLastActiveAt: otherUserLastActiveAt,
    lastMessageAt: lastMessageAt,
  );
}

// Plain render harness (no router needed).
Widget _render(CameraState state, {ConversationSummary? summary}) {
  return ProviderScope(
    overrides: [
      cameraProvider(_convId).overrideWith(() => _FakeCameraNotifier(state)),
      conversationsProvider.overrideWithBuild(
        (ref, self) => ConversationsState(
          conversations: summary == null ? const [] : [summary],
        ),
      ),
    ],
    child: const MaterialApp(home: CameraScreen(conversationId: _convId)),
  );
}

// Router harness for interactions (back navigation + control taps).
Widget _routed(_FakeCameraNotifier fake, {ConversationSummary? summary}) {
  final router = GoRouter(
    initialLocation: '/camera/$_convId',
    routes: [
      GoRoute(
        path: '/camera/:id',
        builder: (_, s) =>
            CameraScreen(conversationId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/conversations',
        builder: (_, _) => const Text('CONVERSATIONS'),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      cameraProvider(_convId).overrideWith(() => fake),
      conversationsProvider.overrideWithBuild(
        (ref, self) => ConversationsState(
          conversations: summary == null ? const [] : [summary],
        ),
      ),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  group('CameraScreen — 6a shell', () {
    group('layout', () {
      testWidgets('camera view is full-bleed (feed present, no nav bar)',
          (tester) async {
        await tester.pumpWidget(_render(const CameraState(conversationId: _convId)));

        expect(find.byKey(const Key('camera-feed')), findsOneWidget);
        expect(find.byType(BottomNavigationBar), findsNothing);
      });

      testWidgets('renders an (empty) thumbnail strip below the camera',
          (tester) async {
        await tester.pumpWidget(_render(const CameraState(conversationId: _convId)));

        expect(find.byKey(const Key('camera-thumbnails')), findsOneWidget);
        expect(find.byKey(const Key('camera-thumbnail-item')), findsNothing);
      });
    });

    group('header', () {
      testWidgets('shows conversation name, flip button, and back button',
          (tester) async {
        await tester.pumpWidget(_render(
          const CameraState(conversationId: _convId),
          summary: _summary(displayName: 'Jordan'),
        ));

        expect(find.text('Jordan'), findsOneWidget);
        expect(find.byKey(const Key('camera-flip')), findsOneWidget);
        expect(find.byKey(const Key('camera-back')), findsOneWidget);
      });

      testWidgets('shows "active now" when the other user is active',
          (tester) async {
        await tester.pumpWidget(_render(
          const CameraState(conversationId: _convId),
          summary: _summary(isOtherUserActive: true),
        ));

        expect(find.textContaining('active now'), findsOneWidget);
      });

      testWidgets('shows a last-active timestamp when the other user is idle',
          (tester) async {
        await tester.pumpWidget(_render(
          const CameraState(conversationId: _convId),
          summary: _summary(
            isOtherUserActive: false,
            otherUserLastActiveAt:
                DateTime.now().subtract(const Duration(minutes: 5)),
          ),
        ));

        expect(find.textContaining('ago'), findsOneWidget);
      });

      testWidgets(
          'falls back to last message time when there is no last-active '
          '(matches the Conversations list)', (tester) async {
        await tester.pumpWidget(_render(
          const CameraState(conversationId: _convId),
          summary: _summary(
            isOtherUserActive: false,
            otherUserLastActiveAt: null,
            lastMessageAt: DateTime.now().subtract(const Duration(minutes: 10)),
          ),
        ));

        expect(find.textContaining('ago'), findsOneWidget);
      });
    });

    group('controls', () {
      testWidgets('preview mode shows record button and Row 2 actions',
          (tester) async {
        await tester.pumpWidget(_render(
          const CameraState(conversationId: _convId, mode: CameraMode.preview),
        ));

        expect(find.byKey(const Key('camera-record')), findsOneWidget);
        expect(find.byKey(const Key('camera-photo')), findsOneWidget);
        expect(find.byKey(const Key('camera-note')), findsOneWidget);
        expect(find.byKey(const Key('camera-settings')), findsOneWidget);
        expect(find.byKey(const Key('camera-timer')), findsNothing);
      });

      testWidgets('recording mode hides Row 2 and shows the timer',
          (tester) async {
        await tester.pumpWidget(_render(
          const CameraState(conversationId: _convId, mode: CameraMode.recording),
        ));

        // Row 1 (record) + header remain; Row 2 is fully suppressed.
        expect(find.byKey(const Key('camera-record')), findsOneWidget);
        expect(find.byKey(const Key('camera-flip')), findsOneWidget);
        expect(find.byKey(const Key('camera-photo')), findsNothing);
        expect(find.byKey(const Key('camera-note')), findsNothing);
        expect(find.byKey(const Key('camera-settings')), findsNothing);
        expect(find.byKey(const Key('camera-timer')), findsOneWidget);
      });

      testWidgets('recording timer clears the header name (no overlap)',
          (tester) async {
        await tester.pumpWidget(_render(
          const CameraState(conversationId: _convId, mode: CameraMode.recording),
          summary: _summary(displayName: 'Henri'),
        ));

        final nameRect = tester.getRect(find.text('Henri'));
        final timerRect = tester.getRect(find.byKey(const Key('camera-timer')));
        // The timer sits below the header, not on top of the name.
        expect(timerRect.top, greaterThanOrEqualTo(nameRect.bottom));
      });
    });

    group('interactions', () {
      testWidgets('tapping record in preview calls startRecording',
          (tester) async {
        final fake = _FakeCameraNotifier(
            const CameraState(conversationId: _convId, mode: CameraMode.preview));
        await tester.pumpWidget(_routed(fake));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('camera-record')));
        expect(fake.startRecordingCalls, 1);
        expect(fake.stopRecordingCalls, 0);
      });

      testWidgets('tapping record while recording calls stopRecording',
          (tester) async {
        final fake = _FakeCameraNotifier(const CameraState(
            conversationId: _convId, mode: CameraMode.recording));
        await tester.pumpWidget(_routed(fake));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('camera-record')));
        expect(fake.stopRecordingCalls, 1);
        expect(fake.startRecordingCalls, 0);
      });

      testWidgets('tapping flip calls flipCamera', (tester) async {
        final fake = _FakeCameraNotifier(const CameraState(conversationId: _convId));
        await tester.pumpWidget(_routed(fake));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('camera-flip')));
        expect(fake.flipCalls, 1);
      });

      testWidgets('tapping back navigates to Conversations', (tester) async {
        final fake = _FakeCameraNotifier(const CameraState(conversationId: _convId));
        await tester.pumpWidget(_routed(fake));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('camera-back')));
        await tester.pumpAndSettle();

        expect(find.text('CONVERSATIONS'), findsOneWidget);
      });
    });

    // ── Note composer (6b) ───────────────────────────────────────────────────
    group('note composer', () {
      const composing =
          CameraState(conversationId: _convId, mode: CameraMode.noteComposer);

      testWidgets(
          'replaces the camera view with a text canvas — feed and camera '
          'controls gone, header and thumbnail strip stay', (tester) async {
        await tester.pumpWidget(_render(composing, summary: _summary()));

        expect(find.byKey(const Key('note-canvas')), findsOneWidget);
        expect(find.byKey(const Key('note-input')), findsOneWidget);
        expect(find.byKey(const Key('camera-record')), findsNothing);
        expect(find.byKey(const Key('camera-photo')), findsNothing);
        expect(find.byKey(const Key('camera-note')), findsNothing);
        // Header + thumbnails stay visible (spec §5).
        expect(find.byKey(const Key('camera-back')), findsOneWidget);
        expect(find.byKey(const Key('camera-thumbnails')), findsOneWidget);
      });

      testWidgets('shows the two color buttons (camera-icon style) and Send; '
          'palettes stay closed until asked', (tester) async {
        await tester.pumpWidget(_render(composing));

        expect(find.byKey(const Key('note-bg-button')), findsOneWidget);
        expect(find.byKey(const Key('note-text-button')), findsOneWidget);
        expect(find.byKey(const Key('note-send')), findsOneWidget);
        expect(find.byKey(const Key('note-bg-palette')), findsNothing);
        expect(find.byKey(const Key('note-text-palette')), findsNothing);
      });

      testWidgets('tapping the background button opens its palette; picking a '
          'swatch applies it and closes the picker', (tester) async {
        await tester.pumpWidget(_render(composing));

        await tester.tap(find.byKey(const Key('note-bg-button')));
        await tester.pump();
        expect(find.byKey(const Key('note-bg-palette')), findsOneWidget);

        await tester
            .tap(find.byKey(Key('note-bg-swatch-${oliveDark.toARGB32()}')));
        await tester.pump();

        final canvas =
            tester.widget<Container>(find.byKey(const Key('note-canvas')));
        expect((canvas.decoration as BoxDecoration?)?.color ?? canvas.color,
            oliveDark);
        expect(find.byKey(const Key('note-bg-palette')), findsNothing);
      });

      testWidgets('the two pickers are exclusive — opening one closes the '
          'other', (tester) async {
        await tester.pumpWidget(_render(composing));

        await tester.tap(find.byKey(const Key('note-bg-button')));
        await tester.pump();
        expect(find.byKey(const Key('note-bg-palette')), findsOneWidget);

        await tester.tap(find.byKey(const Key('note-text-button')));
        await tester.pump();
        expect(find.byKey(const Key('note-text-palette')), findsOneWidget);
        expect(find.byKey(const Key('note-bg-palette')), findsNothing);
      });

      testWidgets('Send is disabled while a send is in flight — impatient '
          'tapping must not duplicate the note', (tester) async {
        final fake = _FakeCameraNotifier(const CameraState(
          conversationId: _convId,
          mode: CameraMode.noteComposer,
          isLoading: true,
        ));
        await tester.pumpWidget(_routed(fake));
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(const Key('note-input')), 'hi');
        await tester.pump();
        await tester.tap(find.byKey(const Key('note-send')));
        await tester.pumpAndSettle();

        expect(fake.sentNotes, isEmpty);
      });

      testWidgets('typing and tapping Send calls sendNote with the text and '
          'the selected colors', (tester) async {
        final fake = _FakeCameraNotifier(composing);
        await tester.pumpWidget(_routed(fake));
        await tester.pumpAndSettle();

        await tester.enterText(
            find.byKey(const Key('note-input')), 'hello roger');
        await tester.pump(); // let the Send pill enable off the new text
        await tester.tap(find.byKey(const Key('note-send')));
        await tester.pumpAndSettle();

        expect(fake.sentNotes.length, 1);
        expect(fake.sentNotes.single.text, 'hello roger');
        // Defaults: charcoal2 canvas (visible against the charcoal thumbnail
        // strip — Ashe, 7/25), warm white text.
        expect(fake.sentNotes.single.backgroundColor, charcoal2.toARGB32());
        expect(fake.sentNotes.single.textColor, warmWhite.toARGB32());
      });

      testWidgets('Send with an empty canvas does not call sendNote',
          (tester) async {
        final fake = _FakeCameraNotifier(composing);
        await tester.pumpWidget(_routed(fake));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('note-send')));
        await tester.pumpAndSettle();

        expect(fake.sentNotes, isEmpty);
      });

      testWidgets('picking a background swatch recolors the canvas and rides '
          'into sendNote', (tester) async {
        final fake = _FakeCameraNotifier(composing);
        await tester.pumpWidget(_routed(fake));
        await tester.pumpAndSettle();

        // Open the background picker, then pick. Swatches carry keys by
        // palette + ARGB value.
        await tester.tap(find.byKey(const Key('note-bg-button')));
        await tester.pump();
        final oliveSwatch =
            find.byKey(Key('note-bg-swatch-${oliveDark.toARGB32()}'));
        await tester.ensureVisible(oliveSwatch);
        await tester.tap(oliveSwatch);
        await tester.pump();

        final canvas =
            tester.widget<Container>(find.byKey(const Key('note-canvas')));
        expect((canvas.decoration as BoxDecoration?)?.color ?? canvas.color,
            oliveDark);

        await tester.enterText(find.byKey(const Key('note-input')), 'hi');
        await tester.pump(); // let the Send pill enable off the new text
        await tester.tap(find.byKey(const Key('note-send')));
        await tester.pumpAndSettle();

        expect(fake.sentNotes.single.backgroundColor, oliveDark.toARGB32());
      });

      testWidgets('a send failure shows the error on the composer — never a '
          'silent nothing-happened', (tester) async {
        const failed = CameraState(
          conversationId: _convId,
          mode: CameraMode.noteComposer,
          error: "This conversation can't be encrypted yet — a member hasn't "
              'opened roger since encryption was added.',
        );
        await tester.pumpWidget(_render(failed));

        expect(find.byKey(const Key('note-send-error')), findsOneWidget);
        expect(find.textContaining("can't be encrypted yet"), findsOneWidget);
      });

      testWidgets('no error line when there is no error', (tester) async {
        await tester.pumpWidget(_render(composing));

        expect(find.byKey(const Key('note-send-error')), findsNothing);
      });

      testWidgets('back exits the composer instead of leaving the screen',
          (tester) async {
        final fake = _FakeCameraNotifier(composing);
        await tester.pumpWidget(_routed(fake));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('camera-back')));
        await tester.pumpAndSettle();

        expect(fake.exitComposerCalls, 1);
        // Still on the camera screen, not bounced to Conversations.
        expect(find.text('CONVERSATIONS'), findsNothing);
      });

      testWidgets('a subtle counter appears as the text approaches the '
          '1000-char limit', (tester) async {
        await tester.pumpWidget(_render(composing));

        expect(find.byKey(const Key('note-counter')), findsNothing);

        await tester.enterText(
            find.byKey(const Key('note-input')), 'x' * 950);
        await tester.pump();

        expect(find.byKey(const Key('note-counter')), findsOneWidget);
        expect(find.textContaining('950'), findsOneWidget);
      });
    });

    // ── Note viewer + thumbnails (6b) ────────────────────────────────────────
    group('note thumbnails and viewer', () {
      final noteMessage = Message(
        id: 'm-1',
        conversationId: _convId,
        senderId: 'u-other',
        type: MessageType.note,
        encryptedText: 'cipher',
        createdAt: DateTime(2026, 7, 22),
      );
      const notePayload = NotePayload(
        text: 'full-screen note',
        backgroundColor: 0xFF595900,
        textColor: 0xFFE8E600,
      );

      CameraState withNote({CameraMode mode = CameraMode.preview}) =>
          CameraState(
            conversationId: _convId,
            mode: mode,
            thumbnails: [noteMessage],
            notePayloads: const {'m-1': notePayload},
            activeMessage: mode == CameraMode.playback ? noteMessage : null,
          );

      testWidgets('a note renders a thumbnail tinted with its background '
          'color', (tester) async {
        await tester.pumpWidget(_render(withNote()));

        final item = find.byKey(const Key('camera-thumbnail-item'));
        expect(item, findsOneWidget);
        final container = tester.widget<Container>(item);
        expect((container.decoration as BoxDecoration).color,
            const Color(0xFF595900));
      });

      testWidgets('thumbnails carry a hairline border so a charcoal note '
          'never disappears into the strip', (tester) async {
        // A note deliberately composed on the app's own charcoal background.
        final charcoalNote = CameraState(
          conversationId: _convId,
          thumbnails: [noteMessage],
          notePayloads: {
            'm-1': NotePayload(
              text: 'dark note',
              backgroundColor: charcoal.toARGB32(),
              textColor: warmWhite.toARGB32(),
            ),
          },
        );
        await tester.pumpWidget(_render(charcoalNote));

        final container = tester.widget<Container>(
            find.byKey(const Key('camera-thumbnail-item')));
        expect((container.decoration as BoxDecoration).border, isNotNull,
            reason: 'the strip background is charcoal — without a border a '
                'charcoal thumbnail is invisible');
      });

      testWidgets('tapping a thumbnail calls selectThumbnail with its id',
          (tester) async {
        final fake = _FakeCameraNotifier(withNote());
        await tester.pumpWidget(_routed(fake));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('camera-thumbnail-item')));
        expect(fake.selectedThumbnails, ['m-1']);
      });

      testWidgets('playback of a note fills the view with its colors and text',
          (tester) async {
        await tester.pumpWidget(
            _render(withNote(mode: CameraMode.playback)));

        expect(find.byKey(const Key('note-viewer')), findsOneWidget);
        expect(find.text('full-screen note'), findsOneWidget);
        final viewer =
            tester.widget<Container>(find.byKey(const Key('note-viewer')));
        expect((viewer.decoration as BoxDecoration?)?.color ?? viewer.color,
            const Color(0xFF595900));
        // Camera controls are gone while viewing.
        expect(find.byKey(const Key('camera-record')), findsNothing);
      });

      testWidgets('back during playback closes the viewer instead of leaving '
          'the screen', (tester) async {
        final fake = _FakeCameraNotifier(withNote(mode: CameraMode.playback));
        await tester.pumpWidget(_routed(fake));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('camera-back')));
        await tester.pumpAndSettle();

        expect(fake.closePlaybackCalls, 1);
        expect(find.text('CONVERSATIONS'), findsNothing);
      });

      testWidgets('an undecryptable note shows an error state, not silence',
          (tester) async {
        final state = CameraState(
          conversationId: _convId,
          mode: CameraMode.playback,
          thumbnails: [noteMessage],
          // no payload for m-1 — decryption failed
          activeMessage: noteMessage,
        );
        await tester.pumpWidget(_render(state));

        expect(find.byKey(const Key('note-viewer-error')), findsOneWidget);
      });
    });

    // ── Later slices — kept skipped, scoped (testWidgets skip is bool-only,
    // so the slice is named in the description) ──────────────────────────────
    group('deferred', () {
      testWidgets('salmon video call pill between photo and note [step 9]',
          (_) async {},
          skip: true);
      testWidgets('sidebar shows on others\' messages only [step 7]',
          (_) async {},
          skip: true);
      testWidgets('playback speed control during playback [6c]', (_) async {},
          skip: true);
    });
  });
}
