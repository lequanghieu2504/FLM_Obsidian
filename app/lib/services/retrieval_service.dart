import '../core/network/api_client.dart';
import '../models/search_result.dart';

class RetrievalService {
  const RetrievalService(this.apiClient);

  final ApiClient apiClient;

  Future<List<SearchResult>> retrieve(String question) async {
    final json = await apiClient.postJson('/api/retrieve', {'query': question});
    final results = (json as Map<String, dynamic>)['results'] as List<dynamic>;
    return [
      for (final item in results)
        SearchResult.fromJson(item as Map<String, dynamic>),
    ];
  }
}
