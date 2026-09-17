import 'search_result.dart';

class Conversation {
  const Conversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Conversation.fromMap(Map<String, Object?> map) => Conversation(
    id: map['id']! as String,
    title: map['title']! as String,
    createdAt: DateTime.parse(map['created_at']! as String),
    updatedAt: DateTime.parse(map['updated_at']! as String),
  );
}

class StoredChatMessage {
  const StoredChatMessage({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    required this.createdAt,
    this.sources = const [],
  });

  final String id;
  final String conversationId;
  final String role;
  final String content;
  final DateTime createdAt;
  final List<SearchResult> sources;

  bool get isUser => role == 'user';
}
