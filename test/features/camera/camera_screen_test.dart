import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:roger/core/models/conversation.dart';
import 'package:roger/core/models/user.dart';
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
      testWidgets('note composer replaces camera with a text canvas [6b]',
          (_) async {},
          skip: true);
    });
  });
}
