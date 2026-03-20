import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';

/// 全局缩略图缓存 - 使用 LRU 策略
class _ThumbnailCache {
  static const int _maxSize = 200;
  static final Map<String, Uint8List> _cache = {};
  static final List<String> _accessOrder = [];

  static Uint8List? get(String assetId) {
    if (_cache.containsKey(assetId)) {
      _accessOrder.remove(assetId);
      _accessOrder.add(assetId);
      return _cache[assetId];
    }
    return null;
  }

  static void put(String assetId, Uint8List? data) {
    if (data == null) return;
    
    if (_cache.containsKey(assetId)) {
      _accessOrder.remove(assetId);
    } else if (_cache.length >= _maxSize) {
      final oldest = _accessOrder.removeAt(0);
      _cache.remove(oldest);
    }
    
    _cache[assetId] = data;
    _accessOrder.add(assetId);
  }

  static void clear() {
    _cache.clear();
    _accessOrder.clear();
  }
}

class PhotoTile extends StatefulWidget {
  final String assetId;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;

  const PhotoTile({
    super.key,
    required this.assetId,
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
  Uint8List? _thumbnail;
  bool _isLoading = true;
  bool _hasError = false;

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
    
    _loadThumbnail();
  }

  Future<void> _loadThumbnail() async {
    final cached = _ThumbnailCache.get(widget.assetId);
    if (cached != null) {
      if (mounted) {
        setState(() {
          _thumbnail = cached;
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final asset = await AssetEntity.fromId(widget.assetId);
      if (asset == null) {
        if (mounted) {
          setState(() {
            _hasError = true;
            _isLoading = false;
          });
        }
        return;
      }
      
      final data = await asset.thumbnailDataWithSize(
        const ThumbnailSize.square(300),
        quality: 80,
      );
      
      if (data != null) {
        _ThumbnailCache.put(widget.assetId, data);
      }
      
      if (mounted) {
        setState(() {
          _thumbnail = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading thumbnail: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: _controller.reverse,
      onLongPress: widget.onLongPress,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusTile),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildImage(),
              if (widget.isSelected)
                Positioned.fill(
                  child: Container(
                    color: AppColors.primary.withAlpha(76),
                    child: Center(
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (_isLoading) {
      return _buildPlaceholder(isLoading: true);
    }
    
    if (_hasError || _thumbnail == null) {
      return _buildPlaceholder(hasError: true);
    }
    
    return Image.memory(
      _thumbnail!,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => _buildPlaceholder(hasError: true),
    );
  }

  Widget _buildPlaceholder({bool isLoading = false, bool hasError = false}) {
    return Container(
      color: AppColors.shimmerBase,
      child: Center(
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                hasError ? Icons.broken_image : Icons.image,
                color: AppColors.shimmerHighlight,
                size: 32,
              ),
      ),
    );
  }
}

/// 预加载指定范围内的缩略图
Future<void> preloadThumbnails(List<String> assetIds) async {
  for (int i = 0; i < assetIds.length; i++) {
    final assetId = assetIds[i];
    if (_ThumbnailCache.get(assetId) != null) continue;
    
    try {
      final asset = await AssetEntity.fromId(assetId);
      if (asset == null) continue;
      final data = await asset.thumbnailDataWithSize(
        const ThumbnailSize.square(300),
        quality: 80,
      );
      if (data != null) {
        _ThumbnailCache.put(assetId, data);
      }
    } catch (e) {
      debugPrint('Error preloading thumbnail for $assetId: $e');
    }
  }
}

/// 清空缓存（内存不足时调用）
void clearThumbnailCache() {
  _ThumbnailCache.clear();
}
