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

    return Container(
      height: AppSpacing.statsBannerHeight,
      color: isDark ? AppColors.surfaceDark : AppColors.statsBanner,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
            icon: '📷',
            label: AppStrings.statsTotal,
            value: '\$totalPhotos',
            unit: AppStrings.statsUnit,
          ),
          _StatItem(
            icon: '🗑',
            label: AppStrings.statsTrash,
            value: '\$trashedPhotos',
            unit: AppStrings.statsUnit,
          ),
          _StatItem(
            icon: '💾',
            label: AppStrings.statsSaved,
            value: '\$savedMB',
            unit: AppStrings.statsMB,
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final String unit;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(icon, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 2),
            Text(
              unit,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }
}
