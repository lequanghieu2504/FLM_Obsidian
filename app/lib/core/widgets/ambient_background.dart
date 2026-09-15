import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AmbientBackground extends StatelessWidget {
  const AmbientBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!isDark) {
      return Container(color: AppColors.lightBackground, child: child);
    }

    return Stack(
      children: [
        // Solid Deep Cosmic Space Base
        Positioned.fill(child: Container(color: AppColors.darkBackground)),

        // Ambient Radial Glow Orb Top Left (Deep Amethyst Violet)
        Positioned(
          top: -120,
          left: -100,
          child: Container(
            width: 450,
            height: 450,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF8B5CF6).withValues(alpha: 0.18),
                  const Color(0xFF6D28D9).withValues(alpha: 0.08),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),

        // Ambient Radial Glow Orb Top Right / Middle (Cyber Cyan)
        Positioned(
          top: 180,
          right: -120,
          child: Container(
            width: 500,
            height: 500,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF06B6D4).withValues(alpha: 0.14),
                  const Color(0xFF0284C7).withValues(alpha: 0.06),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),

        // Ambient Radial Glow Orb Bottom Left (Emerald Accent)
        Positioned(
          bottom: -150,
          left: 200,
          child: Container(
            width: 400,
            height: 400,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF10B981).withValues(alpha: 0.12),
                  Colors.transparent,
                ],
                stops: const [0.0, 1.0],
              ),
            ),
          ),
        ),

        // Main Page Content Layer
        Positioned.fill(child: child),
      ],
    );
  }
}
