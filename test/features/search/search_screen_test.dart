import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:roger/core/models/user.dart';
import 'package:roger/core/providers.dart';
import 'package:roger/core/services/contacts_service.dart';
import 'package:roger/features/search/search_notifier.dart';
import 'package:roger/features/search/search_screen.dart';
import 'package:roger/features/search/search_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

class MockContactsService extends Mock implements ContactsService {}
class MockSupabaseClient extends Mock implements SupabaseClient {}

final _rogerUser = User(
  id: 'user-1',
  phoneNumber: '+15551111111',
  avatarColor: 'Rust',
  lastActiveAt: DateTime.now().subtract(const Duration(minutes: 2)),
  createdAt: DateTime(2026, 1, 1),
);

// For rendering-only tests where we don't need real notifier behavior
Widget _buildWithFakeState({required SearchState state}) {
  return ProviderScope(
    overrides: [
      searchProvider.overrideWith(() => _FakeSearchNotifier(state)),
    ],
    child: const MaterialApp(
      home: SearchScreen(),
    ),
  );
}

class _FakeSearchNotifier extends SearchNotifier {
  final SearchState _initialState;
  final List<String?> createGroupCalls = [];
  int refreshContactsCalls = 0;
  Future<void>? _refreshFuture;
  _FakeSearchNotifier(this._initialState);
  @override
  SearchState build() => _initialState;
  @override
  Future<String> createGroupConversation({String? name}) async {
    createGroupCalls.add(name);
    return 'fake-conv-id';
  }

  @override
  Future<void> refreshContacts() async {
    refreshContactsCalls++;
    if (_refreshFuture != null) await _refreshFuture;
  }

  /// Test helper: hold the refresh open until [completer] completes.
  /// Lets a test assert that the loading indicator appears during refresh.
  void holdRefreshUntil(Future<void> future) {
    _refreshFuture = future;
  }
}

// For interaction tests — real notifier, mocked services
Widget _buildWithMockedServices({
  required MockContactsService contactsService,
}) {
  return ProviderScope(
    overrides: [
      contactsServiceProvider.overrideWithValue(contactsService),
      supabaseClientProvider.overrideWithValue(MockSupabaseClient()),
      currentUserIdProvider.overrideWithValue('current-user-id'),
    ],
    child: const MaterialApp(
      home: SearchScreen(),
    ),
  );
}

