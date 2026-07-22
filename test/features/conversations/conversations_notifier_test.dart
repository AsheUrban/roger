import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:roger/core/database/app_database.dart';
import 'package:roger/core/models/conversation.dart';
import 'package:roger/core/models/user.dart';
import 'package:roger/core/providers.dart';
import 'package:roger/core/services/contacts_service.dart';
import 'package:roger/core/services/conversation_service.dart';
import 'package:roger/features/conversations/conversations_notifier.dart';
import 'package:roger/features/conversations/conversations_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

class MockContactsService extends Mock implements ContactsService {}
class MockConversationService extends Mock implements ConversationService {}
class MockSupabaseClient extends Mock implements SupabaseClient {}

AppDatabase _makeInMemoryDatabase() =>
    AppDatabase(NativeDatabase.memory());

// ---- Test data ----

final _conv1 = Conversation(id: 'conv-1', createdAt: DateTime(2026, 1, 1));
final _conv2 = Conversation(id: 'conv-2', createdAt: DateTime(2026, 1, 2));

final _otherUser = User(
  id: 'other-user',
  avatarColor: 'Rust',
  createdAt: DateTime(2026, 1, 1),
);

final _userU1 = User(
  id: 'u1',
  avatarColor: 'Rust',
  createdAt: DateTime(2026, 1, 1),
);

ConversationSummary _makeSummary({
  required Conversation conversation,
  String displayName = 'Test',
  DateTime? lastMessageAt,
  bool hasUnread = false,
  bool isOtherUserActive = false,
}) {
  return ConversationSummary(
    conversation: conversation,
    displayName: displayName,
    members: [_otherUser],
    lastMessageAt: lastMessageAt,
    hasUnread: hasUnread,
    isOtherUserActive: isOtherUserActive,
  );
}

