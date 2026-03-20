import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';

class PhotoTile extends StatelessWidget {
  final String? thumbnailPath;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;

  const PhotoTile({
    super.key,
    this.thumbnailPath,
    required this.onTap,
    this.onLongPress,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.radiusTile),
          border: isSelected
              ? Border.all(
                  color: AppColors.primary,
                  width: 3,
                )
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusTile),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 占位符
              Container(
                color: AppColors.shimmerBase,
                child: const Center(
                  child: Icon(Icons.image, color: AppColors.shimmerHighlight),
                ),
              ),
              // 图片
              if (thumbnailPath != null)
                Image.file(
                  File(thumbnailPath!),
                  fit: BoxFit.cover,
                )
              else
                Container(
                  color: AppColors.shimmerBase,
                ),
              // 选中指示器
              if (isSelected)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
