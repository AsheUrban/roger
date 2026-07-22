import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:roger/core/models/conversation.dart';
import 'package:roger/core/models/user.dart';
import 'package:roger/core/theme/colors.dart';
import 'package:roger/features/conversations/conversations_notifier.dart';
import 'package:roger/features/conversations/conversations_screen.dart';
import 'package:roger/features/conversations/conversations_state.dart';

// ---- Test data ----

final _activeUser = User(
  id: 'user-1',
  avatarColor: 'Rust',
  lastActiveAt: DateTime.now().subtract(const Duration(minutes: 3)),
  createdAt: DateTime(2026, 1, 1),
);

final _inactiveUser = User(
  id: 'user-2',
  avatarColor: 'Cornflower',
  lastActiveAt: DateTime.now().subtract(const Duration(hours: 3)),
  createdAt: DateTime(2026, 1, 1),
);

ConversationSummary _makeSummary({
  String id = 'conv-1',
  String displayName = 'Alex',
  List<User>? members,
  List<String>? memberContactNames,
  DateTime? lastMessageAt,
  bool hasUnread = false,
  bool isOtherUserActive = false,
  DateTime? otherUserLastActiveAt,
  int deletedMemberCount = 0,
}) {
  return ConversationSummary(
    conversation: Conversation(
      id: id,
      createdAt: DateTime(2026, 1, 1),
    ),
    displayName: displayName,
    members: members ?? [_inactiveUser],
    memberContactNames: memberContactNames ?? const [],
    lastMessageAt: lastMessageAt ?? DateTime(2026, 4, 8, 10, 0),
    hasUnread: hasUnread,
    isOtherUserActive: isOtherUserActive,
    otherUserLastActiveAt: otherUserLastActiveAt,
    deletedMemberCount: deletedMemberCount,
  );
}

// Renders ConversationsScreen with a pre-seeded state. No router — for
// rendering-only tests.
Widget _buildWithFakeState({required ConversationsState state}) {
  return ProviderScope(
    overrides: [
      conversationsProvider.overrideWithBuild((ref, self) => state),
    ],
    child: const MaterialApp(
      home: ConversationsScreen(),
    ),
  );
}

