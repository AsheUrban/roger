import 'package:flutter_test/flutter_test.dart';
import 'package:roger/core/models/conversation.dart';

Conversation _baseConversation({
  String id = 'conv-1',
  String? name,
  DateTime? createdAt,
}) {
  return Conversation(
    id: id,
    name: name,
    createdAt: createdAt ?? DateTime(2026, 1, 1),
  );
}

void main() {
  group('Conversation equality', () {
    test('two instances with the same field values are equal', () {
      final a = _baseConversation(name: 'Crew');
      final b = _baseConversation(name: 'Crew');
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('two instances with null name are equal', () {
      final a = _baseConversation();
      final b = _baseConversation();
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('not equal when id differs', () {
      expect(
        _baseConversation(id: 'conv-1'),
        isNot(equals(_baseConversation(id: 'conv-2'))),
      );
    });

    test('not equal when name differs', () {
      expect(
        _baseConversation(name: 'Crew'),
        isNot(equals(_baseConversation(name: 'Squad'))),
      );
    });

    test('not equal when one has name set and the other is null', () {
      expect(
        _baseConversation(),
        isNot(equals(_baseConversation(name: 'Crew'))),
      );
    });

    test('not equal when createdAt differs', () {
      expect(
        _baseConversation(createdAt: DateTime(2026, 1, 1)),
        isNot(equals(_baseConversation(createdAt: DateTime(2026, 1, 2)))),
      );
    });
  });
}
