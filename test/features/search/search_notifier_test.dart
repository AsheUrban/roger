import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:roger/core/models/user.dart';
import 'package:roger/core/providers.dart';
import 'package:roger/core/services/contacts_service.dart';
import 'package:roger/core/services/conversation_service.dart';
import 'package:roger/features/search/search_notifier.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

class MockContactsService extends Mock implements ContactsService {}
class MockConversationService extends Mock implements ConversationService {}
class MockSupabaseClient extends Mock implements SupabaseClient {}

final _testUser1 = User(
  id: 'user-1',
  phoneNumber: '+15551111111',
  avatarColor: 'Rust',
  createdAt: DateTime(2026, 1, 1),
);

final _testUser2 = User(
  id: 'user-2',
  phoneNumber: '+15552222222',
  avatarColor: 'Cornflower',
  createdAt: DateTime(2026, 1, 1),
);

void main() {
  late MockContactsService contactsService;
  late MockConversationService conversationService;
  late ProviderContainer container;
  late SearchNotifier notifier;

  setUp(() {
    contactsService = MockContactsService();
    conversationService = MockConversationService();

    // Default: no permission, empty caches
    when(() => contactsService.hasPermission())
        .thenAnswer((_) async => false);
    when(() => contactsService.cachedContacts).thenReturn([]);
    when(() => contactsService.cachedRogerUsers).thenReturn([]);

    container = ProviderContainer(overrides: [
      contactsServiceProvider.overrideWithValue(contactsService),
      conversationServiceProvider.overrideWithValue(conversationService),
      supabaseClientProvider.overrideWithValue(MockSupabaseClient()),
      currentUserIdProvider.overrideWithValue('current-user-id'),
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

    group('contacts declined during onboarding', () {
      test('does not auto-load contacts when user declined even if OS permission exists',
          () async {
        // OS has permission from a previous install
        when(() => contactsService.hasPermission())
            .thenAnswer((_) async => true);

        // But user tapped "Not now" during onboarding
        final declinedContainer = ProviderContainer(overrides: [
          contactsServiceProvider.overrideWithValue(contactsService),
          supabaseClientProvider.overrideWithValue(MockSupabaseClient()),
          currentUserIdProvider.overrideWithValue('current-user-id'),
          contactsDeclinedProvider.overrideWith((ref) => true),
        ]);

        // Let _initAsync run
        await Future<void>.delayed(Duration.zero);

        final state = declinedContainer.read(searchProvider);
        expect(state.results, isEmpty);
        expect(state.hasContactsPermission, false);
        verifyNever(() => contactsService.refreshBatchCheck());

        declinedContainer.dispose();
      });

      test('granting permission via search bar overrides declined flag',
          () async {
        when(() => contactsService.requestPermission())
            .thenAnswer((_) async => true);
        when(() => contactsService.refreshBatchCheck())
            .thenAnswer((_) async {});
        when(() => contactsService.cachedContacts).thenReturn([
          (name: 'Jordan B', phoneNumber: '+15551111111'),
        ]);
        when(() => contactsService.cachedRogerUsers)
            .thenReturn([_testUser1]);

        final declinedContainer = ProviderContainer(overrides: [
          contactsServiceProvider.overrideWithValue(contactsService),
          supabaseClientProvider.overrideWithValue(MockSupabaseClient()),
          currentUserIdProvider.overrideWithValue('current-user-id'),
          contactsDeclinedProvider.overrideWith((ref) => true),
        ]);

        final declinedNotifier = declinedContainer.read(searchProvider.notifier);

        await declinedNotifier.requestContactsPermission();

        final state = declinedContainer.read(searchProvider);
        expect(state.results.length, 1);
        expect(state.hasContactsPermission, true);
        // Declined flag should be cleared
        expect(declinedContainer.read(contactsDeclinedProvider), false);

        declinedContainer.dispose();
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
          skip: 'Integration test — existing-conversation lookup hits real Supabase',
          () {});

      test('never creates duplicate conversation',
          skip: 'Integration test — existing-conversation lookup hits real Supabase',
          () {});

      test(
          'creates new conversation via ConversationService with both members',
          skip:
              'Integration test — the existing-conv lookup runs before create, '
              'and that lookup hits real Supabase. Service call itself is '
              'covered by group-create test below using the same RPC path.',
          () {});
    });

    group('sendInvite', () {
      test('creates pending invite with 7-day expiry',
          skip: 'Integration test — InviteService writes hit real Supabase',
          () {});

      test('marks contact as having pending invite in state',
          skip: 'Integration test — InviteService writes hit real Supabase',
          () {});

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

    group('group mode', () {
      setUp(() async {
        when(() => contactsService.refreshBatchCheck())
            .thenAnswer((_) async {});
        when(() => contactsService.cachedContacts).thenReturn([
          (name: 'Jordan B', phoneNumber: '+15550001000'),
          (name: 'Casey L', phoneNumber: '+15550002000'),
          (name: 'Dana R', phoneNumber: '+15550003000'),
        ]);
        when(() => contactsService.cachedRogerUsers)
            .thenReturn([_testUser1, _testUser2]);
        await notifier.loadInitialContacts();
      });

      test('enterGroupMode sets isGroupMode true', () {
        notifier.enterGroupMode();

        final state = container.read(searchProvider);
        expect(state.isGroupMode, true);
        expect(state.selectedUserIds, isEmpty);
      });

      test('exitGroupMode clears selection and mode', () {
        notifier.enterGroupMode();
        notifier.toggleContactSelection(_testUser1.id);
        notifier.exitGroupMode();

        final state = container.read(searchProvider);
        expect(state.isGroupMode, false);
        expect(state.selectedUserIds, isEmpty);
      });

      test('toggleContactSelection adds and removes user', () {
        notifier.enterGroupMode();

        notifier.toggleContactSelection(_testUser1.id);
        expect(container.read(searchProvider).selectedUserIds,
            contains(_testUser1.id));

        notifier.toggleContactSelection(_testUser1.id);
        expect(container.read(searchProvider).selectedUserIds,
            isNot(contains(_testUser1.id)));
      });

      test('cannot select more than 4 members (you are the 5th)', () {
        notifier.enterGroupMode();

        // Create 5 fake users to try selecting
        for (var i = 0; i < 5; i++) {
          notifier.toggleContactSelection('user-$i');
        }

        final state = container.read(searchProvider);
        expect(state.selectedUserIds.length, 4);
      });

      test('enterGroupModeWithContact enters mode with contact pre-selected',
          () {
        notifier.enterGroupModeWithContact(_testUser1.id);

        final state = container.read(searchProvider);
        expect(state.isGroupMode, true);
        expect(state.selectedUserIds, contains(_testUser1.id));
      });

      test(
          'createGroupConversation calls ConversationService with name '
          'and the selected members plus the current user',
          () async {
        notifier.enterGroupMode();
        notifier.toggleContactSelection(_testUser1.id);
        notifier.toggleContactSelection(_testUser2.id);

        when(() => conversationService.createConversation(
              name: any(named: 'name'),
              memberIds: any(named: 'memberIds'),
            )).thenAnswer((_) async => 'new-conv-id');

        final convId =
            await notifier.createGroupConversation(name: 'Game Night');

        expect(convId, 'new-conv-id');
        verify(() => conversationService.createConversation(
              name: 'Game Night',
              memberIds: any(
                named: 'memberIds',
                that: containsAll(
                    [_testUser1.id, _testUser2.id, 'current-user-id']),
              ),
            )).called(1);
        // Exits group mode after creating
        expect(container.read(searchProvider).isGroupMode, false);
      });

      test(
          'createGroupConversation passes null name when no name provided',
          () async {
        notifier.enterGroupMode();
        notifier.toggleContactSelection(_testUser1.id);
        notifier.toggleContactSelection(_testUser2.id);

        when(() => conversationService.createConversation(
              name: any(named: 'name'),
              memberIds: any(named: 'memberIds'),
            )).thenAnswer((_) async => 'new-conv-id');

        await notifier.createGroupConversation();

        verify(() => conversationService.createConversation(
              name: null,
              memberIds: any(named: 'memberIds'),
            )).called(1);
      });
    });

    group('refreshContacts', () {
      test('calls refreshBatchCheck and rebuilds results', () async {
        when(() => contactsService.hasPermission())
            .thenAnswer((_) async => true);
        when(() => contactsService.refreshBatchCheck())
            .thenAnswer((_) async {});
        when(() => contactsService.cachedContacts).thenReturn([
          (name: 'Henrietta', phoneNumber: '+15550001000'),
        ]);
        when(() => contactsService.cachedRogerUsers)
            .thenReturn([_testUser1]);

        // Prime the notifier so it knows permission is granted
        await notifier.loadInitialContacts();
        clearInteractions(contactsService);

        // Now swap caches and call refresh — results should pick up new data
        when(() => contactsService.cachedContacts).thenReturn([
          (name: 'Henrietta', phoneNumber: '+15550001000'),
          (name: 'Thanos', phoneNumber: '+15550002000'),
        ]);
        when(() => contactsService.refreshBatchCheck())
            .thenAnswer((_) async {});

        await notifier.refreshContacts();

        verify(() => contactsService.refreshBatchCheck()).called(1);
        final state = container.read(searchProvider);
        expect(state.results.length, 2);
      });

      test('no-op when contactsDeclined is true', () async {
        when(() => contactsService.hasPermission())
            .thenAnswer((_) async => true);

        final declinedContainer = ProviderContainer(overrides: [
          contactsServiceProvider.overrideWithValue(contactsService),
          supabaseClientProvider.overrideWithValue(MockSupabaseClient()),
          currentUserIdProvider.overrideWithValue('current-user-id'),
          contactsDeclinedProvider.overrideWith((ref) => true),
        ]);
        final declinedNotifier =
            declinedContainer.read(searchProvider.notifier);

        await declinedNotifier.refreshContacts();

        verifyNever(() => contactsService.refreshBatchCheck());
        declinedContainer.dispose();
      });

      test('no-op when permission is not granted', () async {
        // Default setUp has hasPermission = false; permission state in the
        // notifier reflects that (hasContactsPermission = false in state).
        await notifier.refreshContacts();

        verifyNever(() => contactsService.refreshBatchCheck());
      });

      test('second refreshContacts while one is in flight skips the duplicate',
          () async {
        when(() => contactsService.hasPermission())
            .thenAnswer((_) async => true);
        when(() => contactsService.cachedContacts).thenReturn([]);
        when(() => contactsService.cachedRogerUsers).thenReturn([]);

        // Prime — permission known to notifier
        when(() => contactsService.refreshBatchCheck())
            .thenAnswer((_) async {});
        await notifier.loadInitialContacts();
        clearInteractions(contactsService);

        // Now stub refreshBatchCheck with a controllable completer so the
        // in-flight window is observable.
        final completer = Completer<void>();
        when(() => contactsService.refreshBatchCheck())
            .thenAnswer((_) => completer.future);

        final first = notifier.refreshContacts();
        final second = notifier.refreshContacts();

        // Only one underlying refresh fired
        verify(() => contactsService.refreshBatchCheck()).called(1);

        completer.complete();
        await first;
        await second;

        // Still just one — the second was guarded (no additional calls fired
        // beyond the one already verified above)
        verifyNever(() => contactsService.refreshBatchCheck());
      });
    });
  });
}
