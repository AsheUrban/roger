import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:roger/core/models/user.dart';
import 'package:roger/core/providers.dart';
import 'package:roger/core/services/contacts_service.dart';
import 'package:roger/features/search/search_notifier.dart';
import 'package:roger/features/search/search_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

class MockContactsService extends Mock implements ContactsService {}
class MockSupabaseClient extends Mock implements SupabaseClient {}

final _testUser1 = User(
  id: 'user-1',
  email: 'jordan@example.com',
  phoneNumber: '+15551111111',
  avatarColor: 'Rust',
  createdAt: DateTime(2026, 1, 1),
);

final _testUser2 = User(
  id: 'user-2',
  email: 'casey@example.com',
  phoneNumber: '+15552222222',
  avatarColor: 'Cornflower',
  createdAt: DateTime(2026, 1, 1),
);

void main() {
  late MockContactsService contactsService;
  late ProviderContainer container;
  late SearchNotifier notifier;

  setUp(() {
    contactsService = MockContactsService();

    // Default: no permission, empty caches
    when(() => contactsService.hasPermission())
        .thenAnswer((_) async => false);
    when(() => contactsService.cachedContacts).thenReturn([]);
    when(() => contactsService.cachedRogerUsers).thenReturn([]);

    container = ProviderContainer(overrides: [
      contactsServiceProvider.overrideWithValue(contactsService),
      supabaseClientProvider.overrideWithValue(MockSupabaseClient()),
      currentUserIdProvider.overrideWithValue('current-user-id'),
      authStateChangesProvider.overrideWith(
        (ref) => const Stream<AuthState>.empty(),
      ),
    ]);

    notifier = container.read(searchProvider.notifier);
  });

  tearDown(() {
    container.dispose();
  });

  group('SearchNotifier', () {
    group('initial state', () {
      test('starts with empty results and no permission', () {
        final state = container.read(searchProvider);
        expect(state.results, isEmpty);
        expect(state.hasContactsPermission, false);
        expect(state.query, '');
        expect(state.isLoading, false);
        expect(state.error, isNull);
      });
    });

    group('contact loading', () {
      test('loadInitialContacts runs refreshBatchCheck and populates results',
          () async {
        when(() => contactsService.refreshBatchCheck())
            .thenAnswer((_) async {});
        when(() => contactsService.cachedContacts).thenReturn([
          (name: 'Jordan B', phoneNumber: '+15551111111'),
          (name: 'Dana R', phoneNumber: '+15553333333'),
        ]);
        when(() => contactsService.cachedRogerUsers)
            .thenReturn([_testUser1]);

        await notifier.loadInitialContacts();

        verify(() => contactsService.refreshBatchCheck()).called(1);
        final state = container.read(searchProvider);
        expect(state.results.length, 2);
        expect(state.isLoading, false);
      });

      test('results sorted alphabetically by contact name', () async {
        when(() => contactsService.refreshBatchCheck())
            .thenAnswer((_) async {});
        when(() => contactsService.cachedContacts).thenReturn([
          (name: 'Zara', phoneNumber: '+15559999999'),
          (name: 'Alice', phoneNumber: '+15558888888'),
          (name: 'Morgan', phoneNumber: '+15557777777'),
        ]);
        when(() => contactsService.cachedRogerUsers).thenReturn([]);

        await notifier.loadInitialContacts();

        final state = container.read(searchProvider);
        final names = state.results.map((r) => r.contactName).toList();
        expect(names, ['Alice', 'Morgan', 'Zara']);
      });

      test('roger users show isOnRoger true', () async {
        when(() => contactsService.refreshBatchCheck())
            .thenAnswer((_) async {});
        when(() => contactsService.cachedContacts).thenReturn([
          (name: 'Jordan B', phoneNumber: '+15551111111'),
        ]);
        when(() => contactsService.cachedRogerUsers)
            .thenReturn([_testUser1]);

        await notifier.loadInitialContacts();

        final state = container.read(searchProvider);
        final jordan = state.results.first;
        expect(jordan.isOnRoger, true);
        expect(jordan.rogerUser, isNotNull);
        expect(jordan.rogerUser!.id, 'user-1');
      });

      test('non-roger contacts show isOnRoger false', () async {
        when(() => contactsService.refreshBatchCheck())
            .thenAnswer((_) async {});
        when(() => contactsService.cachedContacts).thenReturn([
          (name: 'Dana R', phoneNumber: '+15553333333'),
        ]);
        when(() => contactsService.cachedRogerUsers).thenReturn([]);

        await notifier.loadInitialContacts();

        final state = container.read(searchProvider);
        final dana = state.results.first;
        expect(dana.isOnRoger, false);
        expect(dana.rogerUser, isNull);
      });

      test('current user is excluded from results', () async {
        final currentUser = User(
          id: 'current-user-id',
          email: 'me@example.com',
          phoneNumber: '+15550000000',
          avatarColor: 'Charcoal',
          createdAt: DateTime(2026, 1, 1),
        );

        when(() => contactsService.refreshBatchCheck())
            .thenAnswer((_) async {});
        when(() => contactsService.cachedContacts).thenReturn([
          (name: 'Me', phoneNumber: '+15550000000'),
          (name: 'Jordan B', phoneNumber: '+15551111111'),
        ]);
        when(() => contactsService.cachedRogerUsers)
            .thenReturn([currentUser, _testUser1]);

        await notifier.loadInitialContacts();

        final state = container.read(searchProvider);
        expect(state.results.length, 1);
        expect(state.results.first.contactName, 'Jordan B');
      });

      test('error on load sets error state', () async {
        when(() => contactsService.refreshBatchCheck())
            .thenThrow(Exception('Network error'));
        when(() => contactsService.cachedContacts).thenReturn([]);
        when(() => contactsService.cachedRogerUsers).thenReturn([]);

        await notifier.loadInitialContacts();

        final state = container.read(searchProvider);
        expect(state.error, isNotNull);
        expect(state.isLoading, false);
      });
    });

    group('search', () {
      setUp(() async {
        when(() => contactsService.refreshBatchCheck())
            .thenAnswer((_) async {});
        when(() => contactsService.cachedContacts).thenReturn([
          (name: 'Jordan B', phoneNumber: '+15551111111'),
          (name: 'Casey L', phoneNumber: '+15552222222'),
          (name: 'Dana R', phoneNumber: '+15553333333'),
        ]);
        when(() => contactsService.cachedRogerUsers)
            .thenReturn([_testUser1, _testUser2]);
        when(() => contactsService.onDemandSearch(any()))
            .thenAnswer((_) async => null);

        await notifier.loadInitialContacts();
      });

      test('filters results by name, case-insensitive', () async {
        await notifier.search('jordan');

        final state = container.read(searchProvider);
        expect(state.results.length, 1);
        expect(state.results.first.contactName, 'Jordan B');
      });

      test('empty query returns all results', () async {
        await notifier.search('jordan');
        await notifier.search('');

        final state = container.read(searchProvider);
        expect(state.results.length, 3);
      });

      test('zero results returns empty list with no error', () async {
        await notifier.search('zzzzzzz');

        final state = container.read(searchProvider);
        expect(state.results, isEmpty);
        expect(state.error, isNull);
      });

      test('search query with special characters handled gracefully',
          () async {
        await notifier.search('🎉!@#\$%');

        final state = container.read(searchProvider);
        expect(state.results, isEmpty);
        expect(state.error, isNull);
      });

      test('updates query in state', () async {
        await notifier.search('cas');

        final state = container.read(searchProvider);
        expect(state.query, 'cas');
      });

      test('filters by contact name only — not by other user data',
          () async {
        // Contact saved as 'J-Dog'. Filter matches contact name only.
        when(() => contactsService.cachedContacts).thenReturn([
          (name: 'J-Dog', phoneNumber: '+15551111111'),
        ]);
        when(() => contactsService.cachedRogerUsers).thenReturn([_testUser1]);
        await notifier.loadInitialContacts();

        // Searching by a name not in contacts should return nothing
        await notifier.search('Jordan');
        expect(container.read(searchProvider).results, isEmpty,
            reason: 'Filter must match contact name only');

        // Searching by contact name should return the result
        await notifier.search('J-Dog');
        final state = container.read(searchProvider);
        expect(state.results.length, 1);
        expect(state.results.first.contactName, 'J-Dog');
      });
    });

    group('contacts permission', () {
      test('granted: loads contacts and sets hasContactsPermission', () async {
        when(() => contactsService.requestPermission())
            .thenAnswer((_) async => true);
        when(() => contactsService.refreshBatchCheck())
            .thenAnswer((_) async {});
        when(() => contactsService.cachedContacts).thenReturn([]);
        when(() => contactsService.cachedRogerUsers).thenReturn([]);

        await notifier.requestContactsPermission();

        verify(() => contactsService.refreshBatchCheck()).called(1);
        final state = container.read(searchProvider);
        expect(state.hasContactsPermission, true);
      });

      test('denied: stays on empty state, no crash', () async {
        when(() => contactsService.requestPermission())
            .thenAnswer((_) async => false);

        await notifier.requestContactsPermission();

        verifyNever(() => contactsService.refreshBatchCheck());
        final state = container.read(searchProvider);
        expect(state.hasContactsPermission, false);
      });

      test('without permission hasContactsPermission is false', () {
        final state = container.read(searchProvider);
        expect(state.hasContactsPermission, false);
      });
    });

    group('startChat', () {
      test('opens existing conversation if 1:1 already exists',
          skip: true, () {});

      test('creates new conversation if none exists',
          skip: true, () {});

      test('never creates duplicate conversation',
          skip: true, () {});
    });

    group('sendInvite', () {
      test('creates pending invite with 7-day expiry',
          skip: true, () {});

      test('marks contact as having pending invite in state',
          skip: true, () {});

      test('only available for contacts NOT on roger', () async {
        when(() => contactsService.refreshBatchCheck())
            .thenAnswer((_) async {});
        when(() => contactsService.cachedContacts).thenReturn([
          (name: 'Jordan B', phoneNumber: '+15551111111'),
          (name: 'Dana R', phoneNumber: '+15553333333'),
        ]);
        when(() => contactsService.cachedRogerUsers)
            .thenReturn([_testUser1]);

        await notifier.loadInitialContacts();

        final state = container.read(searchProvider);
        final jordan =
            state.results.firstWhere((r) => r.contactName == 'Jordan B');
        final dana =
            state.results.firstWhere((r) => r.contactName == 'Dana R');

        expect(jordan.isOnRoger, true);
        expect(dana.isOnRoger, false);
      });
    });
  });
}
