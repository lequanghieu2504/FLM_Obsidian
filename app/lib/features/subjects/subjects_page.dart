import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/badge_tag.dart';
import '../../core/widgets/glass_card.dart';
import '../../models/subject.dart';
import '../../repositories/providers.dart';
import '../syllabus/syllabus_detail_page.dart';

class SubjectsPage extends ConsumerStatefulWidget {
  const SubjectsPage({super.key});

  @override
  ConsumerState<SubjectsPage> createState() => _SubjectsPageState();
}

class _SubjectsPageState extends ConsumerState<SubjectsPage> {
  final controller = TextEditingController();
  int page = 1;
  late Future<SubjectList> subjects = _load();

  Future<SubjectList> _load() {
    return ref
        .read(subjectRepositoryProvider)
        .listSubjects(filter: controller.text, page: page);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _triggerSearch() {
    setState(() {
      page = 1;
      subjects = _load();
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Subjects Catalog',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Browse and filter academic subjects captured in local syllabus store.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              BadgeTag(
                label: 'Page $page',
                style: BadgeStyle.primary,
                icon: Icons.auto_stories_rounded,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Search Filter Bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () {
                              controller.clear();
                              _triggerSearch();
                            },
                          )
                        : null,
                    hintText: 'Search by subject code (e.g., JPD111, PRM393) or title...',
                  ),
                  onSubmitted: (_) => _triggerSearch(),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _triggerSearch,
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: const Text('Filter'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Subjects List View
          Expanded(
            child: FutureBuilder<SubjectList>(
              future: subjects,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: GlassCard(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 40,
                            color: AppColors.accentRose,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Backend Error: ${snapshot.error}',
                            style: const TextStyle(color: AppColors.accentRose),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final data = snapshot.data;
                final rows = data?.items ?? const <Subject>[];

                if (rows.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.folder_off_rounded,
                          size: 48,
                          color: isDark
                              ? const Color(0xFF475569)
                              : const Color(0xFF94A3B8),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No matching subjects found.',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    Expanded(
                      child: ListView.separated(
                        itemCount: rows.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final subject = rows[index];
                          return GlassCard(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            hoverable: true,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => SyllabusDetailPage(
                                  subjectCode: subject.code,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                BadgeTag(
                                  label: subject.code,
                                  style: BadgeStyle.cyan,
                                  fontSize: 13,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        subject.name,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF1E2638)
                                        : const Color(0xFFE2E8F0),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 13,
                                    color: isDark
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Pagination Control Bar
                    GlassCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total ${data?.total ?? 0} subjects recorded',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                'Page $page of ${_totalPages(data)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 12),
                              IconButton.outlined(
                                tooltip: 'Previous page',
                                onPressed: page <= 1
                                    ? null
                                    : () => setState(() {
                                        page -= 1;
                                        subjects = _load();
                                      }),
                                icon: const Icon(
                                  Icons.chevron_left_rounded,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 6),
                              IconButton.outlined(
                                tooltip: 'Next page',
                                onPressed: page >= _totalPages(data)
                                    ? null
                                    : () => setState(() {
                                        page += 1;
                                        subjects = _load();
                                      }),
                                icon: const Icon(
                                  Icons.chevron_right_rounded,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ],
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

  int _totalPages(SubjectList? data) {
    if (data == null || data.total == 0) {
      return 1;
    }
    return (data.total / data.pageSize).ceil();
  }
}
