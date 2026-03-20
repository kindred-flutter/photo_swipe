import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:ui';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';

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
    final isIOS = Platform.isIOS;
    const radius = BorderRadius.only(
      topLeft: Radius.circular(AppSpacing.radiusCard),
      topRight: Radius.circular(AppSpacing.radiusCard),
    );

    final content = Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: isIOS
            ? Colors.black.withAlpha(115) // ~0.45
            : (Theme.of(context).brightness == Brightness.dark
                ? AppColors.surfaceDark
                : AppColors.surface),
        borderRadius: radius,
        border: isIOS
            ? Border(
                top: BorderSide(
                  color: Colors.white.withAlpha(38), // ~0.15
                  width: 1,
                ),
              )
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部拖拽把手
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              decoration: BoxDecoration(
                color: isIOS
                    ? Colors.white.withAlpha(76) // ~0.3
                    : Colors.grey.withAlpha(102), // ~0.4
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          if (photoDate != null) ...[_InfoRow(label: '拍摄时间', value: photoDate!, isIOS: isIOS), const SizedBox(height: AppSpacing.md)],
          if (photoSize != null) ...[_InfoRow(label: '文件大小', value: photoSize!, isIOS: isIOS), const SizedBox(height: AppSpacing.md)],
          if (photoResolution != null) _InfoRow(label: '分辨率', value: photoResolution!, isIOS: isIOS),
        ],
      ),
    );

    if (!isIOS) return content;

    // iOS 毛玻璃效果
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: content,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isIOS;

  const _InfoRow({
    required this.label,
    required this.value,
    this.isIOS = false,
  });

  @override
  Widget build(BuildContext context) {
    final labelColor = isIOS
        ? Colors.white.withAlpha(140) // ~0.55
        : AppColors.secondary;
    final valueColor = isIOS ? Colors.white : null;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: labelColor,
              ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
        ),
      ],
    );
  }
}
