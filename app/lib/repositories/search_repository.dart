import '../models/search_result.dart';
import '../core/network/api_client.dart';

class SearchRepository {
  const SearchRepository(this.apiClient);

  final ApiClient apiClient;

  Future<List<SearchResult>> search({
    required String query,
    String? subjectCode,
    String? section,
    int? sessionNumber,
    int limit = 8,
  }) async {
    return [
      for (final item in await apiClient.getJson('/api/search', {
        'q': query,
        'subject_code': subjectCode,
        'section': section,
        'limit': limit,
      }) as List<dynamic>)
        SearchResult.fromJson(item as Map<String, dynamic>),
    ];
  }
}
