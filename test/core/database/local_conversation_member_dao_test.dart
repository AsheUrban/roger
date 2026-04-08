import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roger/core/database/app_database.dart';

// Tests use NativeDatabase.memory() — no encryption needed for in-memory
// test databases. SQLCipher encryption is exercised on real devices.
// These tests cover DAO logic only.

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('LocalConversationMemberDao', () {
    group('upsertMember', () {
      test('inserts a new member with all fields', () async {
        await db.localConversationMemberDao.upsertMember(
          memberId: 'member-1',
          conversationId: 'conv-1',
          userId: 'user-1',
          phoneNumber: '+15551111111',
          avatarColor: 'Rust',
        );

        final members = await db.localConversationMemberDao
            .getMembersForConversation('conv-1');
        expect(members.length, 1);
        expect(members.first.memberId, 'member-1');
        expect(members.first.phoneNumber, '+15551111111');
        expect(members.first.avatarColor, 'Rust');
        expect(members.first.userId, 'user-1');
      });

      test('updates existing row on conflict — preserves phone and color',
          () async {
        // Initial insert when user is active
        await db.localConversationMemberDao.upsertMember(
          memberId: 'member-1',
          conversationId: 'conv-1',
          userId: 'user-1',
          phoneNumber: '+15551111111',
          avatarColor: 'Rust',
        );

        // Upsert again after account deletion (userId now null, Supabase sends
        // the same memberId row with user_id = null)
        await db.localConversationMemberDao.upsertMember(
          memberId: 'member-1',
          conversationId: 'conv-1',
          userId: null,
          phoneNumber: '+15551111111',
          avatarColor: 'Rust',
        );

        final members = await db.localConversationMemberDao
            .getMembersForConversation('conv-1');
        expect(members.length, 1);
        expect(members.first.phoneNumber, '+15551111111');
        expect(members.first.avatarColor, 'Rust');
        expect(members.first.userId, isNull);
      });

      test('stores multiple members for the same conversation', () async {
        await db.localConversationMemberDao.upsertMember(
          memberId: 'member-1',
          conversationId: 'conv-1',
          userId: 'user-1',
          phoneNumber: '+15551111111',
          avatarColor: 'Rust',
        );
        await db.localConversationMemberDao.upsertMember(
          memberId: 'member-2',
          conversationId: 'conv-1',
          userId: 'user-2',
          phoneNumber: '+15552222222',
          avatarColor: 'Cornflower',
        );

        final members = await db.localConversationMemberDao
            .getMembersForConversation('conv-1');
        expect(members.length, 2);
      });

      test('members from different conversations are isolated', () async {
        await db.localConversationMemberDao.upsertMember(
          memberId: 'member-1',
          conversationId: 'conv-1',
          userId: 'user-1',
          phoneNumber: '+15551111111',
          avatarColor: 'Rust',
        );
        await db.localConversationMemberDao.upsertMember(
          memberId: 'member-2',
          conversationId: 'conv-2',
          userId: 'user-2',
          phoneNumber: '+15552222222',
          avatarColor: 'Olive',
        );

        final conv1 = await db.localConversationMemberDao
            .getMembersForConversation('conv-1');
        final conv2 = await db.localConversationMemberDao
            .getMembersForConversation('conv-2');

        expect(conv1.length, 1);
        expect(conv2.length, 1);
        expect(conv1.first.phoneNumber, '+15551111111');
        expect(conv2.first.phoneNumber, '+15552222222');
      });
    });

    group('getPhoneNumber', () {
      test('returns cached phone number for a known memberId', () async {
        await db.localConversationMemberDao.upsertMember(
          memberId: 'member-1',
          conversationId: 'conv-1',
          userId: 'user-1',
          phoneNumber: '+15551111111',
          avatarColor: 'Rust',
        );

        final phone = await db.localConversationMemberDao
            .getPhoneNumber('member-1');
        expect(phone, '+15551111111');
      });

      test('returns cached phone even after userId is nulled (deleted user)',
          () async {
        await db.localConversationMemberDao.upsertMember(
          memberId: 'member-1',
          conversationId: 'conv-1',
          userId: 'user-1',
          phoneNumber: '+15551111111',
          avatarColor: 'Rust',
        );
        await db.localConversationMemberDao.upsertMember(
          memberId: 'member-1',
          conversationId: 'conv-1',
          userId: null,
          phoneNumber: '+15551111111',
          avatarColor: 'Rust',
        );

        final phone = await db.localConversationMemberDao
            .getPhoneNumber('member-1');
        expect(phone, '+15551111111');
      });

      test('returns null for unknown memberId', () async {
        final phone = await db.localConversationMemberDao
            .getPhoneNumber('nonexistent');
        expect(phone, isNull);
      });
    });

    group('getMembersForConversation', () {
      test('returns empty list when no members cached', () async {
        final members = await db.localConversationMemberDao
            .getMembersForConversation('conv-unknown');
        expect(members, isEmpty);
      });

      test('includes deleted members (userId null) alongside active ones',
          () async {
        await db.localConversationMemberDao.upsertMember(
          memberId: 'member-1',
          conversationId: 'conv-1',
          userId: 'user-1',
          phoneNumber: '+15551111111',
          avatarColor: 'Rust',
        );
        await db.localConversationMemberDao.upsertMember(
          memberId: 'member-2',
          conversationId: 'conv-1',
          userId: null,
          phoneNumber: '+15552222222',
          avatarColor: 'Cornflower',
        );

        final members = await db.localConversationMemberDao
            .getMembersForConversation('conv-1');
        expect(members.length, 2);

        final deleted = members.firstWhere((m) => m.userId == null);
        expect(deleted.phoneNumber, '+15552222222');
      });
    });
  });
}
