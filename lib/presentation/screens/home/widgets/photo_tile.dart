import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';

class PhotoTile extends StatefulWidget {
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
  State<PhotoTile> createState() => _PhotoTileState();
}

class _PhotoTileState extends State<PhotoTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onTap();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onLongPress: widget.onLongPress,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusTile),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusTile),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 占位符背景
                Container(
                  color: AppColors.shimmerBase,
                  child: const Center(
                    child: Icon(
                      Icons.image,
                      color: AppColors.shimmerHighlight,
                      size: 32,
                    ),
                  ),
                ),
                // 图片
                if (widget.thumbnailPath != null)
                  FutureBuilder<bool>(
                    future: File(widget.thumbnailPath!).exists(),
                    builder: (context, snapshot) {
                      if (snapshot.data == true) {
                        return Image.file(
                          File(widget.thumbnailPath!),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: AppColors.shimmerBase,
                            child: const Center(
                              child: Icon(
                                Icons.broken_image,
                                color: AppColors.shimmerHighlight,
                                size: 32,
                              ),
                            ),
                          ),
                        );
                      }
                      return Container(
                        color: AppColors.shimmerBase,
                        child: const Center(
                          child: Icon(
                            Icons.image_not_supported,
                            color: AppColors.shimmerHighlight,
                            size: 32,
                          ),
                        ),
                      );
                    },
                  )
                else
                  Container(
                    color: AppColors.shimmerBase,
                  ),
                // 选中指示器
                if (widget.isSelected)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.3),
                      ),
                      child: Center(
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary,
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
