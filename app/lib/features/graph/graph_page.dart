// ignore_for_file: deprecated_member_use
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/badge_tag.dart';
import '../../core/widgets/glass_card.dart';
import '../../models/graph.dart';
import '../../repositories/providers.dart';
import '../syllabus/syllabus_detail_page.dart';

class GraphPage extends ConsumerStatefulWidget {
  const GraphPage({super.key});

  @override
  ConsumerState<GraphPage> createState() => _GraphPageState();
}

class _GraphPageState extends ConsumerState<GraphPage> {
  final controller = TextEditingController(text: 'JPD111');
  late Future<KnowledgeGraph> graph = _loadSubject();
  GraphNode? selected;
  final transformationController = TransformationController();

  Future<KnowledgeGraph> _loadSubject() {
    return ref
        .read(graphRepositoryProvider)
        .subjectGraph(controller.text.trim());
  }

  @override
  void dispose() {
    controller.dispose();
    transformationController.dispose();
    super.dispose();
  }

  void _triggerLoad() {
    setState(() {
      selected = null;
      graph = _loadSubject();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header section
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Knowledge Graph Visualizer',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Interactive 2D graph view of subject relations, prerequisites, and learning concepts.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              // Search Input Row
              SizedBox(
                width: 220,
                child: TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.hub_rounded),
                    hintText: 'Subject code...',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  onSubmitted: (_) => _triggerLoad(),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: _triggerLoad,
                icon: const Icon(Icons.manage_search_rounded, size: 18),
                label: const Text('Render Graph'),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Main Graph Canvas Area + Side Inspector
          Expanded(
            child: FutureBuilder<KnowledgeGraph>(
              future: graph,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: GlassCard(
                      child: Text(
                        'Backend Error: ${snapshot.error}',
                        style: const TextStyle(color: AppColors.accentRose),
                      ),
                    ),
                  );
                }
                final data = snapshot.data;
                if (data == null || data.nodes.isEmpty) {
                  return Center(
                    child: GlassCard(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.bubble_chart_outlined,
                            size: 48,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No graph data found for "${controller.text}".',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Stack(
                  children: [
                    // Canvas Grid View
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF060911)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                          ),
                        ),
                        child: Stack(
                          children: [
                            // Custom Painter Canvas with InteractiveViewer
                            Positioned.fill(
                              child: _GraphCanvas(
                                graph: data,
                                selected: selected,
                                transformationController:
                                    transformationController,
                                onSelected: (node) =>
                                    setState(() => selected = node),
                              ),
                            ),

                            // Floating Toolbar Top Left (Legend)
                            Positioned(
                              top: 16,
                              left: 16,
                              child: GlassCard(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                borderRadius: 12,
                                child: Row(
                                  children: [
                                    _LegendDot(
                                      color: AppColors.primaryViolet,
                                      label:
                                          'Subject (${data.nodes.where((n) => n.type == "Subject").length})',
                                    ),
                                    const SizedBox(width: 16),
                                    _LegendDot(
                                      color: AppColors.primaryCyan,
                                      label:
                                          'Concept/Chunk (${data.nodes.where((n) => n.type != "Subject").length})',
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Zoom Controls Bottom Right
                            Positioned(
                              bottom: 16,
                              right: selected != null ? 310 : 16,
                              child: GlassCard(
                                padding: const EdgeInsets.all(6),
                                borderRadius: 12,
                                child: Column(
                                  children: [
                                    IconButton(
                                      tooltip: 'Zoom In',
                                      icon: const Icon(
                                        Icons.add_rounded,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        transformationController.value =
                                            Matrix4.copy(
                                              transformationController.value,
                                            )..scale(1.2);
                                      },
                                    ),
                                    IconButton(
                                      tooltip: 'Zoom Out',
                                      icon: const Icon(
                                        Icons.remove_rounded,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        transformationController.value =
                                            Matrix4.copy(
                                              transformationController.value,
                                            )..scale(0.8);
                                      },
                                    ),
                                    IconButton(
                                      tooltip: 'Reset Canvas View',
                                      icon: const Icon(
                                        Icons.center_focus_strong_rounded,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        transformationController.value =
                                            Matrix4.identity();
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Side Inspector Panel (Slides out when a node is clicked)
                    if (selected != null)
                      Positioned(
                        top: 16,
                        bottom: 16,
                        right: 16,
                        width: 280,
                        child: GlassCard(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  BadgeTag(
                                    label: selected!.type,
                                    style: selected!.type == 'Subject'
                                        ? BadgeStyle.primary
                                        : BadgeStyle.cyan,
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 18,
                                    ),
                                    onPressed: () =>
                                        setState(() => selected = null),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                selected!.label,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Node ID: ${selected!.id}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                              const Divider(height: 24),
                              const Text(
                                'Connections:',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: ListView(
                                  children: [
                                    for (final edge in data.edges.where(
                                      (e) =>
                                          e.source == selected!.id ||
                                          e.target == selected!.id,
                                    ))
                                      ListTile(
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                        leading: const Icon(
                                          Icons.arrow_right_alt_rounded,
                                          size: 18,
                                        ),
                                        title: Text(
                                          edge.source == selected!.id
                                              ? '-> ${edge.target}'
                                              : '<- ${edge.source}',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (selected!.type == 'Subject')
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => SyllabusDetailPage(
                                            subjectCode: selected!.label,
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.open_in_new_rounded,
                                      size: 16,
                                    ),
                                    label: const Text('Open Subject Detail'),
                                  ),
                                ),
                            ],
                          ),
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
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

class _GraphCanvas extends StatelessWidget {
  const _GraphCanvas({
    required this.graph,
    required this.selected,
    required this.transformationController,
    required this.onSelected,
  });

  final KnowledgeGraph graph;
  final GraphNode? selected;
  final TransformationController transformationController;
  final ValueChanged<GraphNode> onSelected;

  @override
  Widget build(BuildContext context) {
    final layout = _GraphLayout(graph);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTapUp: (details) {
        final box = context.findRenderObject() as RenderBox;
        final local = box.globalToLocal(details.globalPosition);
        final transformedPoint = transformationController.toScene(local);
        final node = layout.hitTest(transformedPoint);
        if (node != null) {
          onSelected(node);
        }
      },
      child: InteractiveViewer(
        transformationController: transformationController,
        minScale: 0.3,
        maxScale: 4.0,
        boundaryMargin: const EdgeInsets.all(1000),
        child: CustomPaint(
          size: const Size(1400, 900),
          painter: _GraphPainter(
            layout: layout,
            selected: selected,
            isDark: isDark,
          ),
        ),
      ),
    );
  }
}

class _GraphLayout {
  _GraphLayout(this.graph) {
    final count = math.max(graph.nodes.length, 1);
    const center = Offset(700, 450);
    const radius = 320.0;
    for (var i = 0; i < graph.nodes.length; i++) {
      final node = graph.nodes[i];
      final angle = (2 * math.pi * i) / count;
      final r = node.type == 'Subject' ? radius * 0.85 : radius * 0.55;
      positions[node.id] = Offset(
        center.dx + math.cos(angle) * r,
        center.dy + math.sin(angle) * r,
      );
    }
  }

  final KnowledgeGraph graph;
  final positions = <String, Offset>{};

  GraphNode? hitTest(Offset point) {
    for (final node in graph.nodes.reversed) {
      final position = positions[node.id];
      if (position != null && (position - point).distance <= 32) {
        return node;
      }
    }
    return null;
  }
}

class _GraphPainter extends CustomPainter {
  const _GraphPainter({
    required this.layout,
    required this.selected,
    required this.isDark,
  });

  final _GraphLayout layout;
  final GraphNode? selected;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    // Draw background grid lines
    final gridPaint = Paint()
      ..color = isDark
          ? const Color(0xFF1E293B).withValues(alpha: 0.4)
          : const Color(0xFFE2E8F0).withValues(alpha: 0.7)
      ..strokeWidth = 1;

    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Draw Edges
    final edgePaint = Paint()
      ..color = isDark
          ? const Color(0xFF64748B).withValues(alpha: 0.4)
          : const Color(0xFF94A3B8).withValues(alpha: 0.5)
      ..strokeWidth = 1.5;

    for (final edge in layout.graph.edges) {
      final source = layout.positions[edge.source];
      final target = layout.positions[edge.target];
      if (source != null && target != null) {
        canvas.drawLine(source, target, edgePaint);
      }
    }

    // Draw Nodes
    for (final node in layout.graph.nodes) {
      final position = layout.positions[node.id]!;
      final isSelected = node.id == selected?.id;

      final baseColor = node.type == 'Subject'
          ? AppColors.primaryViolet
          : AppColors.primaryCyan;

      // Glow / Selection Ring
      if (isSelected) {
        final selectionGlow = Paint()
          ..color = AppColors.primaryCyan.withValues(alpha: 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
        canvas.drawCircle(position, 34, selectionGlow);

        final selectionBorder = Paint()
          ..color = AppColors.primaryCyan
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5;
        canvas.drawCircle(position, 32, selectionBorder);
      }

      // Node Body Circle
      final fill = Paint()
        ..shader = RadialGradient(
          colors: [baseColor.withValues(alpha: 0.9), baseColor],
        ).createShader(Rect.fromCircle(center: position, radius: 24));

      canvas.drawCircle(position, isSelected ? 26 : 22, fill);

      // Node Label Box
      final textSpan = TextSpan(
        text: node.label,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 140);

      final labelBg = Paint()
        ..color = isDark
            ? const Color(0xFF0F172A).withValues(alpha: 0.85)
            : Colors.white.withValues(alpha: 0.9)
        ..style = PaintingStyle.fill;

      final textRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          position.dx + 30,
          position.dy - 10,
          textPainter.width + 12,
          textPainter.height + 6,
        ),
        const Radius.circular(6),
      );

      canvas.drawRRect(textRect, labelBg);
      canvas.drawRRect(
        textRect,
        Paint()
          ..color = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );

      textPainter.paint(canvas, position + const Offset(36, -7));
    }
  }

  @override
  bool shouldRepaint(covariant _GraphPainter oldDelegate) {
    return oldDelegate.layout != layout ||
        oldDelegate.selected != selected ||
        oldDelegate.isDark != isDark;
  }
}
