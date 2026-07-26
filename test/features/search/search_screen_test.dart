import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:roger/features/search/search_notifier.dart';
import 'package:roger/features/search/search_screen.dart';
import 'package:roger/features/search/search_state.dart';

// A fake notifier that serves a fixed state and records group creation.
class _FakeSearchNotifier extends SearchNotifier {
  final SearchState _initialState;
  final List<String?> createGroupCalls = [];
  final List<String> toggledContacts = [];
  int addSomeoneCalls = 0;
  _FakeSearchNotifier(this._initialState);

  @override
  SearchState build() => _initialState;

  int inviteCalls = 0;

  @override
  Future<void> addSomeone() async {
    addSomeoneCalls++;
  }

  @override
  Future<void> invite() async {
    inviteCalls++;
  }

  @override
  void toggleContactSelection(String userId) {
    toggledContacts.add(userId);
  }

  @override
  Future<String?> createGroupConversation({String? name}) async {
    createGroupCalls.add(name);
    return 'fake-conv-id';
  }
}

Widget _buildWithFakeState({required SearchState state}) {
  return ProviderScope(
    overrides: [
      searchProvider.overrideWith(() => _FakeSearchNotifier(state)),
    ],
    child: const MaterialApp(home: SearchScreen()),
  );
}

Widget _buildWithFakeNotifier(_FakeSearchNotifier notifier) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SearchScreen()),
      GoRoute(path: '/camera/:id', builder: (_, _) => const SizedBox.shrink()),
      GoRoute(
          path: '/conversations',
          builder: (_, _) => const Text('CONVERSATIONS')),
    ],
  );
  return ProviderScope(
    overrides: [searchProvider.overrideWith(() => notifier)],
    child: MaterialApp.router(routerConfig: router),
  );
}

const _jordan = AddedContactResult(
  userId: 'u-1',
  contactName: 'Jordan',
  avatarColor: 'Rust',
);

