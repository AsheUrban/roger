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

class _FakeConversationsNotifier extends ConversationsNotifier {
  final ConversationsState _seed;
  _FakeConversationsNotifier(this._seed);

  @override
  ConversationsState build() => _seed;
}

// ---- Test data ----

final _activeUser = User(
  id: 'user-1',
  phoneNumber: '+15551111111',
  avatarColor: 'Rust',
  lastActiveAt: DateTime.now().subtract(const Duration(minutes: 3)),
  createdAt: DateTime(2026, 1, 1),
);

final _inactiveUser = User(
  id: 'user-2',
  phoneNumber: '+15552222222',
  avatarColor: 'Cornflower',
  lastActiveAt: DateTime.now().subtract(const Duration(hours: 3)),
  createdAt: DateTime(2026, 1, 1),
);

ConversationSummary _makeSummary({
  String id = 'conv-1',
  String displayName = 'Alex',
  List<User>? members,
  DateTime? lastMessageAt,
  bool hasUnread = false,
  bool isOtherUserActive = false,
  DateTime? otherUserLastActiveAt,
}) {
  return ConversationSummary(
    conversation: Conversation(
      id: id,
      createdAt: DateTime(2026, 1, 1),
    ),
    displayName: displayName,
    members: members ?? [_inactiveUser],
    lastMessageAt: lastMessageAt ?? DateTime(2026, 4, 8, 10, 0),
    hasUnread: hasUnread,
    isOtherUserActive: isOtherUserActive,
    otherUserLastActiveAt: otherUserLastActiveAt,
  );
}

// Renders ConversationsScreen with a pre-seeded state. No router — for
// rendering-only tests.
Widget _buildWithFakeState({required ConversationsState state}) {
  return ProviderScope(
    overrides: [
      conversationsProvider.overrideWith(
        () => _FakeConversationsNotifier(state),
      ),
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
        builder: (_, __) => const ConversationsScreen(),
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
      conversationsProvider.overrideWith(
        () => _FakeConversationsNotifier(state),
      ),
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

    group('nav bar', () {
      test('nav bar visible with Conversations tab active',
          skip: 'Integration test — requires full shell route', () {});
    });
  });
}
