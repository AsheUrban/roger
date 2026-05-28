import 'package:flutter_test/flutter_test.dart';
import 'package:roger/core/models/user.dart';

User _baseUser({
  String id = 'u-1',
  String phoneNumber = '+15551111111',
  String avatarColor = 'Rust',
  String? recoveryEmail,
  DateTime? lastActiveAt,
  DateTime? createdAt,
}) {
  return User(
    id: id,
    phoneNumber: phoneNumber,
    avatarColor: avatarColor,
    recoveryEmail: recoveryEmail,
    lastActiveAt: lastActiveAt,
    createdAt: createdAt ?? DateTime(2026, 1, 1),
  );
}

void main() {
  group('User equality', () {
    test('two instances with the same field values are equal', () {
      final a = _baseUser(
        recoveryEmail: 'a@example.com',
        lastActiveAt: DateTime(2026, 4, 8),
      );
      final b = _baseUser(
        recoveryEmail: 'a@example.com',
        lastActiveAt: DateTime(2026, 4, 8),
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('two instances with minimum fields are equal', () {
      final a = _baseUser();
      final b = _baseUser();
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('not equal when id differs', () {
      expect(_baseUser(id: 'u-1'), isNot(equals(_baseUser(id: 'u-2'))));
    });

    test('not equal when phoneNumber differs', () {
      expect(
        _baseUser(phoneNumber: '+15551111111'),
        isNot(equals(_baseUser(phoneNumber: '+15552222222'))),
      );
    });

    test('not equal when avatarColor differs', () {
      expect(
        _baseUser(avatarColor: 'Rust'),
        isNot(equals(_baseUser(avatarColor: 'Salmon'))),
      );
    });

    test('not equal when recoveryEmail differs', () {
      expect(
        _baseUser(recoveryEmail: 'a@example.com'),
        isNot(equals(_baseUser(recoveryEmail: 'b@example.com'))),
      );
    });

    test('not equal when one has recoveryEmail set and the other is null', () {
      expect(
        _baseUser(),
        isNot(equals(_baseUser(recoveryEmail: 'a@example.com'))),
      );
    });

    test('not equal when lastActiveAt differs', () {
      expect(
        _baseUser(lastActiveAt: DateTime(2026, 4, 8)),
        isNot(equals(_baseUser(lastActiveAt: DateTime(2026, 4, 9)))),
      );
    });

    test('not equal when one has lastActiveAt set and the other is null', () {
      expect(
        _baseUser(),
        isNot(equals(_baseUser(lastActiveAt: DateTime(2026, 4, 8)))),
      );
    });

    test('not equal when createdAt differs', () {
      expect(
        _baseUser(createdAt: DateTime(2026, 1, 1)),
        isNot(equals(_baseUser(createdAt: DateTime(2026, 1, 2)))),
      );
    });
  });
}
