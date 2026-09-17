class KnowledgeGraph {
  const KnowledgeGraph({required this.nodes, required this.edges});

  factory KnowledgeGraph.fromJson(Map<String, dynamic> json) {
    return KnowledgeGraph(
      nodes: [
        for (final item in json['nodes'] as List<dynamic>? ?? const [])
          GraphNode.fromJson(item as Map<String, dynamic>),
      ],
      edges: [
        for (final item in json['edges'] as List<dynamic>? ?? const [])
          GraphEdge.fromJson(item as Map<String, dynamic>),
      ],
    );
  }

  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
}

class GraphNode {
  const GraphNode({
    required this.id,
    required this.type,
    required this.label,
    this.name,
  });

  factory GraphNode.fromJson(Map<String, dynamic> json) {
    return GraphNode(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      label: json['label'] as String? ?? '',
      name: json['name'] as String?,
    );
  }

  final String id;
  final String type;
  final String label;
  final String? name;
}

class GraphEdge {
  const GraphEdge({
    required this.source,
    required this.target,
    required this.type,
  });

  factory GraphEdge.fromJson(Map<String, dynamic> json) {
    return GraphEdge(
      source: json['source'] as String? ?? '',
      target: json['target'] as String? ?? '',
      type: json['type'] as String? ?? '',
    );
  }

  final String source;
  final String target;
  final String type;
}
