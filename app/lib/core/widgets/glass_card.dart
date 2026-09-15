import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class GlassCard extends StatefulWidget {
  const GlassCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 18,
    this.onTap,
    this.borderColor,
    this.backgroundColor,
    this.gradient,
    this.hoverable = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final VoidCallback? onTap;
  final Color? borderColor;
  final Color? backgroundColor;
  final Gradient? gradient;
  final bool hoverable;

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final defaultBorder = isDark
        ? (isHovered && widget.hoverable
              ? AppColors.primaryViolet.withValues(alpha: 0.6)
              : AppColors.darkBorder)
        : (isHovered && widget.hoverable
              ? AppColors.primaryViolet.withValues(alpha: 0.5)
              : AppColors.lightBorder);

    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: widget.gradient == null
              ? (widget.backgroundColor ?? defaultBg)
              : null,
          gradient: widget.gradient,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(
            color: widget.borderColor ?? defaultBorder,
            width: isHovered && widget.hoverable ? 1.5 : 1,
          ),
          boxShadow: isHovered && widget.hoverable
              ? [
                  BoxShadow(
                    color: AppColors.primaryViolet.withValues(
                      alpha: isDark ? 0.22 : 0.12,
                    ),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: AppColors.primaryCyan.withValues(
                      alpha: isDark ? 0.12 : 0.05,
                    ),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            splashColor: AppColors.primaryViolet.withValues(alpha: 0.12),
            highlightColor: AppColors.primaryViolet.withValues(alpha: 0.06),
            child: Padding(padding: widget.padding, child: widget.child),
          ),
        ),
      ),
    );
  }
}
