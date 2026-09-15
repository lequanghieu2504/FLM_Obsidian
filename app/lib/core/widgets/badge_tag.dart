import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum BadgeStyle { primary, cyan, emerald, amber, rose, outline }

class BadgeTag extends StatelessWidget {
  const BadgeTag({
    required this.label,
    super.key,
    this.style = BadgeStyle.primary,
    this.icon,
    this.fontSize = 11,
  });

  final String label;
  final BadgeStyle style;
  final IconData? icon;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color bg;
    Color fg;
    Color border;

    switch (style) {
      case BadgeStyle.primary:
        bg = AppColors.primaryViolet.withValues(alpha: isDark ? 0.22 : 0.12);
        fg = isDark ? const Color(0xFFC084FC) : AppColors.primaryViolet;
        border = AppColors.primaryViolet.withValues(alpha: 0.35);
        break;
      case BadgeStyle.cyan:
        bg = AppColors.primaryCyan.withValues(alpha: isDark ? 0.22 : 0.12);
        fg = isDark ? const Color(0xFF67E8F9) : const Color(0xFF0891B2);
        border = AppColors.primaryCyan.withValues(alpha: 0.35);
        break;
      case BadgeStyle.emerald:
        bg = AppColors.accentEmerald.withValues(alpha: isDark ? 0.22 : 0.12);
        fg = isDark ? const Color(0xFF6EE7B7) : const Color(0xFF059669);
        border = AppColors.accentEmerald.withValues(alpha: 0.35);
        break;
      case BadgeStyle.amber:
        bg = AppColors.accentAmber.withValues(alpha: isDark ? 0.22 : 0.12);
        fg = isDark ? const Color(0xFFFDE047) : const Color(0xFFD97706);
        border = AppColors.accentAmber.withValues(alpha: 0.35);
        break;
      case BadgeStyle.rose:
        bg = AppColors.accentRose.withValues(alpha: isDark ? 0.22 : 0.12);
        fg = isDark ? const Color(0xFFFDA4AF) : const Color(0xFFE11D48);
        border = AppColors.accentRose.withValues(alpha: 0.35);
        break;
      case BadgeStyle.outline:
        bg = Colors.transparent;
        fg = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
        border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: 1),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: fg.withValues(alpha: 0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fontSize + 2, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
