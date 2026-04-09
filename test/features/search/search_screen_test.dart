import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
  email: 'jordan@example.com',
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
  _FakeSearchNotifier(this._initialState);
  @override
  SearchState build() => _initialState;
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
      authStateChangesProvider.overrideWith(
        (ref) => const Stream<AuthState>.empty(),
      ),
    ],
    child: const MaterialApp(
      home: SearchScreen(),
    ),
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
      // Nav bar is part of _RogerShell, not SearchScreen.
      // Test via integration test with full router.
    }, skip: true);
  });
}
