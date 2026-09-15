import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../services/key_storage_service.dart';
import '../services/llm_service.dart';
import '../services/retrieval_service.dart';
import 'graph_repository.dart';
import 'knowledge_database.dart';
import 'search_repository.dart';
import 'subject_repository.dart';
import 'syllabus_repository.dart';

final apiClientProvider = Provider((ref) => ApiClient());
final knowledgeDatabaseProvider = Provider((ref) => KnowledgeDatabase());
final subjectRepositoryProvider = Provider(
  (ref) => SubjectRepository(ref.watch(apiClientProvider)),
);
final syllabusRepositoryProvider = Provider(
  (ref) => SyllabusRepository(ref.watch(apiClientProvider)),
);
final searchRepositoryProvider = Provider(
  (ref) => SearchRepository(ref.watch(apiClientProvider)),
);
final retrievalServiceProvider = Provider(
  (ref) => RetrievalService(ref.watch(apiClientProvider)),
);
final graphRepositoryProvider = Provider(
  (ref) => GraphRepository(ref.watch(apiClientProvider)),
);
final keyStorageServiceProvider = Provider((ref) => KeyStorageService());
final llmServiceProvider = Provider((ref) => OpenAICompatibleLlmService());
