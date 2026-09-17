import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/chat_history.dart';
import '../models/search_result.dart';

class ChatHistoryRepository {
  ChatHistoryRepository({
    DatabaseFactory? databaseFactory,
    String? databasePath,
  }) : this._(databaseFactory, databasePath);

  ChatHistoryRepository._(this._databaseFactory, this._databasePath);

  final DatabaseFactory? _databaseFactory;
  final String? _databasePath;
  Database? _database;
  final Random _random = Random.secure();

  Future<Database> get _db async {
    if (_database != null) return _database!;
    sqfliteFfiInit();
    final path =
        _databasePath ??
        p.join(
          (await getApplicationSupportDirectory()).path,
          'chat_history.db',
        );
    _database = await (_databaseFactory ?? databaseFactoryFfi).openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE conversations(
              id TEXT PRIMARY KEY,
              title TEXT,
              created_at TEXT,
              updated_at TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE messages(
              id TEXT PRIMARY KEY,
              conversation_id TEXT,
              role TEXT,
              content TEXT,
              created_at TEXT,
              FOREIGN KEY(conversation_id) REFERENCES conversations(id) ON DELETE CASCADE
            )
          ''');
          await db.execute('''
            CREATE TABLE message_sources(
              id TEXT PRIMARY KEY,
              message_id TEXT,
              subject_code TEXT,
              syllabus_id INTEGER,
              section TEXT,
              session_number INTEGER,
              title TEXT,
              snippet TEXT,
              FOREIGN KEY(message_id) REFERENCES messages(id) ON DELETE CASCADE
            )
          ''');
          await db.execute(
            'CREATE INDEX messages_conversation_idx ON messages(conversation_id, created_at)',
          );
          await db.execute(
            'CREATE INDEX sources_message_idx ON message_sources(message_id)',
          );
        },
      ),
    );
    return _database!;
  }

  String newId() {
    final time = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final random = List.generate(
      4,
      (_) => _random.nextInt(0xffffffff).toRadixString(16).padLeft(8, '0'),
    ).join();
    return '$time-$random';
  }

  String titleFor(String firstMessage) {
    final singleLine = firstMessage.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (singleLine.length <= 60) return singleLine;
    return '${singleLine.substring(0, 57).trimRight()}...';
  }

  Future<Conversation> createConversation(String firstMessage) async {
    final now = DateTime.now().toUtc();
    final conversation = Conversation(
      id: newId(),
      title: titleFor(firstMessage),
      createdAt: now,
      updatedAt: now,
    );
    final db = await _db;
    await db.insert('conversations', {
      'id': conversation.id,
      'title': conversation.title,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });
    return conversation;
  }

  Future<List<Conversation>> getConversations() async {
    final rows = await (await _db).query(
      'conversations',
      orderBy: 'updated_at DESC',
    );
    return rows.map(Conversation.fromMap).toList();
  }

  Future<List<StoredChatMessage>> getMessages(String conversationId) async {
    final db = await _db;
    final rows = await db.query(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'created_at ASC',
    );
    final result = <StoredChatMessage>[];
    for (final row in rows) {
      final id = row['id']! as String;
      final sourceRows = await db.query(
        'message_sources',
        where: 'message_id = ?',
        whereArgs: [id],
        orderBy: 'rowid ASC',
      );
      result.add(
        StoredChatMessage(
          id: id,
          conversationId: conversationId,
          role: row['role']! as String,
          content: row['content']! as String,
          createdAt: DateTime.parse(row['created_at']! as String),
          sources: sourceRows
              .map(
                (source) => SearchResult(
                  subjectCode: source['subject_code'] as String? ?? '',
                  syllabusId: source['syllabus_id'] as int?,
                  section: source['section'] as String? ?? '',
                  sessionNumber: source['session_number'] as int?,
                  title: source['title'] as String? ?? '',
                  content: source['snippet'] as String? ?? '',
                  snippet: source['snippet'] as String?,
                  sourcePath: '',
                ),
              )
              .toList(),
        ),
      );
    }
    return result;
  }

  Future<StoredChatMessage> addMessage({
    required String conversationId,
    required String role,
    required String content,
    List<SearchResult> sources = const [],
  }) async {
    final db = await _db;
    final now = DateTime.now().toUtc();
    final message = StoredChatMessage(
      id: newId(),
      conversationId: conversationId,
      role: role,
      content: content,
      createdAt: now,
      sources: sources,
    );
    await db.transaction((txn) async {
      await txn.insert('messages', {
        'id': message.id,
        'conversation_id': conversationId,
        'role': role,
        'content': content,
        'created_at': now.toIso8601String(),
      });
      for (final source in sources) {
        await txn.insert('message_sources', {
          'id': newId(),
          'message_id': message.id,
          'subject_code': source.subjectCode,
          'syllabus_id': source.syllabusId,
          'section': source.section,
          'session_number': source.sessionNumber,
          'title': source.title,
          'snippet': source.snippet ?? source.content,
        });
      }
      await txn.update(
        'conversations',
        {'updated_at': now.toIso8601String()},
        where: 'id = ?',
        whereArgs: [conversationId],
      );
    });
    return message;
  }

  Future<void> deleteConversation(String id) async {
    await (await _db).delete('conversations', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearAll() async {
    await (await _db).delete('conversations');
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
