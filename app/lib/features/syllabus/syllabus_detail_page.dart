import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/badge_tag.dart';
import '../../core/widgets/glass_card.dart';
import '../../models/subject.dart';
import '../../repositories/providers.dart';
import '../chat/embedded_chat_widget.dart';

class SyllabusDetailPage extends ConsumerWidget {
  const SyllabusDetailPage({required this.subjectCode, super.key});

  final String subjectCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            BadgeTag(label: subjectCode, style: BadgeStyle.cyan, fontSize: 14),
            const SizedBox(width: 12),
            const Text(
              'Syllabus Details',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      body: FutureBuilder<SubjectDetail>(
        future: ref.read(subjectRepositoryProvider).getSubject(subjectCode),
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
          final detail = snapshot.data;
          if (detail == null || detail.syllabi.isEmpty) {
            return Center(
              child: GlassCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.menu_book_outlined,
                      size: 40,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No syllabus versions found for $subjectCode.',
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

          final syllabus = detail.syllabi.first;

          final detailView = ListView(
            padding: const EdgeInsets.all(28),
            children: [
              // Hero Subject Banner Card
              GlassCard(
                padding: const EdgeInsets.all(24),
                gradient: isDark
                    ? AppColors.heroGradientDark
                    : AppColors.heroGradientLight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        BadgeTag(
                          label: 'SYL-${syllabus.syllabusId}',
                          style: BadgeStyle.primary,
                        ),
                        const SizedBox(width: 8),
                        BadgeTag(
                          label: '${syllabus.credits} Credits',
                          style: BadgeStyle.emerald,
                          icon: Icons.star_rounded,
                        ),
                        if (syllabus.degreeLevel.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          BadgeTag(
                            label: syllabus.degreeLevel,
                            style: BadgeStyle.cyan,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      detail.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _InfoGrid(
                      values: {
                        'Prerequisite': syllabus.prerequisite,
                        'Decision': syllabus.decision,
                        'Time Allocation': syllabus.timeAllocation,
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Description Section Card
              if (syllabus.description.isNotEmpty)
                _SectionCard(
                  title: 'Course Description',
                  icon: Icons.description_rounded,
                  iconColor: AppColors.primaryIndigo,
                  child: Text(
                    syllabus.description,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              // Learning Outcomes Section Card
              _RecordSection(
                title: 'Learning Outcomes (CLO)',
                icon: Icons.track_changes_rounded,
                iconColor: AppColors.primaryCyan,
                records: detail.learningOutcomes,
              ),

              const SizedBox(height: 20),

              // Assessment Scheme Section Card
              _RecordSection(
                title: 'Assessment Breakdown',
                icon: Icons.grading_rounded,
                iconColor: AppColors.accentAmber,
                records: detail.assessment,
              ),

              const SizedBox(height: 20),

              // Weekly Schedule Section
              FutureBuilder<List<ScheduleItem>>(
                future: ref
                    .read(subjectRepositoryProvider)
                    .schedule(subjectCode),
                builder: (context, scheduleSnapshot) =>
                    _ScheduleSection(items: scheduleSnapshot.data ?? const []),
              ),

              const SizedBox(height: 20),

              // Materials & Textbooks Section
              _RecordSection(
                title: 'Textbooks & Learning Materials',
                icon: Icons.collections_bookmark_rounded,
                iconColor: AppColors.primaryIndigo,
                records: detail.materials,
              ),
            ],
          );

          return LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 700) {
                return detailView;
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 7,
                    child: detailView,
                  ),
                  Expanded(
                    flex: 3,
                    child: EmbeddedChatWidget(subjectCode: subjectCode),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _InfoGrid extends StatelessWidget {
  const _InfoGrid({required this.values});

  final Map<String, String> values;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 12,
      children: [
        for (final entry in values.entries)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${entry.key}: ',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                Text(
                  entry.value.isEmpty ? 'None required' : entry.value,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _RecordSection extends StatelessWidget {
  const _RecordSection({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.records,
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final List<Map<String, String>> records;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _SectionCard(
      title: title,
      icon: icon,
      iconColor: iconColor,
      child: records.isEmpty
          ? const Text(
              'No records captured.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            )
          : Column(
              children: [
                for (final record in records)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF131722)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF1E2638)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.values.take(2).join(' • '),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (record.length > 2) ...[
                          const SizedBox(height: 6),
                          Text(
                            record.entries
                                .skip(2)
                                .map((e) => '${e.key}: ${e.value}')
                                .join('  |  '),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _ScheduleSection extends StatelessWidget {
  const _ScheduleSection({required this.items});

  final List<ScheduleItem> items;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Weekly Schedule Timeline',
      icon: Icons.event_note_rounded,
      iconColor: AppColors.accentEmerald,
      child: items.isEmpty
          ? const Text(
              'No schedule items captured.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            )
          : Column(
              children: [
                for (int i = 0; i < items.take(15).length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accentEmerald.withValues(
                              alpha: 0.15,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'S${i + 1}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.accentEmerald,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                items[i].title,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                items[i].content,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF94A3B8),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
