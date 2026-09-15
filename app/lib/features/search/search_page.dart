import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/badge_tag.dart';
import '../../core/widgets/glass_card.dart';
import '../../models/search_result.dart';
import '../../repositories/providers.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final controller = TextEditingController();
  Future<List<SearchResult>>? results;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _search(String query) {
    if (query.trim().isEmpty) return;
    setState(() {
      controller.text = query;
      results = ref.read(searchRepositoryProvider).search(query: query);
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
          const Text(
            'Full-Text Syllabus Search',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Instant SQLite FTS query across all syllabus sections, learning outcomes, and schedule topics.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 20),

          // Search Field & Button
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
                              setState(() => results = null);
                            },
                          )
                        : null,
                    hintText: 'Enter search keywords (e.g. Flutter, Japanese, Quiz, Final Exam)...',
                  ),
                  onSubmitted: _search,
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () => _search(controller.text),
                icon: const Icon(Icons.manage_search_rounded, size: 18),
                label: const Text('Search'),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Quick Suggestion Chips
          Row(
            children: [
              const Text(
                'Suggestions:',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(width: 8),
              Wrap(
                spacing: 6,
                children: [
                  _SuggestionChip(
                    label: 'PRM393',
                    onTap: () => _search('PRM393'),
                  ),
                  _SuggestionChip(
                    label: 'JPD111',
                    onTap: () => _search('JPD111'),
                  ),
                  _SuggestionChip(
                    label: 'Assessment',
                    onTap: () => _search('Assessment'),
                  ),
                  _SuggestionChip(
                    label: 'Schedule',
                    onTap: () => _search('Schedule'),
                  ),
                  _SuggestionChip(
                    label: 'Prerequisite',
                    onTap: () => _search('Prerequisite'),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Search Results
          Expanded(
            child: FutureBuilder<List<SearchResult>>(
              future: results,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: GlassCard(
                      child: Text(
                        'Backend Search Error: ${snapshot.error}',
                        style: const TextStyle(color: AppColors.accentRose),
                      ),
                    ),
                  );
                }
                final rows = snapshot.data;
                if (rows == null) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 56,
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFCBD5E1),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Type a query above to search syllabus chunks',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (rows.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.youtube_searched_for_rounded,
                          size: 48,
                          color: AppColors.accentAmber,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No results matching "${controller.text}"',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Found ${rows.length} syllabus chunks',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryViolet,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.separated(
                        itemCount: rows.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = rows[index];
                          return GlassCard(
                            padding: const EdgeInsets.all(18),
                            hoverable: true,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    BadgeTag(
                                      label: item.subjectCode,
                                      style: BadgeStyle.cyan,
                                    ),
                                    const SizedBox(width: 8),
                                    BadgeTag(
                                      label: item.section,
                                      style: BadgeStyle.primary,
                                    ),
                                    if (item.sessionNumber != null) ...[
                                      const SizedBox(width: 8),
                                      BadgeTag(
                                        label: 'Session ${item.sessionNumber}',
                                        style: BadgeStyle.amber,
                                        icon: Icons.event_note_rounded,
                                      ),
                                    ],
                                    const Spacer(),
                                    Text(
                                      item.title,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF94A3B8),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Snippet Content Box with left quote border
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? AppColors.darkBackground
                                        : AppColors.lightBackground,
                                    borderRadius: BorderRadius.circular(10),
                                    border: const Border(
                                      left: BorderSide(
                                        color: AppColors.primaryViolet,
                                        width: 3,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    item.snippet?.isNotEmpty == true
                                        ? item.snippet!
                                        : item.content,
                                    maxLines: 4,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      height: 1.5,
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.insert_drive_file_outlined,
                                      size: 14,
                                      color: Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        item.sourcePath,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF64748B),
                                          fontFamily: 'monospace',
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
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
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primaryViolet.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primaryViolet.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.primaryViolet,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
