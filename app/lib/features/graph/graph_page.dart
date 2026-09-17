import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../../models/graph.dart';
import '../../repositories/providers.dart';
import '../syllabus/syllabus_detail_page.dart';

enum _GraphScope { prerequisites, dependents, both }

Matrix4 _viewportTransform(double scale, double dx, double dy) {
  return Matrix4.identity()
    ..setEntry(0, 0, scale)
    ..setEntry(1, 1, scale)
    ..setEntry(0, 3, dx)
    ..setEntry(1, 3, dy);
}

class GraphPage extends ConsumerStatefulWidget {
  const GraphPage({super.key});

  @override
  ConsumerState<GraphPage> createState() => _GraphPageState();
}

class _GraphPageState extends ConsumerState<GraphPage> {
  final searchController = TextEditingController(text: 'JPD326');
  final transformationController = TransformationController();
  final canvasKey = GlobalKey();
  late Future<KnowledgeGraph> graph = _loadSubject('JPD326');
  String rootCode = 'JPD326';
  String? selectedId = 'subject:JPD326';
  _GraphScope scope = _GraphScope.both;
  _HierarchicalLayout? currentLayout;

  Future<KnowledgeGraph> _loadSubject(String code) =>
      ref.read(graphRepositoryProvider).subjectGraph(code, depth: 3);

  @override
  void dispose() {
    searchController.dispose();
    transformationController.dispose();
    super.dispose();
  }

  void _search() {
    final code = searchController.text.trim().toUpperCase().replaceAll(' ', '');
    if (code.isEmpty) return;
    searchController.text = code;
    setState(() {
      rootCode = code;
      selectedId = 'subject:$code';
      scope = _GraphScope.both;
      currentLayout = null;
      graph = _loadSubject(code);
    });
  }

  void _reset() {
    setState(() {
      scope = _GraphScope.both;
      selectedId = 'subject:$rootCode';
      currentLayout = null;
    });
  }

  Size? get _viewportSize {
    final box = canvasKey.currentContext?.findRenderObject() as RenderBox?;
    return box?.hasSize == true ? box!.size : null;
  }

