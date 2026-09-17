import '../core/network/api_client.dart';
import '../models/graph.dart';

class GraphRepository {
  const GraphRepository(this.apiClient);

  final ApiClient apiClient;

  Future<KnowledgeGraph> globalGraph() async {
    final json = await apiClient.getJson('/api/graph', {'limit': 1200});
    return KnowledgeGraph.fromJson(json as Map<String, dynamic>);
  }

  Future<KnowledgeGraph> subjectGraph(
    String subjectCode, {
    int depth = 3,
  }) async {
    final json = await apiClient.getJson('/api/graph/subject/$subjectCode', {
      'depth': depth,
    });
    return KnowledgeGraph.fromJson(json as Map<String, dynamic>);
  }
}
