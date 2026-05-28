import 'package:flutter_test/flutter_test.dart';
import 'package:roger/core/models/conversation.dart';
import 'package:roger/core/models/user.dart';
import 'package:roger/features/conversations/conversations_state.dart';

ConversationSummary _summary({
  String convId = 'conv-1',
  String displayName = 'Alex',
  List<User>? members,
  List<String>? memberContactNames,
  DateTime? lastMessageAt,
  bool hasUnread = false,
  bool isOtherUserActive = false,
  DateTime? otherUserLastActiveAt,
}) {
  return ConversationSummary(
    conversation: Conversation(
      id: convId,
      createdAt: DateTime(2026, 1, 1),
    ),
    displayName: displayName,
    members: members ?? const <User>[],
    memberContactNames: memberContactNames ?? const <String>[],
    lastMessageAt: lastMessageAt,
    hasUnread: hasUnread,
    isOtherUserActive: isOtherUserActive,
    otherUserLastActiveAt: otherUserLastActiveAt,
  );
}

void main() {
  group('ConversationsState equality', () {
    test('two default instances are equal', () {
      final a = ConversationsState();
      final b = ConversationsState();
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('two instances with same field values are equal (shared list ref)',
        () {
      final summaries = const <ConversationSummary>[];
      final a = ConversationsState(
        conversations: summaries,
        isLoading: true,
        error: 'oops',
      );
      final b = ConversationsState(
        conversations: summaries,
        isLoading: true,
        error: 'oops',
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('not equal when conversations list identity differs', () {
      final a = ConversationsState(conversations: const []);
      final b = ConversationsState(conversations: [_summary()]);
      expect(a, isNot(equals(b)));
    });

    test('not equal when isLoading differs', () {
      final a = ConversationsState();
      final b = ConversationsState(isLoading: true);
      expect(a, isNot(equals(b)));
    });

    test('not equal when error differs', () {
      final a = ConversationsState();
      final b = ConversationsState(error: 'oops');
      expect(a, isNot(equals(b)));
    });

    test('copyWith with no changes produces an equal instance', () {
      final a = ConversationsState(isLoading: true, error: 'oops');
      final b = a.copyWith();
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test(
        'equal when conversations have same content but different list identity',
        () {
      final a = ConversationsState(conversations: [_summary()]);
      final b = ConversationsState(conversations: [_summary()]);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('ConversationSummary equality', () {
    test('two instances with same field values are equal (shared refs)', () {
      final conversation =
          Conversation(id: 'conv-1', createdAt: DateTime(2026, 1, 1));
      final members = const <User>[];
      final names = const <String>['Alex'];
      final activeAt = DateTime(2026, 4, 8);
      final a = ConversationSummary(
        conversation: conversation,
        displayName: 'Alex',
        members: members,
        memberContactNames: names,
        lastMessageAt: activeAt,
        hasUnread: true,
        isOtherUserActive: true,
        otherUserLastActiveAt: activeAt,
      );
      final b = ConversationSummary(
        conversation: conversation,
        displayName: 'Alex',
        members: members,
        memberContactNames: names,
        lastMessageAt: activeAt,
        hasUnread: true,
        isOtherUserActive: true,
        otherUserLastActiveAt: activeAt,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('not equal when conversation differs (different identity)', () {
      final a = _summary(convId: 'conv-1');
      final b = _summary(convId: 'conv-2');
      expect(a, isNot(equals(b)));
    });

    test('not equal when displayName differs', () {
      final a = _summary(displayName: 'Alex');
      final b = _summary(displayName: 'Sam');
      expect(a, isNot(equals(b)));
    });

    test('not equal when members differ (different list identity)', () {
      final a = _summary(members: const []);
      final b = _summary(members: [
        User(
          id: 'u-1',
          phoneNumber: '+15551111111',
          avatarColor: 'Rust',
          createdAt: DateTime(2026, 1, 1),
        ),
      ]);
      expect(a, isNot(equals(b)));
    });

    test('not equal when memberContactNames differ (different list identity)',
        () {
      final a = _summary(memberContactNames: const []);
      final b = _summary(memberContactNames: const ['Alex']);
      expect(a, isNot(equals(b)));
    });

    test('not equal when lastMessageAt differs', () {
      final a = _summary(lastMessageAt: null);
      final b = _summary(lastMessageAt: DateTime(2026, 4, 8));
      expect(a, isNot(equals(b)));
    });

    test('not equal when hasUnread differs', () {
      final a = _summary(hasUnread: false);
      final b = _summary(hasUnread: true);
      expect(a, isNot(equals(b)));
    });

    test('not equal when isOtherUserActive differs', () {
      final a = _summary(isOtherUserActive: false);
      final b = _summary(isOtherUserActive: true);
      expect(a, isNot(equals(b)));
    });

    test('not equal when otherUserLastActiveAt differs', () {
      final a = _summary(otherUserLastActiveAt: null);
      final b = _summary(otherUserLastActiveAt: DateTime(2026, 4, 8));
      expect(a, isNot(equals(b)));
    });

    test('copyWith with no changes produces an equal instance', () {
      final a = _summary(
        displayName: 'Alex',
        hasUnread: true,
        isOtherUserActive: true,
      );
      final b = a.copyWith();
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test(
        'equal when memberContactNames have same content but different list identity',
        () {
      final a = _summary(memberContactNames: ['Alex', 'Jordan']);
      final b = _summary(memberContactNames: ['Alex', 'Jordan']);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('equal when members list has equivalent Users in different instances',
        () {
      final a = _summary(members: [
        User(
          id: 'u-1',
          phoneNumber: '+15551111111',
          avatarColor: 'Rust',
          createdAt: DateTime(2026, 1, 1),
        ),
      ]);
      final b = _summary(members: [
        User(
          id: 'u-1',
          phoneNumber: '+15551111111',
          avatarColor: 'Rust',
          createdAt: DateTime(2026, 1, 1),
        ),
      ]);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