  void _fitToScreen() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final layout = currentLayout;
      final viewport = _viewportSize;
      if (!mounted || layout == null || viewport == null) return;
      final scale =
          (math.min(
                    viewport.width / layout.size.width,
                    viewport.height / layout.size.height,
                  ) *
                  0.9)
              .clamp(0.25, 1.25);
      final dx = (viewport.width - layout.size.width * scale) / 2;
      final dy = (viewport.height - layout.size.height * scale) / 2;
      transformationController.value = _viewportTransform(scale, dx, dy);
    });
  }

  void _centerSelected() {
    final layout = currentLayout;
    final viewport = _viewportSize;
    final center = layout?.centers[selectedId];
    if (layout == null || viewport == null || center == null) return;
    final scale = transformationController.value.getMaxScaleOnAxis().clamp(
      0.25,
      4.0,
    );
    transformationController.value = _viewportTransform(
      scale,
      viewport.width / 2 - center.dx * scale,
      viewport.height / 2 - center.dy * scale,
    );
  }

  void _zoom(double factor) {
    final viewport = _viewportSize;
    if (viewport == null) return;
    final oldScale = transformationController.value.getMaxScaleOnAxis();
    final newScale = (oldScale * factor).clamp(0.25, 4.0);
    final sceneCenter = transformationController.toScene(
      Offset(viewport.width / 2, viewport.height / 2),
    );
    transformationController.value = _viewportTransform(
      newScale,
      viewport.width / 2 - sceneCenter.dx * newScale,
      viewport.height / 2 - sceneCenter.dy * newScale,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Prerequisite Graph',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'A → B means A must be passed before B.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 16),
          _buildControls(),
          const SizedBox(height: 14),
          Expanded(
            child: FutureBuilder<KnowledgeGraph>(
              future: graph,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Could not load graph: ${snapshot.error}',
                      style: const TextStyle(color: AppColors.accentRose),
                    ),
                  );
                }
                final fullGraph = snapshot.data;
                if (fullGraph == null || fullGraph.nodes.isEmpty) {
                  return Center(
                    child: Text('No dependency data found for $rootCode.'),
                  );
                }
                final visibleGraph = _visibleGraph(fullGraph);
                final selected =
                    _nodeById(fullGraph, selectedId) ??
                    _nodeById(fullGraph, 'subject:$rootCode');
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _buildCanvas(visibleGraph, selected, isDark),
                    ),
                    const SizedBox(width: 14),
                    SizedBox(
                      width: 300,
                      child: _SubjectPanel(
                        graph: fullGraph,
                        node: selected,
                        onSelect: (id) {
                          setState(() => selectedId = id);
                          WidgetsBinding.instance.addPostFrameCallback(
                            (_) => _centerSelected(),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 250,
          child: TextField(
            controller: searchController,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'Search subject code',
              isDense: true,
            ),
            onSubmitted: (_) => _search(),
          ),
        ),
        FilledButton.icon(
          onPressed: _search,
          icon: const Icon(Icons.account_tree_outlined, size: 18),
          label: const Text('Load'),
        ),
        SegmentedButton<_GraphScope>(
          segments: const [
            ButtonSegment(
              value: _GraphScope.prerequisites,
              label: Text('Show prerequisites'),
            ),
            ButtonSegment(
              value: _GraphScope.dependents,
              label: Text('Show dependents'),
            ),
            ButtonSegment(value: _GraphScope.both, label: Text('Show both')),
          ],
          selected: {scope},
          onSelectionChanged: (value) {
            setState(() {
              scope = value.first;
              currentLayout = null;
            });
          },
        ),
        OutlinedButton.icon(
          onPressed: _reset,
          icon: const Icon(Icons.restart_alt_rounded, size: 18),
          label: const Text('Reset'),
        ),
      ],
    );
  }

  Widget _buildCanvas(
    KnowledgeGraph visibleGraph,
    GraphNode? selected,
    bool isDark,
  ) {
    return Container(
      key: canvasKey,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF070A12) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: _GraphCanvas(
              graph: visibleGraph,
              selectedId: selected?.id,
              rootId: 'subject:$rootCode',
              transformationController: transformationController,
              onLayout: (layout) {
                final firstLayout = currentLayout == null;
                currentLayout = layout;
                if (firstLayout) _fitToScreen();
              },
              onSelected: (node) => setState(() => selectedId = node.id),
            ),
          ),
          Positioned(left: 12, top: 12, child: const _Legend()),
          Positioned(
            right: 12,
            bottom: 12,
            child: GlassCard(
              padding: const EdgeInsets.all(4),
              borderRadius: 12,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Zoom out',
                    onPressed: () => _zoom(0.8),
                    icon: const Icon(Icons.remove_rounded),
                  ),
                  IconButton(
                    tooltip: 'Zoom in',
                    onPressed: () => _zoom(1.25),
                    icon: const Icon(Icons.add_rounded),
                  ),
                  IconButton(
                    tooltip: 'Fit to screen',
                    onPressed: _fitToScreen,
                    icon: const Icon(Icons.fit_screen_rounded),
                  ),
                  IconButton(
                    tooltip: 'Center selected node',
                    onPressed: _centerSelected,
                    icon: const Icon(Icons.center_focus_strong_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  KnowledgeGraph _visibleGraph(KnowledgeGraph source) {
    final root = 'subject:$rootCode';
    final ids = <String>{root};
    if (scope != _GraphScope.dependents) {
      ids.addAll(_walk(source, root, upstream: true));
    }
    if (scope != _GraphScope.prerequisites) {
      ids.addAll(_walk(source, root, upstream: false));
    }
    return KnowledgeGraph(
      nodes: source.nodes.where((node) => ids.contains(node.id)).toList(),
      edges: source.edges
          .where(
            (edge) => ids.contains(edge.source) && ids.contains(edge.target),
          )
          .toList(),
    );
  }
}

class _GraphCanvas extends StatelessWidget {
  const _GraphCanvas({
    required this.graph,
    required this.selectedId,
    required this.rootId,
    required this.transformationController,
    required this.onLayout,
    required this.onSelected,
  });

  final KnowledgeGraph graph;
  final String? selectedId;
  final String rootId;
  final TransformationController transformationController;
  final ValueChanged<_HierarchicalLayout> onLayout;
  final ValueChanged<GraphNode> onSelected;

  @override
  Widget build(BuildContext context) {
    final layout = _HierarchicalLayout(graph, rootId: rootId);
    WidgetsBinding.instance.addPostFrameCallback((_) => onLayout(layout));
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapUp: (details) {
        final box = context.findRenderObject() as RenderBox;
        final local = box.globalToLocal(details.globalPosition);
        final node = layout.hitTest(transformationController.toScene(local));
        if (node != null) onSelected(node);
      },
      child: InteractiveViewer(
        transformationController: transformationController,
        constrained: false,
        minScale: 0.25,
        maxScale: 4,
        boundaryMargin: const EdgeInsets.all(800),
        child: CustomPaint(
          size: layout.size,
          painter: _GraphPainter(
            layout: layout,
            selectedId: selectedId,
            rootId: rootId,
            isDark: Theme.of(context).brightness == Brightness.dark,
          ),
        ),
      ),
    );
  }
}

class _HierarchicalLayout {
  _HierarchicalLayout(this.graph, {required this.rootId}) {
    final ranks = _topologicalRanks(graph);
    final layers = <int, List<GraphNode>>{};
    for (final node in graph.nodes) {
      final rank = ranks[node.id] ?? 0;
      layers.putIfAbsent(rank, () => []).add(node);
    }
    for (final nodes in layers.values) {
      nodes.sort((a, b) => a.label.compareTo(b.label));
    }
    final minRank = layers.keys.reduce(math.min);
    final maxRank = layers.keys.reduce(math.max);
    final tallest = layers.values.fold<int>(
      1,
      (value, nodes) => math.max(value, nodes.length),
    );
    size = Size(
      120 + (maxRank - minRank + 1) * 230,
      math.max(420, 100 + tallest * 82),
    );
    for (final entry in layers.entries) {
      final x = 60 + (entry.key - minRank) * 230.0;
      final totalHeight = (entry.value.length - 1) * 82.0;
      final startY = size.height / 2 - totalHeight / 2;
      for (var i = 0; i < entry.value.length; i++) {
        centers[entry.value[i].id] = Offset(x + 70, startY + i * 82);
      }
    }
  }

  static const nodeSize = Size(140, 52);
  final KnowledgeGraph graph;
  final String rootId;
  final centers = <String, Offset>{};
  late final Size size;

  Rect rectFor(String id) => Rect.fromCenter(
    center: centers[id]!,
    width: nodeSize.width,
    height: nodeSize.height,
  );

  GraphNode? hitTest(Offset point) {
    for (final node in graph.nodes.reversed) {
      if (rectFor(node.id).contains(point)) return node;
    }
    return null;
  }
}

class _GraphPainter extends CustomPainter {
  const _GraphPainter({
    required this.layout,
    required this.selectedId,
    required this.rootId,
    required this.isDark,
  });

  final _HierarchicalLayout layout;
  final String? selectedId;
  final String rootId;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final ancestors = selectedId == null
        ? <String>{}
        : _walk(layout.graph, selectedId!, upstream: true);
    final descendants = selectedId == null
        ? <String>{}
        : _walk(layout.graph, selectedId!, upstream: false);
    for (final edge in layout.graph.edges) {
      final sourceRect = layout.rectFor(edge.source);
      final targetRect = layout.rectFor(edge.target);
      final start = Offset(sourceRect.right, sourceRect.center.dy);
      final end = Offset(targetRect.left, targetRect.center.dy);
      final highlighted =
          selectedId != null &&
          ((ancestors.contains(edge.source) &&
                  (ancestors.contains(edge.target) ||
                      edge.target == selectedId)) ||
              (descendants.contains(edge.target) &&
                  (descendants.contains(edge.source) ||
                      edge.source == selectedId)));
      final color = highlighted
          ? AppColors.primaryCyan
          : isDark
          ? const Color(0xFF64748B)
          : const Color(0xFF94A3B8);
      _drawArrow(canvas, start, end, color, highlighted ? 2.4 : 1.5);
    }
    for (final node in layout.graph.nodes) {
      final rect = layout.rectFor(node.id);
      final selected = node.id == selectedId;
      final upstream = ancestors.contains(node.id);
      final downstream = descendants.contains(node.id);
      final fill = selected
          ? AppColors.primaryViolet
          : upstream
          ? const Color(0xFFF59E0B)
          : downstream
          ? AppColors.primaryCyan
          : node.id == rootId
          ? AppColors.primaryViolet.withValues(alpha: 0.72)
          : isDark
          ? const Color(0xFF172033)
          : Colors.white;
      final border = selected
          ? const Color(0xFFC4B5FD)
          : upstream
          ? const Color(0xFFFBBF24)
          : downstream
          ? const Color(0xFF22D3EE)
          : const Color(0xFF64748B);
      if (selected) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect.inflate(6), const Radius.circular(16)),
          Paint()
            ..color = AppColors.primaryViolet.withValues(alpha: 0.3)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
      }
      final rounded = RRect.fromRectAndRadius(rect, const Radius.circular(13));
      canvas.drawRRect(rounded, Paint()..color = fill);
      canvas.drawRRect(
        rounded,
        Paint()
          ..color = border
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected ? 2.5 : 1.5,
      );
      final painter = TextPainter(
        text: TextSpan(
          text: node.label,
          style: TextStyle(
            color: selected || upstream || downstream || node.id == rootId
                ? Colors.white
                : isDark
                ? const Color(0xFFF1F5F9)
                : const Color(0xFF0F172A),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: rect.width - 20);
      painter.paint(
        canvas,
        Offset(
          rect.center.dx - painter.width / 2,
          rect.center.dy - painter.height / 2,
        ),
      );
    }
  }

  void _drawArrow(
    Canvas canvas,
    Offset start,
    Offset end,
    Color color,
    double width,
  ) {
    final midX = (start.dx + end.dx) / 2;
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(midX, start.dy, midX, end.dy, end.dx, end.dy);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width,
    );
    const arrow = 9.0;
    final arrowPath = Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(end.dx - arrow, end.dy - arrow * 0.6)
      ..lineTo(end.dx - arrow, end.dy + arrow * 0.6)
      ..close();
    canvas.drawPath(arrowPath, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _GraphPainter oldDelegate) =>
      oldDelegate.layout.graph != layout.graph ||
      oldDelegate.selectedId != selectedId ||
      oldDelegate.isDark != isDark;
}

