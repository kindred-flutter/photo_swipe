import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';

/// 全局缩略图缓存 - 使用 LRU 策略
class _ThumbnailCache {
  static const int _maxSize = 120;
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
  final String mediaType;
  final VoidCallback onTap;
  final VoidCallback? onDeleteHoldComplete;
  final bool isSelected;

  const PhotoTile({
    super.key,
    required this.assetId,
    required this.mediaType,
    required this.onTap,
    this.onDeleteHoldComplete,
    this.isSelected = false,
  });

  @override
  State<PhotoTile> createState() => _PhotoTileState();
}

class _PhotoTileState extends State<PhotoTile>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late AnimationController _deleteHoldController;
  late AnimationController _deleteFadeController;
  late AnimationController _collapseController;
  Uint8List? _thumbnail;
  bool _isLoading = true;
  bool _hasError = false;
  bool _deleteTriggered = false;

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
    _deleteHoldController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..addListener(() {
        if (mounted) setState(() {});
      })
      ..addStatusListener((status) async {
        if (status == AnimationStatus.completed && !_deleteTriggered) {
          _deleteTriggered = true;
          HapticFeedback.mediumImpact();
          await _deleteFadeController.forward(from: 0);
          await _collapseController.forward(from: 0);
          if (mounted) {
            widget.onDeleteHoldComplete?.call();
          }
        }
      });
    _deleteFadeController = AnimationController(
      duration: const Duration(milliseconds: 240),
      vsync: this,
    )..addListener(() {
        if (mounted) setState(() {});
      });
    _collapseController = AnimationController(
      duration: const Duration(milliseconds: 180),
      vsync: this,
    )..addListener(() {
        if (mounted) setState(() {});
      });

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
        const ThumbnailSize.square(220),
        quality: 72,
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
    _deleteHoldController.dispose();
    _deleteFadeController.dispose();
    _collapseController.dispose();
    super.dispose();
  }

  void _startDeleteHold() {
    if (widget.onDeleteHoldComplete == null) return;
    _deleteTriggered = false;
    _deleteFadeController.value = 0;
    _collapseController.value = 0;
    HapticFeedback.selectionClick();
    _deleteHoldController.forward(from: 0);
  }

  void _cancelDeleteHold() {
    if (_deleteTriggered) return;
    if (_deleteHoldController.isAnimating || _deleteHoldController.value > 0) {
      _deleteHoldController.stop();
      _deleteHoldController.reverse();
    }
    if (_deleteFadeController.isAnimating || _deleteFadeController.value > 0) {
      _deleteFadeController.stop();
      _deleteFadeController.reverse();
    }
    if (_collapseController.isAnimating || _collapseController.value > 0) {
      _collapseController.stop();
      _collapseController.reverse();
    }
    _deleteTriggered = false;
  }

  @override
  Widget build(BuildContext context) {
    final deleteProgress = (_deleteHoldController.value / 0.5).clamp(0.0, 1.0);
    final fadeProgress = _deleteFadeController.value;
    final collapseProgress = _collapseController.value;
    final borderColor = Color.lerp(
      Colors.transparent,
      const Color(0xFFE63946),
      Curves.easeIn.transform(deleteProgress),
    )!;
    final overlayColor = const Color(0xFFE63946).withValues(
      alpha: 0.08 + deleteProgress * 0.22 + fadeProgress * 0.18,
    );
    final visualOpacity = (1 - fadeProgress).clamp(0.0, 1.0);
    final visualScale = 1 - fadeProgress * 0.08;
    final heightFactor = 1 - collapseProgress;

    return Align(
      alignment: Alignment.topCenter,
      child: ClipRect(
        child: Align(
          heightFactor: heightFactor,
          child: GestureDetector(
            onTapDown: (_) => _controller.forward(),
            onTapUp: (_) {
              _controller.reverse();
              widget.onTap();
            },
            onTapCancel: _controller.reverse,
            onLongPressStart: (_) => _startDeleteHold(),
            onLongPressEnd: (_) => _cancelDeleteHold(),
            onLongPressCancel: _cancelDeleteHold,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Transform.scale(
                scale: visualScale,
                child: Opacity(
                  opacity: visualOpacity,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusTile),
                      border: Border.all(
                        color: borderColor,
                        width: 1.5 + deleteProgress * 2.5,
                      ),
                      boxShadow: deleteProgress > 0 || fadeProgress > 0
                          ? [
                              BoxShadow(
                                color: const Color(0xFFE63946).withValues(
                                  alpha: 0.12 + deleteProgress * 0.18 + fadeProgress * 0.12,
                                ),
                                blurRadius: 8 + deleteProgress * 14 + fadeProgress * 8,
                                spreadRadius: deleteProgress * 1.5,
                              ),
                            ]
                          : [],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusTile),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _buildImage(),
                          if (widget.mediaType == 'video' || widget.mediaType == 'live')
                            Positioned(
                              right: 8,
                              bottom: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.play_arrow_rounded,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      widget.mediaType == 'live' ? '动图' : '视频',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (deleteProgress > 0 || fadeProgress > 0)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: Container(color: overlayColor),
                              ),
                            ),
                          if (widget.isSelected)
                            Positioned.fill(
                              child: Container(
                                color: AppColors.primary.withValues(alpha: 0.3),
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
                ),
              ),
            ),
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
        const ThumbnailSize.square(220),
        quality: 72,
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