// Renders ConversationsScreen inside a real GoRouter. For navigation tests.
Widget _buildWithRouter({required ConversationsState state}) {
  final router = GoRouter(
    initialLocation: '/conversations',
    routes: [
      GoRoute(
        path: '/conversations',
        builder: (_, _) => const ConversationsScreen(),
      ),
      GoRoute(
        path: '/camera/:conversationId',
        builder: (_, routeState) => Scaffold(
          body: Text('camera:${routeState.pathParameters['conversationId']}'),
        ),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      conversationsProvider.overrideWithBuild((ref, self) => state),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  group('ConversationsScreen', () {
    group('empty state', () {
      testWidgets('shows prompt to go to Search when no conversations',
          (tester) async {
        await tester.pumpWidget(_buildWithFakeState(
          state: const ConversationsState(),
        ));

        expect(find.textContaining('Search'), findsOneWidget);
      });
    });

    group('loading state', () {
      testWidgets('shows loading spinner while isLoading is true',
          (tester) async {
        await tester.pumpWidget(_buildWithFakeState(
          state: const ConversationsState(isLoading: true),
        ));

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    });

    group('conversation rows', () {
      testWidgets('renders a row for each conversation summary',
          (tester) async {
        await tester.pumpWidget(_buildWithFakeState(
          state: ConversationsState(
            conversations: [
              _makeSummary(id: 'conv-1', displayName: 'Alex'),
              _makeSummary(id: 'conv-2', displayName: 'Sam'),
            ],
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Alex'), findsOneWidget);
        expect(find.text('Sam'), findsOneWidget);
      });

      testWidgets('shows conversation display name in each row',
          (tester) async {
        await tester.pumpWidget(_buildWithFakeState(
          state: ConversationsState(
            conversations: [_makeSummary(displayName: 'Alex')],
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Alex'), findsOneWidget);
      });

      testWidgets('shows last-message timestamp in each row', (tester) async {
        await tester.pumpWidget(_buildWithFakeState(
          state: ConversationsState(
            conversations: [
              _makeSummary(
                lastMessageAt:
                    DateTime.now().subtract(const Duration(hours: 2)),
              ),
            ],
          ),
        ));
        await tester.pumpAndSettle();

        // Timestamp should render in some form — not blank
        expect(find.textContaining('ago'), findsOneWidget);
      });

      testWidgets('truncates long display names with ellipsis — no overflow',
          (tester) async {
        await tester.pumpWidget(_buildWithFakeState(
          state: ConversationsState(
            conversations: [
              _makeSummary(
                displayName:
                    'A very long conversation name that should definitely be truncated with an ellipsis',
              ),
            ],
          ),
        ));
        await tester.pumpAndSettle();

        // Widget renders without overflow error — no RenderFlex exception
        expect(tester.takeException(), isNull);
      });
    });

    group('unread dot', () {
      testWidgets('shows unread dot (warm white) when hasUnread is true',
          (tester) async {
        await tester.pumpWidget(_buildWithFakeState(
          state: ConversationsState(
            conversations: [_makeSummary(hasUnread: true)],
          ),
        ));
        await tester.pumpAndSettle();

        // Unread dot: a small circle with color warmWhite (#FAFAF5)
        final unreadDot = find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).color == warmWhite &&
              (widget.decoration as BoxDecoration).shape == BoxShape.circle,
        );
        expect(unreadDot, findsOneWidget);
      });

      testWidgets('no unread dot when hasUnread is false', (tester) async {
        await tester.pumpWidget(_buildWithFakeState(
          state: ConversationsState(
            conversations: [_makeSummary(hasUnread: false)],
          ),
        ));
        await tester.pumpAndSettle();

        final unreadDot = find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).color == warmWhite &&
              (widget.decoration as BoxDecoration).shape == BoxShape.circle,
        );
        expect(unreadDot, findsNothing);
      });
    });

    group('presence dot', () {
      testWidgets('shows presence dot (olive #E8E600) when other user is active',
          (tester) async {
        await tester.pumpWidget(_buildWithFakeState(
          state: ConversationsState(
            conversations: [_makeSummary(isOtherUserActive: true)],
          ),
        ));
        await tester.pumpAndSettle();

        // Presence dot: small circle with color oliveLight (#E8E600)
        final presenceDot = find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).color == oliveLight &&
              (widget.decoration as BoxDecoration).shape == BoxShape.circle,
        );
        expect(presenceDot, findsOneWidget);
      });

      testWidgets('no presence dot when other user is not active',
          (tester) async {
        await tester.pumpWidget(_buildWithFakeState(
          state: ConversationsState(
            conversations: [_makeSummary(isOtherUserActive: false)],
          ),
        ));
        await tester.pumpAndSettle();

        final presenceDot = find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).color == oliveLight &&
              (widget.decoration as BoxDecoration).shape == BoxShape.circle,
        );
        expect(presenceDot, findsNothing);
      });
    });

    group('deleted user', () {
      // Finder for a warm-white circle avatar (spec §4 deleted-user treatment).
      final warmWhiteCircle = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color == warmWhite &&
            (w.decoration as BoxDecoration).shape == BoxShape.circle,
      );
      final oliveCircle = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color == oliveLight &&
            (w.decoration as BoxDecoration).shape == BoxShape.circle,
      );

      testWidgets(
          '1:1 with a deleted other party shows the warm-white circle + '
          'charcoal dash avatar and the name "Deleted user"', (tester) async {
        await tester.pumpWidget(_buildWithFakeState(
          state: ConversationsState(
            conversations: [
              _makeSummary(
                displayName: 'Deleted user',
                members: const [],
                deletedMemberCount: 1,
                isOtherUserActive: false,
              ),
            ],
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Deleted user'), findsOneWidget);
        // The charcoal dash inside the avatar.
        expect(find.byIcon(Icons.remove), findsOneWidget);
        // A warm-white circle avatar (no unread dot in this summary).
        expect(warmWhiteCircle, findsOneWidget);
        // Never the generic "?" fallback.
        expect(find.text('?'), findsNothing);
      });

      testWidgets('1:1 deleted other party never shows a presence dot',
          (tester) async {
        await tester.pumpWidget(_buildWithFakeState(
          state: ConversationsState(
            conversations: [
              _makeSummary(
                displayName: 'Deleted user',
                members: const [],
                deletedMemberCount: 1,
                isOtherUserActive: false,
              ),
            ],
          ),
        ));
        await tester.pumpAndSettle();

        expect(oliveCircle, findsNothing);
      });

      testWidgets(
          'group with one deleted member shows the deleted treatment for that '
          'slot, renders active members normally, and does not crash',
          (tester) async {
        await tester.pumpWidget(_buildWithFakeState(
          state: ConversationsState(
            conversations: [
              _makeSummary(
                displayName: 'Alex, Deleted user',
                members: [_activeUser],
                memberContactNames: const ['Alex'],
                deletedMemberCount: 1,
              ),
            ],
          ),
        ));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        // The deleted member's slot renders the dash.
        expect(find.byIcon(Icons.remove), findsOneWidget);
        // The active member renders their initial normally.
        expect(find.text('A'), findsOneWidget);
      });
    });

    group('last-active timestamp', () {
      testWidgets('shows "active Xm ago" format for recent activity',
          (tester) async {
        await tester.pumpWidget(_buildWithFakeState(
          state: ConversationsState(
            conversations: [
              _makeSummary(
                isOtherUserActive: false,
                otherUserLastActiveAt:
                    DateTime.now().subtract(const Duration(minutes: 5)),
              ),
            ],
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.textContaining('active 5m ago'), findsOneWidget);
      });

      testWidgets('shows "active Xh ago" for activity within today',
          (tester) async {
        await tester.pumpWidget(_buildWithFakeState(
          state: ConversationsState(
            conversations: [
              _makeSummary(
                isOtherUserActive: false,
                otherUserLastActiveAt:
                    DateTime.now().subtract(const Duration(hours: 2)),
              ),
            ],
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.textContaining('active 2h ago'), findsOneWidget);
      });

      testWidgets('shows "active yesterday" for previous day', (tester) async {
        await tester.pumpWidget(_buildWithFakeState(
          state: ConversationsState(
            conversations: [
              _makeSummary(
                isOtherUserActive: false,
                otherUserLastActiveAt:
                    DateTime.now().subtract(const Duration(hours: 25)),
              ),
            ],
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.textContaining('active yesterday'), findsOneWidget);
      });

      testWidgets('shows no last-active text when other user is active now',
          (tester) async {
        await tester.pumpWidget(_buildWithFakeState(
          state: ConversationsState(
            conversations: [_makeSummary(isOtherUserActive: true)],
          ),
        ));
        await tester.pumpAndSettle();

        // When active, presence dot shows — no last-active timestamp text
        expect(find.textContaining('ago'), findsNothing);
        expect(find.textContaining('yesterday'), findsNothing);
      });
    });

    group('group conversations', () {
      testWidgets('group conversation shows multiple overlapping mini-avatars',
          (tester) async {
        // 2 other members = group conversation
        await tester.pumpWidget(_buildWithFakeState(
          state: ConversationsState(
            conversations: [
              _makeSummary(
                members: [_activeUser, _inactiveUser],
              ),
            ],
          ),
        ));
        await tester.pumpAndSettle();

        // Group avatar is a Stack with multiple avatar widgets
        // Verify by finding more than one avatar circle in the row
        final avatarCircles = find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).shape == BoxShape.circle,
        );
        // At least 2 avatar circles for a group (one per member)
        expect(avatarCircles, findsAtLeastNWidgets(2));
      });

      testWidgets('1:1 conversation shows a single avatar', (tester) async {
        await tester.pumpWidget(_buildWithFakeState(
          state: ConversationsState(
            conversations: [
              _makeSummary(members: [_inactiveUser]),
            ],
          ),
        ));
        await tester.pumpAndSettle();

        // Single member = 1:1 = only one avatar circle
        final avatarCircles = find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).shape == BoxShape.circle,
        );
        expect(avatarCircles, findsOneWidget);
      });
    });

    group('navigation', () {
      testWidgets('tapping a row navigates to /camera/:conversationId',
          (tester) async {
        await tester.pumpWidget(_buildWithRouter(
          state: ConversationsState(
            conversations: [_makeSummary(id: 'conv-1', displayName: 'Alex')],
          ),
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Alex'));
        await tester.pumpAndSettle();

        expect(find.text('camera:conv-1'), findsOneWidget);
      });
    });

    group('bulk-leave selection mode', () {
      ConversationsState twoConvos({bool selectionMode = false, Set<String>? selected}) =>
          ConversationsState(
            conversations: [
              _makeSummary(id: 'conv-1', displayName: 'Alpha'),
              _makeSummary(id: 'conv-2', displayName: 'Beta'),
            ],
            isSelectionMode: selectionMode,
            selectedIds: selected ?? const {},
          );

      testWidgets('a select toggle is shown, and no leave bar until in mode',
          (tester) async {
        await tester.pumpWidget(_buildWithFakeState(state: twoConvos()));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('select-mode-toggle')), findsOneWidget);
        expect(find.byKey(const Key('leave-selected-bar')), findsNothing);
      });

      testWidgets('selection mode shows the leave bar with the selected count',
          (tester) async {
        await tester.pumpWidget(_buildWithFakeState(
          state: twoConvos(selectionMode: true, selected: {'conv-1'}),
        ));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('leave-selected-bar')), findsOneWidget);
        expect(find.textContaining('1'), findsWidgets);
      });

      testWidgets('tapping a row in selection mode toggles it instead of '
          'navigating', (tester) async {
        final notifier = _RecordingConversationsNotifier(
            twoConvos(selectionMode: true));
        await tester.pumpWidget(_buildWithNotifier(notifier));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Alpha'));
        await tester.pumpAndSettle();

        expect(notifier.toggled, ['conv-1']);
        // Did not navigate to Camera — still on the list.
        expect(find.textContaining('camera:'), findsNothing);
      });

      testWidgets('Leave asks for confirmation, then calls leaveSelected',
          (tester) async {
        final notifier = _RecordingConversationsNotifier(
            twoConvos(selectionMode: true, selected: {'conv-1', 'conv-2'}));
        await tester.pumpWidget(_buildWithNotifier(notifier));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('leave-selected-button')));
        await tester.pumpAndSettle();
        // Confirmation dialog before any leave (spec §9).
        expect(notifier.leftSelected, 0);
        await tester.tap(find.byKey(const Key('confirm-leave')));
        await tester.pumpAndSettle();

        expect(notifier.leftSelected, 1);
      });
    });

    group('nav bar', () {
      test('nav bar visible with Conversations tab active',
          skip: 'Integration test — requires full shell route', () {});
    });
  });
}

// Records notifier interactions for selection-mode interaction tests.
class _RecordingConversationsNotifier extends ConversationsNotifier {
  final ConversationsState _state;
  final List<String> toggled = [];
  int leftSelected = 0;
  _RecordingConversationsNotifier(this._state);

  @override
  ConversationsState build() => _state;

  @override
  void toggleSelected(String id) => toggled.add(id);

  @override
  Future<void> leaveSelected() async => leftSelected++;
}

Widget _buildWithNotifier(_RecordingConversationsNotifier notifier) {
  final router = GoRouter(
    initialLocation: '/conversations',
    routes: [
      GoRoute(
        path: '/conversations',
        builder: (_, _) => const ConversationsScreen(),
      ),
      GoRoute(
        path: '/camera/:conversationId',
        builder: (_, s) => Text('camera:${s.pathParameters['conversationId']}'),
      ),
    ],
  );
  return ProviderScope(
    overrides: [conversationsProvider.overrideWith(() => notifier)],
    child: MaterialApp.router(routerConfig: router),
  );
}