// For group-name-prompt tests — fake notifier in group mode with a router
// stubbed for the post-create navigation to /camera/:id.
Widget _buildWithFakeNotifier(_FakeSearchNotifier notifier) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SearchScreen()),
      GoRoute(
        path: '/camera/:id',
        builder: (_, _) => const SizedBox.shrink(),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      searchProvider.overrideWith(() => notifier),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  group('SearchScreen', () {
    group('rendering', () {
      testWidgets('renders "Find people" header', (tester) async {
        await tester.pumpWidget(_buildWithFakeState(
          state: const SearchState(hasContactsPermission: true),
        ));

        expect(find.text('Find people'), findsOneWidget);
      });

      testWidgets('renders search bar with "Search contacts" placeholder',
          (tester) async {
        await tester.pumpWidget(_buildWithFakeState(
          state: const SearchState(hasContactsPermission: true),
        ));

        expect(find.text('Search contacts'), findsOneWidget);
      });

      testWidgets('roger users show Chat pill', (tester) async {
        await tester.pumpWidget(_buildWithFakeState(
          state: SearchState(
            hasContactsPermission: true,
            results: [
              SearchResult(
                rogerUser: _rogerUser,
                contactName: 'Jordan B',
                phoneNumber: '+15551111111',
                isOnRoger: true,
              ),
            ],
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Chat'), findsOneWidget);
      });

      testWidgets('non-roger contacts show Invite text', (tester) async {
        await tester.pumpWidget(_buildWithFakeState(
          state: const SearchState(
            hasContactsPermission: true,
            results: [
              SearchResult(
                contactName: 'Dana R',
                phoneNumber: '+15553333333',
                isOnRoger: false,
              ),
            ],
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.textContaining('Invite'), findsOneWidget);
      });

      testWidgets('already-invited contacts show Pending text',
          (tester) async {
        await tester.pumpWidget(_buildWithFakeState(
          state: const SearchState(
            hasContactsPermission: true,
            results: [
              SearchResult(
                contactName: 'Sam M',
                phoneNumber: '+15554444444',
                isOnRoger: false,
                hasPendingInvite: true,
              ),
            ],
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Pending'), findsOneWidget);
      });

      testWidgets('no permission shows neutral empty state', (tester) async {
        await tester.pumpWidget(_buildWithFakeState(
          state: const SearchState(hasContactsPermission: false),
        ));

        expect(find.text('Your contacts will appear here.'), findsOneWidget);
      });

      testWidgets('empty results with query shows no results message',
          (tester) async {
        await tester.pumpWidget(_buildWithFakeState(
          state: const SearchState(
            hasContactsPermission: true,
            query: 'zzzzz',
          ),
        ));

        expect(find.text('No results for "zzzzz"'), findsOneWidget);
      });

      testWidgets('last-active timestamp shown for roger contacts',
          (tester) async {
        await tester.pumpWidget(_buildWithFakeState(
          state: SearchState(
            hasContactsPermission: true,
            results: [
              SearchResult(
                rogerUser: _rogerUser,
                contactName: 'Jordan B',
                phoneNumber: '+15551111111',
                isOnRoger: true,
              ),
            ],
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.textContaining('active'), findsOneWidget);
      });
    });

    group('interactions', () {
      late MockContactsService contactsService;

      setUp(() {
        contactsService = MockContactsService();
        when(() => contactsService.hasPermission())
            .thenAnswer((_) async => false);
        when(() => contactsService.cachedContacts).thenReturn([]);
        when(() => contactsService.cachedRogerUsers).thenReturn([]);
      });

      testWidgets(
          'tapping search bar without permission calls requestContactsPermission',
          (tester) async {
        when(() => contactsService.requestPermission())
            .thenAnswer((_) async => false);

        await tester.pumpWidget(
          _buildWithMockedServices(contactsService: contactsService),
        );
        await tester.pumpAndSettle();

        // Tap the search bar area
        await tester.tap(find.text('Search contacts'));
        await tester.pumpAndSettle();

        verify(() => contactsService.requestPermission()).called(1);
      });

      testWidgets(
          'granting permission via search bar tap loads contacts',
          (tester) async {
        when(() => contactsService.requestPermission())
            .thenAnswer((_) async => true);
        when(() => contactsService.refreshBatchCheck())
            .thenAnswer((_) async {});

        await tester.pumpWidget(
          _buildWithMockedServices(contactsService: contactsService),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Search contacts'));
        await tester.pumpAndSettle();

        verify(() => contactsService.requestPermission()).called(1);
        verify(() => contactsService.refreshBatchCheck()).called(1);
      });
    });

    testWidgets('nav bar visible with Search tab', (tester) async {
      // Integration test — _RogerShell only mounts under the full router,
      // not in SearchScreen widget tests in isolation.
    }, skip: true);

    group('group name prompt', () {
      // Initial state used by every test in this group: in group mode with
      // two selected users — the minimum required for the Create button to
      // be enabled.
      const groupModeState = SearchState(
        hasContactsPermission: true,
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

      testWidgets('sheet shows title, text field, and Create button',
          (tester) async {
        final notifier = _FakeSearchNotifier(groupModeState);
        await tester.pumpWidget(_buildWithFakeNotifier(notifier));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('group-create-button')));
        await tester.pumpAndSettle();

        expect(find.text('Group name (optional)'), findsOneWidget);
        expect(find.byKey(const Key('group-name-field')), findsOneWidget);
        expect(find.byKey(const Key('group-name-confirm')), findsOneWidget);
      });

      testWidgets(
          'submitting a name calls createGroupConversation with that name',
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

      testWidgets('submitting whitespace-padded name trims before passing',
          (tester) async {
        final notifier = _FakeSearchNotifier(groupModeState);
        await tester.pumpWidget(_buildWithFakeNotifier(notifier));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('group-create-button')));
        await tester.pumpAndSettle();

        await tester.enterText(
            find.byKey(const Key('group-name-field')), '  Game Night  ');
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

      testWidgets(
          'submitting whitespace-only calls createGroupConversation with null',
          (tester) async {
        final notifier = _FakeSearchNotifier(groupModeState);
        await tester.pumpWidget(_buildWithFakeNotifier(notifier));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('group-create-button')));
        await tester.pumpAndSettle();

        await tester.enterText(
            find.byKey(const Key('group-name-field')), '     ');
        await tester.tap(find.byKey(const Key('group-name-confirm')));
        await tester.pumpAndSettle();

        expect(notifier.createGroupCalls, [null]);
      });

      testWidgets('dismissing the sheet does not call createGroupConversation',
          (tester) async {
        final notifier = _FakeSearchNotifier(groupModeState);
        await tester.pumpWidget(_buildWithFakeNotifier(notifier));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('group-create-button')));
        await tester.pumpAndSettle();

        // Tap the scrim above the sheet to dismiss it.
        await tester.tapAt(const Offset(20, 20));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('group-name-sheet')), findsNothing);
        expect(notifier.createGroupCalls, isEmpty);
      });

      testWidgets('text field caps input at 50 characters', (tester) async {
        final notifier = _FakeSearchNotifier(groupModeState);
        await tester.pumpWidget(_buildWithFakeNotifier(notifier));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('group-create-button')));
        await tester.pumpAndSettle();

        // 60-character string — 10 over the cap.
        final tooLong = 'a' * 60;
        await tester.enterText(
            find.byKey(const Key('group-name-field')), tooLong);
        await tester.tap(find.byKey(const Key('group-name-confirm')));
        await tester.pumpAndSettle();

        expect(notifier.createGroupCalls, ['a' * 50]);
      });
    });

    group('pull-to-refresh', () {
      // A SearchState with permission granted and at least one rendered row,
      // so the RefreshIndicator has scrollable content underneath it.
      final readyState = SearchState(
        hasContactsPermission: true,
        results: [
          SearchResult(
            rogerUser: _rogerUser,
            contactName: 'Henrietta',
            phoneNumber: '+15550001000',
            isOnRoger: true,
          ),
        ],
      );

      testWidgets('pull-to-refresh gesture calls refreshContacts',
          (tester) async {
        final notifier = _FakeSearchNotifier(readyState);
        await tester.pumpWidget(_buildWithFakeNotifier(notifier));
        await tester.pumpAndSettle();

        // Drag the list down to trigger RefreshIndicator
        await tester.fling(
            find.byKey(const Key('search-results-list')),
            const Offset(0, 400),
            1000);
        await tester.pumpAndSettle();

        expect(notifier.refreshContactsCalls, 1);
      });

      testWidgets('RefreshIndicator wraps the contact list',
          (tester) async {
        final notifier = _FakeSearchNotifier(readyState);
        await tester.pumpWidget(_buildWithFakeNotifier(notifier));
        await tester.pumpAndSettle();

        expect(find.byType(RefreshIndicator), findsOneWidget);
      });
    });
  });
}

