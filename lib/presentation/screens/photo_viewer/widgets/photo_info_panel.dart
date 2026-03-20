import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/date_utils.dart';

class PhotoInfoPanel extends StatelessWidget {
  final String? photoDate;
  final String? photoSize;
  final String? photoResolution;

  const PhotoInfoPanel({
    super.key,
    this.photoDate,
    this.photoSize,
    this.photoResolution,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.surfaceDark
            : AppColors.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppSpacing.radiusCard),
          topRight: Radius.circular(AppSpacing.radiusCard),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (photoDate != null) ...[
            _InfoRow(label: '拍摄时间', value: photoDate!),
            const SizedBox(height: AppSpacing.md),
          ],
          if (photoSize != null) ...[
            _InfoRow(label: '文件大小', value: photoSize!),
            const SizedBox(height: AppSpacing.md),
          ],
          if (photoResolution != null) ...[
            _InfoRow(label: '分辨率', value: photoResolution!),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.secondary,
              ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}
