import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/stat_card.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero Cosmic Knowledge Vault Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: isDark
                  ? AppColors.heroGradientDark
                  : AppColors.heroGradientLight,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                    ? AppColors.primaryViolet.withValues(alpha: 0.3)
                    : AppColors.lightBorder,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryViolet.withValues(
                    alpha: isDark ? 0.2 : 0.05,
                  ),
                  blurRadius: 28,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryViolet.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.primaryViolet.withValues(alpha: 0.4),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 14,
                            color: AppColors.primaryViolet,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Obsidian Intelligence Core',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryViolet,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ShaderMask(
                  shaderCallback: (bounds) =>
                      AppColors.crystalGradient.createShader(bounds),
                  child: const Text(
                    'FLM Knowledge Studio',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Standalone desktop browser and BYOK intelligent chat client connected to your local syllabus database.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF94A3B8),
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Metrics Grid Row
          LayoutBuilder(
            builder: (context, constraints) {
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: 240,
                    child: StatCard(
                      title: 'Syllabus Subjects',
                      value: '120+',
                      subtitle: 'Active Curricula',
                      icon: Icons.menu_book_rounded,
                      gradient: AppColors.primaryGradient,
                    ),
                  ),
                  SizedBox(
                    width: 240,
                    child: StatCard(
                      title: 'Syllabus Chunks',
                      value: '3,450+',
                      subtitle: 'FTS Indexed',
                      icon: Icons.manage_search_rounded,
                      gradient: AppColors.cyanGradient,
                    ),
                  ),
                  SizedBox(
                    width: 240,
                    child: StatCard(
                      title: 'Knowledge Nodes',
                      value: '1,890',
                      subtitle: 'Constellation Edges',
                      icon: Icons.hub_rounded,
                      gradient: AppColors.emeraldGradient,
                    ),
                  ),
                  SizedBox(
                    width: 240,
                    child: StatCard(
                      title: 'LLM Engine',
                      value: 'BYOK Active',
                      subtitle: 'OpenAI Compatible',
                      icon: Icons.auto_awesome_rounded,
                      gradient: AppColors.crystalGradient,
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 32),

          // Section Title
          const Text(
            'Studio Vault Explorer',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Select a portal to explore subjects, search content, view relationships, or converse with AI.',
            style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
          ),

          const SizedBox(height: 18),

          // Action Portals Grid
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _ActionCard(
                icon: Icons.menu_book_rounded,
                title: 'Browse Subjects Catalog',
                description: 'Explore full course syllabi, credits, learning outcomes, assessment schemes, and weekly schedules.',
                color: AppColors.primaryViolet,
              ),
              _ActionCard(
                icon: Icons.manage_search_rounded,
                title: 'Full-Text Syllabus Search',
                description: 'Search syllabus content, session topics, and learning materials across all subjects instantly.',
                color: AppColors.primaryCyan,
              ),
              _ActionCard(
                icon: Icons.hub_rounded,
                title: 'Interactive Knowledge Network',
                description: 'Visualize prerequisite links, subject relations, and concept nodes in a dynamic 2D canvas view.',
                color: AppColors.primaryIndigo,
              ),
              _ActionCard(
                icon: Icons.auto_awesome_rounded,
                title: 'Ask BYOK AI Studio',
                description: 'Converse with your LLM using context retrieved directly from local syllabus knowledge chunks.',
                color: AppColors.accentEmerald,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 380,
      child: GlassCard(
        hoverable: true,
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: color.withValues(alpha: 0.35)),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: color.withValues(alpha: 0.7),
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF94A3B8),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
