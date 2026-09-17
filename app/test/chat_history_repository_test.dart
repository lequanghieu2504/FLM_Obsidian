import 'package:app/models/search_result.dart';
import 'package:app/repositories/chat_history_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late ChatHistoryRepository repository;

  setUp(() {
    sqfliteFfiInit();
    repository = ChatHistoryRepository(
      databaseFactory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
  });

  tearDown(() => repository.close());

  test('stores messages and their retrieval sources', () async {
    final conversation = await repository.createConversation(
      'What are the prerequisites for PRM393?',
    );
    await repository.addMessage(
      conversationId: conversation.id,
      role: 'user',
      content: 'What are the prerequisites for PRM393?',
    );
    await repository.addMessage(
      conversationId: conversation.id,
      role: 'assistant',
      content: 'MAD101 is a prerequisite.',
      sources: const [
        SearchResult(
          subjectCode: 'PRM393',
          syllabusId: 42,
          section: 'prerequisite',
          sessionNumber: null,
          title: 'Pre-Requisite',
          content: 'MAD101',
          snippet: 'MAD101',
          sourcePath: '/syllabi/PRM393.md',
        ),
      ],
    );

    final messages = await repository.getMessages(conversation.id);

    expect(messages, hasLength(2));
    expect(messages.first.isUser, isTrue);
    expect(messages.last.content, 'MAD101 is a prerequisite.');
    expect(messages.last.sources.single.subjectCode, 'PRM393');
    expect(messages.last.sources.single.section, 'prerequisite');
    expect(messages.last.sources.single.snippet, 'MAD101');
  });

  test(
    'uses a concise title and deletes messages with the conversation',
    () async {
      final conversation = await repository.createConversation(
        '  This is a deliberately long first message that should become a concise conversation title in the sidebar.  ',
      );
      await repository.addMessage(
        conversationId: conversation.id,
        role: 'user',
        content: 'Hello',
      );

      final conversations = await repository.getConversations();
      expect(conversations.single.title.length, lessThanOrEqualTo(60));
      expect(conversations.single.title, endsWith('...'));

      await repository.deleteConversation(conversation.id);

      expect(await repository.getConversations(), isEmpty);
      expect(await repository.getMessages(conversation.id), isEmpty);
    },
  );
}