class _SubjectPanel extends StatelessWidget {
  const _SubjectPanel({
    required this.graph,
    required this.node,
    required this.onSelect,
  });

  final KnowledgeGraph graph;
  final GraphNode? node;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    if (node == null) {
      return const GlassCard(child: Center(child: Text('Select a subject')));
    }
    final prerequisites =
        graph.edges
            .where((edge) => edge.target == node!.id)
            .map((edge) => _nodeById(graph, edge.source))
            .whereType<GraphNode>()
            .toList()
          ..sort((a, b) => a.label.compareTo(b.label));
    final dependents =
        graph.edges
            .where((edge) => edge.source == node!.id)
            .map((edge) => _nodeById(graph, edge.target))
            .whereType<GraphNode>()
            .toList()
          ..sort((a, b) => a.label.compareTo(b.label));
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SUBJECT DETAILS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            node!.label,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            node!.name?.trim().isNotEmpty == true
                ? node!.name!
                : 'Subject name unavailable',
            style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
          ),
          const Divider(height: 28),
          Expanded(
            child: ListView(
              children: [
                _RelationList(
                  title: 'Direct prerequisites',
                  emptyLabel: 'No direct prerequisites',
                  nodes: prerequisites,
                  color: const Color(0xFFF59E0B),
                  icon: Icons.arrow_back_rounded,
                  onSelect: onSelect,
                ),
                const SizedBox(height: 22),
                _RelationList(
                  title: 'Dependents / unlocked',
                  emptyLabel: 'No direct dependents',
                  nodes: dependents,
                  color: AppColors.primaryCyan,
                  icon: Icons.arrow_forward_rounded,
                  onSelect: onSelect,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SyllabusDetailPage(subjectCode: node!.label),
                ),
              ),
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('Open subject'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RelationList extends StatelessWidget {
  const _RelationList({
    required this.title,
    required this.emptyLabel,
    required this.nodes,
    required this.color,
    required this.icon,
    required this.onSelect,
  });
  final String title;
  final String emptyLabel;
  final List<GraphNode> nodes;
  final Color color;
  final IconData icon;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$title (${nodes.length})',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (nodes.isEmpty)
          Text(
            emptyLabel,
            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
        for (final item in nodes)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            minLeadingWidth: 24,
            leading: Icon(icon, size: 17, color: color),
            title: Text(item.label, style: const TextStyle(fontSize: 13)),
            subtitle: item.name == null
                ? null
                : Text(
                    item.name!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11),
                  ),
            onTap: () => onSelect(item.id),
          ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      borderRadius: 10,
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LegendItem(color: AppColors.primaryViolet, label: 'Selected'),
          SizedBox(width: 14),
          _LegendItem(color: Color(0xFFF59E0B), label: 'Prerequisite'),
          SizedBox(width: 14),
          _LegendItem(color: AppColors.primaryCyan, label: 'Dependent'),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

GraphNode? _nodeById(KnowledgeGraph graph, String? id) {
  if (id == null) return null;
  for (final node in graph.nodes) {
    if (node.id == id) return node;
  }
  return null;
}

Set<String> _walk(
  KnowledgeGraph graph,
  String start, {
  required bool upstream,
}) {
  final visited = <String>{};
  final queue = <String>[start];
  while (queue.isNotEmpty) {
    final current = queue.removeAt(0);
    for (final edge in graph.edges) {
      final matches = upstream
          ? edge.target == current
          : edge.source == current;
      if (!matches) continue;
      final next = upstream ? edge.source : edge.target;
      if (visited.add(next)) queue.add(next);
    }
  }
  visited.remove(start);
  return visited;
}

Map<String, int> _topologicalRanks(KnowledgeGraph graph) {
  final indegree = {for (final node in graph.nodes) node.id: 0};
  final outgoing = <String, List<String>>{};
  for (final edge in graph.edges) {
    if (!indegree.containsKey(edge.source) ||
        !indegree.containsKey(edge.target)) {
      continue;
    }
    outgoing.putIfAbsent(edge.source, () => []).add(edge.target);
    indegree[edge.target] = indegree[edge.target]! + 1;
  }
  final ranks = {for (final node in graph.nodes) node.id: 0};
  final queue =
      indegree.entries
          .where((entry) => entry.value == 0)
          .map((entry) => entry.key)
          .toList()
        ..sort();
  while (queue.isNotEmpty) {
    final current = queue.removeAt(0);
    for (final target in outgoing[current] ?? const <String>[]) {
      ranks[target] = math.max(ranks[target]!, ranks[current]! + 1);
      indegree[target] = indegree[target]! - 1;
      if (indegree[target] == 0) {
        queue.add(target);
        queue.sort();
      }
    }
  }
  return ranks;
}