void main() {
  group('SearchScreen', () {
    group('rendering', () {
      testWidgets('renders "Find people" header and search bar', (tester) async {
        await tester.pumpWidget(_buildWithFakeState(state: const SearchState()));

        expect(find.text('Find people'), findsOneWidget);
        expect(find.text('Search people you’ve added'), findsOneWidget);
      });

      testWidgets('shows the "Add someone" affordance', (tester) async {
        await tester.pumpWidget(_buildWithFakeState(state: const SearchState()));

        expect(find.byKey(const Key('add-someone')), findsOneWidget);
        expect(find.text('Add someone'), findsOneWidget);
      });

      testWidgets('added contacts show a Chat pill', (tester) async {
        await tester.pumpWidget(_buildWithFakeState(
          state: const SearchState(results: [_jordan]),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Jordan'), findsOneWidget);
        expect(find.text('Chat'), findsOneWidget);
      });

      testWidgets('empty state prompts to add someone', (tester) async {
        await tester.pumpWidget(_buildWithFakeState(state: const SearchState()));

        expect(
            find.text('Add someone to start a conversation.'), findsOneWidget);
      });

      testWidgets('a not-on-roger pick shows a notice', (tester) async {
        await tester.pumpWidget(_buildWithFakeState(
          state: const SearchState(notOnRogerName: 'Dana'),
        ));

        expect(find.textContaining('Dana'), findsWidgets);
        expect(find.textContaining('isn’t on roger yet'), findsOneWidget);
      });

      testWidgets('empty results with a query shows a no-results message',
          (tester) async {
        await tester.pumpWidget(_buildWithFakeState(
          state: const SearchState(query: 'zzz'),
        ));

        expect(find.text('No results for "zzz"'), findsOneWidget);
      });
    });

    group('interactions', () {
      testWidgets('tapping "Add someone" calls addSomeone', (tester) async {
        final notifier = _FakeSearchNotifier(const SearchState());
        await tester.pumpWidget(_buildWithFakeNotifier(notifier));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('add-someone')));
        await tester.pumpAndSettle();

        expect(notifier.addSomeoneCalls, 1);
      });
    });

    group('group name prompt', () {
      const groupModeState = SearchState(
        isGroupMode: true,
        selectedUserIds: ['u-1', 'u-2'],
      );

      testWidgets('tapping Create with 2+ selected opens the name sheet',
          (tester) async {
        final notifier = _FakeSearchNotifier(groupModeState);
        await tester.pumpWidget(_buildWithFakeNotifier(notifier));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('group-create-button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('group-name-sheet')), findsOneWidget);
        expect(notifier.createGroupCalls, isEmpty);
      });

      testWidgets('submitting a name calls createGroupConversation with it',
          (tester) async {
        final notifier = _FakeSearchNotifier(groupModeState);
        await tester.pumpWidget(_buildWithFakeNotifier(notifier));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('group-create-button')));
        await tester.pumpAndSettle();
        await tester.enterText(
            find.byKey(const Key('group-name-field')), 'Game Night');
        await tester.tap(find.byKey(const Key('group-name-confirm')));
        await tester.pumpAndSettle();

        expect(notifier.createGroupCalls, ['Game Night']);
      });

      testWidgets('submitting empty calls createGroupConversation with null',
          (tester) async {
        final notifier = _FakeSearchNotifier(groupModeState);
        await tester.pumpWidget(_buildWithFakeNotifier(notifier));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('group-create-button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('group-name-confirm')));
        await tester.pumpAndSettle();

        expect(notifier.createGroupCalls, [null]);
      });
    });

    group('group mode cancel returns to its origin', () {
      testWidgets('entered from Conversations → Cancel navigates back there',
          (tester) async {
        final notifier = _FakeSearchNotifier(const SearchState(
          isGroupMode: true,
          groupModeFromConversations: true,
        ));
        await tester.pumpWidget(_buildWithFakeNotifier(notifier));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(find.text('CONVERSATIONS'), findsOneWidget);
      });

      testWidgets('entered from within Search → Cancel stays on Search',
          (tester) async {
        final notifier =
            _FakeSearchNotifier(const SearchState(isGroupMode: true));
        await tester.pumpWidget(_buildWithFakeNotifier(notifier));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(find.text('CONVERSATIONS'), findsNothing);
        expect(find.text('Find people'), findsOneWidget);
      });
    });

    group('group eligibility (spec §9 — replied 1:1 required)', () {
      const eligible = AddedContactResult(
        userId: 'u-ok',
        contactName: 'Casey',
        avatarColor: 'Olive',
      );
      const ineligible = AddedContactResult(
        userId: 'u-silent',
        contactName: 'Jordan',
        avatarColor: 'Rust',
      );
      const groupState = SearchState(
        isGroupMode: true,
        results: [eligible, ineligible],
        repliedUserIds: {'u-ok'},
      );

      testWidgets('an un-replied contact renders dimmed with the hint; a '
          'replied one renders normally', (tester) async {
        await tester.pumpWidget(_buildWithFakeState(state: groupState));
        await tester.pumpAndSettle();

        expect(
            find.byKey(const Key('ineligible-hint-u-silent')), findsOneWidget);
        // Ashe's copy, locked verbatim (LOG_7_25) — name templated in.
        expect(
          find.text('Start a 1:1 chat with Jordan — once they reply, '
              'you can add them to a group.'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('ineligible-hint-u-ok')), findsNothing);
      });

      testWidgets('tapping an un-replied contact does not toggle selection; '
          'tapping a replied one does', (tester) async {
        final notifier = _FakeSearchNotifier(groupState);
        await tester.pumpWidget(_buildWithFakeNotifier(notifier));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Jordan'));
        await tester.pumpAndSettle();
        expect(notifier.toggledContacts, isEmpty);

        await tester.tap(find.text('Casey'));
        await tester.pumpAndSettle();
        expect(notifier.toggledContacts, ['u-ok']);
      });
    });

    group('invite', () {
      testWidgets('a not-on-roger pick shows an Invite action', (tester) async {
        await tester.pumpWidget(_buildWithFakeState(
          state: const SearchState(notOnRogerName: 'Dana'),
        ));

        expect(find.byKey(const Key('invite-button')), findsOneWidget);
      });

      testWidgets('tapping Invite calls invite()', (tester) async {
        final notifier =
            _FakeSearchNotifier(const SearchState(notOnRogerName: 'Dana'));
        await tester.pumpWidget(_buildWithFakeNotifier(notifier));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('invite-button')));
        await tester.pumpAndSettle();

        expect(notifier.inviteCalls, 1);
      });

      testWidgets('an invited pick shows "Invited" and no button',
          (tester) async {
        await tester.pumpWidget(_buildWithFakeState(
          state: const SearchState(
              notOnRogerName: 'Dana', notOnRogerInvited: true),
        ));

        expect(find.byKey(const Key('invite-button')), findsNothing);
        expect(find.text('Invited'), findsOneWidget);
      });
    });
  });
}
