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
    final defaultBg = isDark
        ? (isHovered && widget.hoverable
              ? AppColors.darkSurfaceHover
              : AppColors.darkCard)
        : (isHovered && widget.hoverable
              ? AppColors.lightSurfaceHover
              : AppColors.lightCard);
    final defaultBorder = isDark
        ? (isHovered && widget.hoverable
              ? AppColors.primaryIndigo.withValues(alpha: 0.4)
              : AppColors.darkBorder)
        : (isHovered && widget.hoverable
              ? AppColors.primaryIndigo.withValues(alpha: 0.3)
              : AppColors.lightBorder);

    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: widget.gradient == null
              ? (widget.backgroundColor ?? defaultBg)
              : null,
          gradient: widget.gradient,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(
            color: widget.borderColor ?? defaultBorder,
            width: 1,
          ),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            splashColor: AppColors.primaryIndigo.withValues(alpha: 0.08),
            highlightColor: AppColors.primaryIndigo.withValues(alpha: 0.04),
            child: Padding(padding: widget.padding, child: widget.child),
          ),
        ),
      ),
    );
  }
}