void main() {
  late MockContactsService contactsService;
  late MockConversationService conversationService;
  late AppDatabase appDatabase;

  setUp(() {
    contactsService = MockContactsService();
    conversationService = MockConversationService();
    appDatabase = _makeInMemoryDatabase();
  });

  tearDown(() async => appDatabase.close());

  ProviderContainer makeContainer({ConversationsState? seed}) {
    return ProviderContainer.test(
      overrides: [
        if (seed != null)
          conversationsProvider.overrideWithBuild((ref, self) => seed),
        contactsServiceProvider.overrideWithValue(contactsService),
        conversationServiceProvider.overrideWithValue(conversationService),
        supabaseClientProvider.overrideWithValue(MockSupabaseClient()),
        currentUserIdProvider.overrideWithValue('current-user-id'),
        appDatabaseProvider.overrideWithValue(appDatabase),
      ],
    );
  }

  group('ConversationsNotifier', () {
    group('initial state', () {
      test('starts with empty list, not loading, no error', () {
        final container = makeContainer();
        final state = container.read(conversationsProvider);
        expect(state.conversations, isEmpty);
        expect(state.isLoading, false);
        expect(state.error, isNull);
      });
    });

    group('loadConversations', () {
      // These require real Supabase — tested on emulator.
      test('loads all active conversations current user is a member of',
          skip: 'Integration test', () {});

      test('excludes conversations where current user has left (left_at set)',
          skip: 'Integration test', () {});

      test('deleted user conversation still appears',
          skip: 'Integration test', () {});

      test('sorts by most recent message first',
          skip: 'Integration test', () {});

      test('sets isLoading true while fetching, false on complete',
          skip: 'Integration test', () {});

      test('sets error state on Supabase failure',
          skip: 'Integration test', () {});
    });

    group('onNewMessage', () {
      test('sets hasUnread true when message is from another user', () {
        final seed = ConversationsState(
          conversations: [
            _makeSummary(
              conversation: _conv1,
              lastMessageAt: DateTime(2026, 4, 1),
            ),
          ],
        );
        final container = makeContainer(seed: seed);
        container.read(conversationsProvider.notifier).onNewMessage(
          conversationId: 'conv-1',
          senderId: 'other-user',
          createdAt: DateTime(2026, 4, 8),
        );

        final updated = container.read(conversationsProvider).conversations.first;
        expect(updated.hasUnread, true);
      });

      test('does not set hasUnread when message is from current user', () {
        final seed = ConversationsState(
          conversations: [
            _makeSummary(
              conversation: _conv1,
              lastMessageAt: DateTime(2026, 4, 1),
              hasUnread: false,
            ),
          ],
        );
        final container = makeContainer(seed: seed);
        container.read(conversationsProvider.notifier).onNewMessage(
          conversationId: 'conv-1',
          senderId: 'current-user-id',
          createdAt: DateTime(2026, 4, 8),
        );

        final updated = container.read(conversationsProvider).conversations.first;
        expect(updated.hasUnread, false);
      });

      test('updates lastMessageAt to the new message timestamp', () {
        final original = DateTime(2026, 4, 1);
        final incoming = DateTime(2026, 4, 8, 12, 0);
        final seed = ConversationsState(
          conversations: [
            _makeSummary(conversation: _conv1, lastMessageAt: original),
          ],
        );
        final container = makeContainer(seed: seed);
        container.read(conversationsProvider.notifier).onNewMessage(
          conversationId: 'conv-1',
          senderId: 'other-user',
          createdAt: incoming,
        );

        final updated = container.read(conversationsProvider).conversations.first;
        expect(updated.lastMessageAt, incoming);
      });

      test('moves updated conversation to top of list', () {
        // conv2 is more recent (second in list = top after sort)
        // conv1 is older (first entry = bottom)
        // After new message for conv1, conv1 should be at top
        final older = DateTime(2026, 4, 1);
        final newer = DateTime(2026, 4, 5);
        final seed = ConversationsState(
          conversations: [
            _makeSummary(conversation: _conv2, lastMessageAt: newer),
            _makeSummary(conversation: _conv1, lastMessageAt: older),
          ],
        );
        final container = makeContainer(seed: seed);
        // New message for conv1 makes it the most recent
        container.read(conversationsProvider.notifier).onNewMessage(
          conversationId: 'conv-1',
          senderId: 'other-user',
          createdAt: DateTime(2026, 4, 8),
        );

        final conversations = container.read(conversationsProvider).conversations;
        expect(conversations.first.conversation.id, 'conv-1');
        expect(conversations.last.conversation.id, 'conv-2');
      });

      test('does not affect other conversations in the list', () {
        final seed = ConversationsState(
          conversations: [
            _makeSummary(
              conversation: _conv1,
              displayName: 'Conv One',
              lastMessageAt: DateTime(2026, 4, 5),
            ),
            _makeSummary(
              conversation: _conv2,
              displayName: 'Conv Two',
              lastMessageAt: DateTime(2026, 4, 1),
              hasUnread: false,
            ),
          ],
        );
        final container = makeContainer(seed: seed);
        container.read(conversationsProvider.notifier).onNewMessage(
          conversationId: 'conv-1',
          senderId: 'other-user',
          createdAt: DateTime(2026, 4, 8),
        );

        final conversations = container.read(conversationsProvider).conversations;
        final conv2 = conversations.firstWhere((c) => c.conversation.id == 'conv-2');
        expect(conv2.hasUnread, false);
        expect(conv2.displayName, 'Conv Two');
      });
    });

    group('leaveConversation', () {
      test('leaves the group via the service and drops it from the list',
          () async {
        final seed = ConversationsState(
          conversations: [
            _makeSummary(conversation: _conv1, displayName: 'Keep'),
            _makeSummary(conversation: _conv2, displayName: 'Leave'),
          ],
        );
        when(() => conversationService.leaveGroup(
              conversationId: any(named: 'conversationId'),
              currentUserId: any(named: 'currentUserId'),
            )).thenAnswer((_) async {});

        final container = makeContainer(seed: seed);
        await container
            .read(conversationsProvider.notifier)
            .leaveConversation('conv-2');

        verify(() => conversationService.leaveGroup(
              conversationId: 'conv-2',
              currentUserId: 'current-user-id',
            )).called(1);
        final ids = container
            .read(conversationsProvider)
            .conversations
            .map((s) => s.conversation.id);
        expect(ids, ['conv-1']);
      });
    });

    group('bulk-leave selection', () {
      ConversationsState twoConvos() => ConversationsState(
            conversations: [
              _makeSummary(conversation: _conv1, displayName: 'One'),
              _makeSummary(conversation: _conv2, displayName: 'Two'),
            ],
          );

      test('enter / toggle / exit selection mode', () {
        final container = makeContainer(seed: twoConvos());
        final notifier = container.read(conversationsProvider.notifier);

        notifier.enterSelectionMode();
        expect(container.read(conversationsProvider).isSelectionMode, true);

        notifier.toggleSelected('conv-1');
        notifier.toggleSelected('conv-2');
        expect(container.read(conversationsProvider).selectedIds,
            {'conv-1', 'conv-2'});

        notifier.toggleSelected('conv-1'); // deselect
        expect(container.read(conversationsProvider).selectedIds, {'conv-2'});

        notifier.exitSelectionMode();
        expect(container.read(conversationsProvider).isSelectionMode, false);
        expect(container.read(conversationsProvider).selectedIds, isEmpty);
      });

      test('leaveSelected leaves each selected group, drops them, exits mode',
          () async {
        when(() => conversationService.leaveGroup(
              conversationId: any(named: 'conversationId'),
              currentUserId: any(named: 'currentUserId'),
            )).thenAnswer((_) async {});

        final container = makeContainer(seed: twoConvos());
        final notifier = container.read(conversationsProvider.notifier);
        notifier.enterSelectionMode();
        notifier.toggleSelected('conv-1');
        notifier.toggleSelected('conv-2');

        await notifier.leaveSelected();

        verify(() => conversationService.leaveGroup(
              conversationId: 'conv-1',
              currentUserId: 'current-user-id',
            )).called(1);
        verify(() => conversationService.leaveGroup(
              conversationId: 'conv-2',
              currentUserId: 'current-user-id',
            )).called(1);
        expect(container.read(conversationsProvider).conversations, isEmpty);
        expect(container.read(conversationsProvider).isSelectionMode, false);
      });

      test('leaveSelected with nothing selected is a no-op', () async {
        final container = makeContainer(seed: twoConvos());
        final notifier = container.read(conversationsProvider.notifier);
        notifier.enterSelectionMode();

        await notifier.leaveSelected();

        verifyNever(() => conversationService.leaveGroup(
              conversationId: any(named: 'conversationId'),
              currentUserId: any(named: 'currentUserId'),
            ));
        expect(
            container.read(conversationsProvider).conversations.length, 2);
      });
    });

    group('reresolveNames (display-name "?" reactivity fix)', () {
      test('re-resolves member and display names from an updated map', () {
        // A member you hadn't picked yet renders as "?" at load. When the
        // addedContacts map gains their name, the notifier re-resolves.
        final seed = ConversationsState(
          conversations: [
            ConversationSummary(
              conversation: _conv1,
              displayName: '?',
              members: [_userU1],
              memberContactNames: const ['?'],
            ),
          ],
        );
        final container = makeContainer(seed: seed);
        container
            .read(conversationsProvider.notifier)
            .reresolveNames({'u1': 'Jordan'});

        final updated =
            container.read(conversationsProvider).conversations.first;
        expect(updated.displayName, 'Jordan');
        expect(updated.memberContactNames, ['Jordan']);
      });

      test('a member still absent from the map stays "?"', () {
        final seed = ConversationsState(
          conversations: [
            ConversationSummary(
              conversation: _conv1,
              displayName: '?',
              members: [_userU1],
              memberContactNames: const ['?'],
            ),
          ],
        );
        final container = makeContainer(seed: seed);
        container
            .read(conversationsProvider.notifier)
            .reresolveNames(const {'someone-else': 'Casey'});

        final updated =
            container.read(conversationsProvider).conversations.first;
        expect(updated.displayName, '?');
        expect(updated.memberContactNames, ['?']);
      });

      test('a group with a set name keeps it; member names still re-resolve',
          () {
        final groupConv = Conversation(
          id: 'g1',
          name: 'Trip crew',
          createdAt: DateTime(2026, 1, 1),
        );
        final seed = ConversationsState(
          conversations: [
            ConversationSummary(
              conversation: groupConv,
              displayName: 'Trip crew',
              members: [_userU1],
              memberContactNames: const ['?'],
            ),
          ],
        );
        final container = makeContainer(seed: seed);
        container
            .read(conversationsProvider.notifier)
            .reresolveNames({'u1': 'Jordan'});

        final updated =
            container.read(conversationsProvider).conversations.first;
        expect(updated.displayName, 'Trip crew'); // group name wins
        expect(updated.memberContactNames, ['Jordan']); // for avatar initials
      });

      test('re-resolving keeps the "Deleted user" label in the display name',
          () {
        // A group with one resolvable member and one deleted member. Re-resolve
        // must still account for the deleted slot (it isn't in `members`).
        final seed = ConversationsState(
          conversations: [
            ConversationSummary(
              conversation: _conv1,
              displayName: '?, Deleted user',
              members: [_userU1],
              memberContactNames: const ['?'],
              deletedMemberCount: 1,
            ),
          ],
        );
        final container = makeContainer(seed: seed);
        container
            .read(conversationsProvider.notifier)
            .reresolveNames({'u1': 'Jordan'});

        final updated =
            container.read(conversationsProvider).conversations.first;
        expect(updated.displayName, 'Jordan, Deleted user');
        expect(updated.memberContactNames, ['Jordan']);
      });
    });
  });
}
