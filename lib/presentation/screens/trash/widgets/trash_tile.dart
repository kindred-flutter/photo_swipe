import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../data/models/trash_item_model.dart';

class TrashTile extends StatefulWidget {
  final TrashItemModel item;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  const TrashTile({
    super.key,
    required this.item,
    required this.onRestore,
    required this.onDelete,
  });

  @override
  State<TrashTile> createState() => _TrashTileState();
}

class _TrashTileState extends State<TrashTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 180),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final daysLeft = widget.item.daysUntilExpiry;
    final isExpiringSoon = daysLeft <= 3;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        _showOptions(context);
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusTile),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(25),
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
                // 背景占位
                Container(
                  color: AppColors.shimmerBase,
                  child: const Center(
                    child: Icon(Icons.image,
                        color: AppColors.shimmerHighlight, size: 32),
                  ),
                ),
                // 实际照片 - 用缩略图 API，不加载原图
                FutureBuilder<Uint8List?>(
                  future: _getThumbnail(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data != null) {
                      return Image.memory(
                        snapshot.data!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: AppColors.shimmerBase,
                          child: const Center(
                            child: Icon(Icons.broken_image,
                                color: AppColors.shimmerHighlight, size: 32),
                          ),
                        ),
                      );
                    }
                    return Container(
                      color: AppColors.shimmerBase,
                      child: const Center(
                        child: Icon(Icons.image_not_supported,
                            color: AppColors.shimmerHighlight, size: 32),
                      ),
                    );
                  },
                ),
                // 底部渐变+信息
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 6),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.black87, Colors.transparent],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          AppDateUtils.formatRelative(widget.item.deletedAt),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              size: 9,
                              color: isExpiringSoon
                                  ? Colors.orange
                                  : Colors.white60,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '$daysLeft天后删除',
                              style: TextStyle(
                                color: isExpiringSoon
                                    ? Colors.orange
                                    : Colors.white60,
                                fontSize: 9,
                                fontWeight: isExpiringSoon
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // 即将到期标记
                if (isExpiringSoon)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '即将删除',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w700),
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

  Future<Uint8List?> _getThumbnail() async {
    try {
      final asset = await AssetEntity.fromId(widget.item.photo.assetId);
      if (asset == null) return null;
      return await asset.thumbnailDataWithSize(
        const ThumbnailSize.square(300),
      );
    } catch (e) {
      debugPrint('Error loading thumbnail: $e');
      return null;
    }
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.restore, color: AppColors.primary),
                ),
                title: const Text('恢复到相册',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                subtitle: const Text('照片将回到主相册'),
                onTap: () {
                  Navigator.pop(context);
                  widget.onRestore();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.error.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child:
                      const Icon(Icons.delete_forever, color: AppColors.error),
                ),
                title: const Text('永久删除',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                subtitle: const Text('此操作不可撤销'),
                onTap: () {
                  Navigator.pop(context);
                  widget.onDelete();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
