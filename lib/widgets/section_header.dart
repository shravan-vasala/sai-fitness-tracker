import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/layout_insets.dart';

/// Uppercase purple section label used on Home / Workout / similar lists.
class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.title, {
    super.key,
    this.icon,
    this.trailing,
    this.countLabel,
    this.horizontalPadding = kScreenPadding,
  });

  final String title;
  final IconData? icon;
  final Widget? trailing;
  final Widget? countLabel;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: context.colors.primary, size: 18),
            const SizedBox(width: 6),
          ],
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: context.colors.primary,
              letterSpacing: 1.2,
            ),
          ),
          if (countLabel != null) ...[
            const SizedBox(width: 8),
            countLabel!,
          ],
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
