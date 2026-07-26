import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:roger/core/database/app_database.dart';
import 'package:roger/core/providers.dart';
import 'package:roger/core/services/contacts_service.dart';
import 'package:roger/core/services/conversation_service.dart';
import 'package:roger/core/services/share_service.dart';
import 'package:roger/features/search/search_notifier.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockContactsService extends Mock implements ContactsService {}

class MockConversationService extends Mock implements ConversationService {}

class MockShareService extends Mock implements ShareService {}

class MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  late MockContactsService contactsService;
  late MockConversationService conversationService;
  late MockShareService shareService;
  late AppDatabase appDatabase;

  setUp(() {
    contactsService = MockContactsService();
    conversationService = MockConversationService();
    shareService = MockShareService();
    appDatabase = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async => appDatabase.close());

  ProviderContainer makeContainer() {
    return ProviderContainer.test(overrides: [
      contactsServiceProvider.overrideWithValue(contactsService),
      conversationServiceProvider.overrideWithValue(conversationService),
      shareServiceProvider.overrideWithValue(shareService),
      supabaseClientProvider.overrideWithValue(MockSupabaseClient()),
      currentUserIdProvider.overrideWithValue('current-user-id'),
      appDatabaseProvider.overrideWithValue(appDatabase),
    ]);
  }

  group('SearchNotifier', () {
    group('initial state', () {
      test('starts empty', () {
        final container = makeContainer();
        final state = container.read(searchProvider);
        expect(state.results, isEmpty);
        expect(state.query, '');
        expect(state.isGroupMode, false);
      });
    });

    group('addSomeone', () {
      test('a picked contact on roger is added and appears in the list',
          () async {
        when(() => contactsService.pickContact()).thenAnswer(
            (_) async => (name: 'Jordan', phoneNumber: '+15551111111'));
        when(() => contactsService.discover('+15551111111')).thenAnswer(
            (_) async => const DiscoveredUser(
                userId: 'u-1', avatarColor: 'Rust'));

        final container = makeContainer();
        await container.read(searchProvider.notifier).addSomeone();
        // let the addedContactsProvider listener re-load the list
        await Future<void>.delayed(Duration.zero);

        final state = container.read(searchProvider);
        expect(state.results.length, 1);
        expect(state.results.first.userId, 'u-1');
        expect(state.results.first.contactName, 'Jordan');
        expect(state.results.first.avatarColor, 'Rust');
        expect(state.notOnRogerName, isNull);
      });

      test('a picked contact not on roger sets notOnRogerName, no add',
          () async {
        when(() => contactsService.pickContact()).thenAnswer(
            (_) async => (name: 'Dana', phoneNumber: '+15553333333'));
        when(() => contactsService.discover('+15553333333'))
            .thenAnswer((_) async => null);

        final container = makeContainer();
        await container.read(searchProvider.notifier).addSomeone();
        await Future<void>.delayed(Duration.zero);

        final state = container.read(searchProvider);
        expect(state.notOnRogerName, 'Dana');
        expect(state.results, isEmpty);
      });

      test('a cancelled pick is a no-op', () async {
        when(() => contactsService.pickContact())
            .thenAnswer((_) async => null);

        final container = makeContainer();
        await container.read(searchProvider.notifier).addSomeone();

        final state = container.read(searchProvider);
        expect(state.results, isEmpty);
        expect(state.notOnRogerName, isNull);
        verifyNever(() => contactsService.discover(any()));
      });
    });

    group('search', () {
      Future<ProviderContainer> withTwoContacts() async {
        final container = makeContainer();
        await appDatabase.addedContactsDao.upsertAddedContact(
            userId: 'u-1', contactName: 'Jordan', avatarColor: 'Rust');
        await appDatabase.addedContactsDao.upsertAddedContact(
            userId: 'u-2', contactName: 'Casey', avatarColor: 'Olive');
        await container.read(searchProvider.notifier).search('');
        return container;
      }

      test('lists added contacts sorted by name', () async {
        final container = await withTwoContacts();
        final names =
            container.read(searchProvider).results.map((r) => r.contactName);
        expect(names, ['Casey', 'Jordan']);
      });

      test('filters by name, case-insensitive', () async {
        final container = await withTwoContacts();
        await container.read(searchProvider.notifier).search('jor');
        final state = container.read(searchProvider);
        expect(state.results.length, 1);
        expect(state.results.first.contactName, 'Jordan');
        expect(state.query, 'jor');
      });

      test('zero matches returns empty, no error', () async {
        final container = await withTwoContacts();
        await container.read(searchProvider.notifier).search('zzzz');
        final state = container.read(searchProvider);
        expect(state.results, isEmpty);
        expect(state.error, isNull);
      });
    });

    group('group mode', () {
      // Group eligibility (spec §9, 2026-07-25): only people who have REPLIED
      // to the current user in a 1:1 are selectable. The notifier loads the
      // replied set from ConversationService when group mode is entered.
      void stubPartners(Map<String, ({String conversationId, bool hasReplied})>
          partners) {
        when(() => conversationService.getOneToOnePartners(
              currentUserId: any(named: 'currentUserId'),
            )).thenAnswer((_) async => partners);
      }

      Map<String, ({String conversationId, bool hasReplied})> replied(
              List<String> ids) =>
          {
            for (final id in ids)
              id: (conversationId: 'conv-$id', hasReplied: true),
          };

      test('enter / toggle / cap at 4 / exit', () async {
        final container = makeContainer();
        final notifier = container.read(searchProvider.notifier);
        stubPartners(replied(['user-0', 'user-1', 'user-2', 'user-3', 'user-4']));

        notifier.enterGroupMode();
        await pumpEventQueue();
        expect(container.read(searchProvider).isGroupMode, true);

        for (var i = 0; i < 5; i++) {
          notifier.toggleContactSelection('user-$i');
        }
        expect(container.read(searchProvider).selectedUserIds.length, 4);

        notifier.toggleContactSelection('user-0'); // deselect
        expect(container.read(searchProvider).selectedUserIds,
            isNot(contains('user-0')));

        notifier.exitGroupMode();
        expect(container.read(searchProvider).isGroupMode, false);
        expect(container.read(searchProvider).selectedUserIds, isEmpty);
      });

      test('group mode remembers a Conversations-screen origin; exit clears it',
          () async {
        final container = makeContainer();
        final notifier = container.read(searchProvider.notifier);
        stubPartners(const {});

        notifier.enterGroupMode(fromConversations: true);
        expect(
            container.read(searchProvider).groupModeFromConversations, true);

        notifier.exitGroupMode();
        expect(
            container.read(searchProvider).groupModeFromConversations, false);

        // Entered from within Search — no origin flag.
        notifier.enterGroupMode();
        expect(
            container.read(searchProvider).groupModeFromConversations, false);
      });

      test('entering group mode loads the replied set (eligibility)', () async {
        final container = makeContainer();
        final notifier = container.read(searchProvider.notifier);
        stubPartners({
          'u-replied': (conversationId: 'c-1', hasReplied: true),
          'u-silent': (conversationId: 'c-2', hasReplied: false),
        });

        notifier.enterGroupMode();
        await pumpEventQueue();

        expect(container.read(searchProvider).repliedUserIds, {'u-replied'});
      });

      test('toggling someone who has not replied is a no-op', () async {
        final container = makeContainer();
        final notifier = container.read(searchProvider.notifier);
        stubPartners(replied(['u-ok']));

        notifier.enterGroupMode();
        await pumpEventQueue();

        notifier.toggleContactSelection('u-never-replied');
        expect(container.read(searchProvider).selectedUserIds, isEmpty);

        notifier.toggleContactSelection('u-ok');
        expect(container.read(searchProvider).selectedUserIds, ['u-ok']);
      });

      test('enterGroupModeWithContact keeps an eligible seed and prunes an '
          'ineligible one once eligibility loads', () async {
        final container = makeContainer();
        final notifier = container.read(searchProvider.notifier);

        stubPartners(replied(['u-ok']));
        notifier.enterGroupModeWithContact('u-ok');
        await pumpEventQueue();
        expect(container.read(searchProvider).selectedUserIds, ['u-ok']);
        notifier.exitGroupMode();

        stubPartners(replied(['someone-else']));
        notifier.enterGroupModeWithContact('u-never-replied');
        await pumpEventQueue();
        expect(container.read(searchProvider).selectedUserIds, isEmpty,
            reason: 'a long-press on an un-replied contact opens group mode '
                'with nothing selected (spec §18 edge case)');
      });

      test('createGroupConversation calls the service with members + self',
          () async {
        final container = makeContainer();
        final notifier = container.read(searchProvider.notifier);
        stubPartners(replied(['u-1', 'u-2']));
        notifier.enterGroupMode();
        await pumpEventQueue();
        notifier.toggleContactSelection('u-1');
        notifier.toggleContactSelection('u-2');

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
                  that: containsAll(['u-1', 'u-2', 'current-user-id'])),
            )).called(1);
        expect(container.read(searchProvider).isGroupMode, false);
      });
    });

    group('invite', () {
      test('shares a sign-up link and flips to the invited state', () async {
        when(() => shareService.shareText(any())).thenAnswer((_) async {});

        final container = makeContainer();
        await container.read(searchProvider.notifier).invite();

        final shared = verify(() => shareService.shareText(captureAny()))
            .captured
            .single as String;
        expect(shared, contains('roger'));
        expect(container.read(searchProvider).notOnRogerInvited, true);
      });
    });

    group('startChat', () {
      test('delegates to findOrCreate1to1',
          skip: 'Integration test — findOrCreate1to1 hits real Supabase',
          () {});
    });

    group('add-cap rejection (per-(adder, addee) daily cap)', () {
      test('createGroupConversation surfaces the cap message, stays in group '
          'mode, and returns null', () async {
        final container = makeContainer();
        final notifier = container.read(searchProvider.notifier);
        when(() => conversationService.getOneToOnePartners(
              currentUserId: any(named: 'currentUserId'),
            )).thenAnswer((_) async => {
              'u-1': (conversationId: 'c-1', hasReplied: true),
              'u-2': (conversationId: 'c-2', hasReplied: true),
            });
        notifier.enterGroupMode();
        await pumpEventQueue();
        notifier.toggleContactSelection('u-1');
        notifier.toggleContactSelection('u-2');

        when(() => conversationService.createConversation(
              name: any(named: 'name'),
              memberIds: any(named: 'memberIds'),
            )).thenThrow(const PostgrestException(
            message:
                "You've added someone to too many conversations today. Try again tomorrow."));

        final convId =
            await notifier.createGroupConversation(name: 'Spam Night');

        expect(convId, isNull);
        expect(container.read(searchProvider).error, contains('too many'));
        // Selection kept so the user can adjust/retry — not silently dropped.
        expect(container.read(searchProvider).isGroupMode, true);
        expect(container.read(searchProvider).selectedUserIds,
            containsAll(['u-1', 'u-2']));
      });

      test('startChat surfaces the cap message and returns null', () async {
        final container = makeContainer();
        final notifier = container.read(searchProvider.notifier);

        when(() => conversationService.findOrCreate1to1(
              currentUserId: any(named: 'currentUserId'),
              otherUserId: any(named: 'otherUserId'),
            )).thenThrow(const PostgrestException(
            message:
                "You've added someone to too many conversations today. Try again tomorrow."));

        final convId = await notifier.startChat('u-1');

        expect(convId, isNull);
        expect(container.read(searchProvider).error, contains('too many'));
      });
    });
  });
}
