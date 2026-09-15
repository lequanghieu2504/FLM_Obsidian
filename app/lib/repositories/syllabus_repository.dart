import '../models/syllabus.dart';
import '../core/network/api_client.dart';
import '../models/subject.dart';

class SyllabusRepository {
  const SyllabusRepository(this.apiClient);

  final ApiClient apiClient;

  Future<List<Syllabus>> bySubject(String subjectCode) async {
    final json = await apiClient.getJson('/api/subjects/$subjectCode');
    return SubjectDetail.fromJson(json as Map<String, dynamic>).syllabi;
  }
}
