import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

class KnowledgeDatabase {
  Database? _database;

  Future<Database> open() async {
    final existing = _database;
    if (existing != null) {
      return existing;
    }
    final supportDir = await getApplicationSupportDirectory();
    final file = File('${supportDir.path}/knowledge.db');
    final devFile = File('../data/knowledge.db');
    if (!file.existsSync()) {
      if (devFile.existsSync()) {
        _database = sqlite3.open(devFile.path);
        return _database!;
      }
      _database = sqlite3.openInMemory();
      _createEmptySchema(_database!);
      return _database!;
    }
    _database = sqlite3.open(file.path);
    return _database!;
  }

  void _createEmptySchema(Database db) {
    db.execute(
      'CREATE TABLE subjects(code TEXT PRIMARY KEY, name TEXT NOT NULL DEFAULT "")',
    );
    db.execute(
      'CREATE TABLE syllabi(syllabus_id INTEGER PRIMARY KEY, subject_code TEXT, subject_name TEXT, syllabus_name TEXT, decision TEXT, description TEXT, source_path TEXT)',
    );
    db.execute(
      'CREATE TABLE chunks(id INTEGER PRIMARY KEY, subject_code TEXT, subject_code_norm TEXT, syllabus_id INTEGER, section TEXT, session_number INTEGER, title TEXT, content TEXT, source_path TEXT)',
    );
  }
}
