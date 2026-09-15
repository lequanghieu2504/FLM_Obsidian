import '../models/subject.dart';
import '../core/network/api_client.dart';

class SubjectRepository {
  const SubjectRepository(this.apiClient);

  final ApiClient apiClient;

  Future<SubjectList> listSubjects({
    String filter = '',
    int page = 1,
    int pageSize = 50,
  }) async {
    final json = await apiClient.getJson('/api/subjects', {
      'q': filter,
      'page': page,
      'page_size': pageSize,
    });
    return SubjectList.fromJson(json as Map<String, dynamic>);
  }

  Future<SubjectDetail> getSubject(String subjectCode) async {
    final json = await apiClient.getJson('/api/subjects/$subjectCode');
    return SubjectDetail.fromJson(json as Map<String, dynamic>);
  }

  Future<List<ScheduleItem>> schedule(String subjectCode) async {
    final json = await apiClient.getJson('/api/subjects/$subjectCode/schedule');
    return [
      for (final item in json as List<dynamic>)
        ScheduleItem.fromJson(item as Map<String, dynamic>),
    ];
  }
}
