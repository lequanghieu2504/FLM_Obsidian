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
        bg = isDark ? const Color(0x1F38BDF8) : const Color(0x100284C7);
        fg = isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);
        border = isDark ? const Color(0x3D38BDF8) : const Color(0x3D0284C7);
        break;
      case BadgeStyle.cyan:
        bg = isDark ? const Color(0x1F0EA5E9) : const Color(0x100284C7);
        fg = isDark ? const Color(0xFF38BDF8) : const Color(0xFF0369A1);
        border = isDark ? const Color(0x3D0EA5E9) : const Color(0x3D0369A1);
        break;
      case BadgeStyle.emerald:
        bg = isDark ? const Color(0x1F10B981) : const Color(0x10059669);
        fg = isDark ? const Color(0xFF34D399) : const Color(0xFF059669);
        border = isDark ? const Color(0x3D10B981) : const Color(0x3D059669);
        break;
      case BadgeStyle.amber:
        bg = isDark ? const Color(0x1FF59E0B) : const Color(0x10D97706);
        fg = isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
        border = isDark ? const Color(0x3DF59E0B) : const Color(0x3DD97706);
        break;
      case BadgeStyle.rose:
        bg = isDark ? const Color(0x1FEF4444) : const Color(0x10DC2626);
        fg = isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
        border = isDark ? const Color(0x3DEF4444) : const Color(0x3DDC2626);
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1),
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
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
