import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_strings.dart';

class StatsBanner extends StatelessWidget {
  final int totalPhotos;
  final int trashedPhotos;
  final int savedMB;

  const StatsBanner({
    super.key,
    required this.totalPhotos,
    required this.trashedPhotos,
    required this.savedMB,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark
        ? const Color(0xFF131722)
        : Colors.white.withValues(alpha: 0.92);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.06);
    final mutedColor = isDark ? Colors.white60 : Colors.black54;
    final textColor = isDark ? Colors.white : const Color(0xFF111827);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryBlock(
              label: AppStrings.statsTotal,
              value: '$totalPhotos',
              suffix: AppStrings.statsUnit,
              accent: AppColors.primary,
              textColor: textColor,
              mutedColor: mutedColor,
            ),
          ),
          _Divider(isDark: isDark),
          Expanded(
            child: _SummaryBlock(
              label: AppStrings.statsTrash,
              value: '$trashedPhotos',
              suffix: AppStrings.statsUnit,
              accent: const Color(0xFFE76F51),
              textColor: textColor,
              mutedColor: mutedColor,
            ),
          ),
          _Divider(isDark: isDark),
          Expanded(
            child: _SummaryBlock(
              label: AppStrings.statsSaved,
              value: '$savedMB',
              suffix: AppStrings.statsMB,
              accent: const Color(0xFF2A9D8F),
              textColor: textColor,
              mutedColor: mutedColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryBlock extends StatelessWidget {
  final String label;
  final String value;
  final String suffix;
  final Color accent;
  final Color textColor;
  final Color mutedColor;

  const _SummaryBlock({
    required this.label,
    required this.value,
    required this.suffix,
    required this.accent,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: accent,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.35),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 20,
            height: 1,
            fontWeight: FontWeight.w800,
            color: textColor,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          suffix,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: mutedColor,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: mutedColor,
          ),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  final bool isDark;

  const _Divider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 52,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      color: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.08),
    );
  }
}
