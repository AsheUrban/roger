class Conversation {
  final String id;
  final String? name;
  final DateTime createdAt;

  const Conversation({
    required this.id,
    this.name,
    required this.createdAt,
  });
}
