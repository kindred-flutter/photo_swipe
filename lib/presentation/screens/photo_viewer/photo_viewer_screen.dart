import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'dart:typed_data';
import 'package:photo_manager/photo_manager.dart';
import '../../../data/models/photo_model.dart';
import '../../../core/utils/date_utils.dart';
import 'widgets/photo_info_panel.dart';

class PhotoViewerScreen extends StatefulWidget {
  final List<PhotoModel> photos;
  final int initialIndex;
  final Future<void> Function(PhotoModel)? onDelete;

  const PhotoViewerScreen({
    super.key,
    required this.photos,
    this.initialIndex = 0,
    this.onDelete,
  });

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late List<PhotoModel> _photos;
  int _currentIndex = 0;
  bool _showInfo = false;
  bool _isDeleting = false;

  // 卡片拖拽状态（ValueNotifier 避免整页重建）
  final ValueNotifier<Offset> _cardOffset = ValueNotifier(Offset.zero);
  final ValueNotifier<double> _cardRotation = ValueNotifier(0.0);
  final ValueNotifier<bool> _isDragging = ValueNotifier(false);
  Offset _dragStart = Offset.zero;

  // 回弹/飞出动画
  late AnimationController _snapController;
  late Animation<Offset> _snapAnimation;

  // 垃圾桶状态
  final ValueNotifier<bool> _trashActive = ValueNotifier(false);
  late AnimationController _trashShakeController;
  late Animation<double> _trashShake;

  // 图片缓存
  final Map<String, Uint8List> _thumbCache = {};
  final Map<String, Uint8List> _photoCache = {};

  static const double _triggerDistance = 110.0;
  static const double _triggerAngleMin = 20.0 * math.pi / 180;
  static const double _triggerAngleMax = 70.0 * math.pi / 180;

  @override
  void initState() {
    super.initState();
    _photos = List.from(widget.photos);
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);

    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _snapAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(_snapController);
    _snapController.addListener(() {
      _cardOffset.value = _snapAnimation.value;
    });

    _trashShakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _trashShake = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.25), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.25, end: 0.25), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.25, end: -0.15), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -0.15, end: 0.0), weight: 1),
    ]).animate(_trashShakeController);

    _preloadPhoto(_currentIndex);
    if (_currentIndex + 1 < _photos.length) _preloadPhoto(_currentIndex + 1);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _snapController.dispose();
    _trashShakeController.dispose();
    _cardOffset.dispose();
    _cardRotation.dispose();
    _isDragging.dispose();
    _trashActive.dispose();
    super.dispose();
  }

  PhotoModel get _currentPhoto => _photos[_currentIndex];

  Future<void> _preloadPhoto(int index) async {
    if (index < 0 || index >= _photos.length) return;
    final assetId = _photos[index].assetId;
    if (_photoCache.containsKey(assetId)) return;
    try {
      final asset = await AssetEntity.fromId(assetId);
      if (asset == null) return;
      final bytes = await asset.originBytes;
      if (bytes != null) _photoCache[assetId] = bytes;
      final thumb = await asset.thumbnailDataWithSize(const ThumbnailSize.square(400));
      if (thumb != null) _thumbCache[assetId] = thumb;
    } catch (_) {}
  }

  Future<Uint8List?> _getPhotoData(String assetId) async {
    if (_photoCache.containsKey(assetId)) return _photoCache[assetId];
    try {
      final asset = await AssetEntity.fromId(assetId);
      if (asset == null) return null;
      final bytes = await asset.originBytes;
      if (bytes != null) _photoCache[assetId] = bytes;
      return bytes;
    } catch (_) { return null; }
  }

  Future<Uint8List?> _getThumb(String assetId) async {
    if (_thumbCache.containsKey(assetId)) return _thumbCache[assetId];
    try {
      final asset = await AssetEntity.fromId(assetId);
      if (asset == null) return null;
      final bytes = await asset.thumbnailDataWithSize(const ThumbnailSize.square(400));
      if (bytes != null) _thumbCache[assetId] = bytes;
      return bytes;
    } catch (_) { return null; }
  }

  bool _isDeleteGesture(Offset delta) {
    if (delta.distance < _triggerDistance) return false;
    if (delta.dx <= 0 || delta.dy >= 0) return false;
    final angle = math.atan2(-delta.dy, delta.dx);
    return angle >= _triggerAngleMin && angle <= _triggerAngleMax;
  }

  void _onPointerDown(PointerDownEvent e) {
    if (_isDeleting) return;
    _snapController.stop();
    _dragStart = e.localPosition;
    _cardOffset.value = Offset.zero;
    _cardRotation.value = 0;
    _isDragging.value = true;
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (!_isDragging.value || _isDeleting) return;
    final delta = e.localPosition - _dragStart;
    _cardOffset.value = delta;
    _cardRotation.value = (delta.dx / 300).clamp(-0.26, 0.26);
    _trashActive.value = _isDeleteGesture(delta);
  }

  void _onPointerUp(PointerUpEvent e) {
    if (!_isDragging.value || _isDeleting) return;
    _isDragging.value = false;
    final delta = e.localPosition - _dragStart;
    if (_isDeleteGesture(delta)) {
      _triggerDelete();
    } else {
      _trashActive.value = false;
      _snapBack();
    }
  }

  void _snapBack() {
    _snapAnimation = Tween<Offset>(
      begin: _cardOffset.value,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _snapController,
      curve: Curves.elasticOut,
    ));
    _cardRotation.value = 0;
    _snapController.forward(from: 0);
  }

  void _triggerDelete() async {
    if (_isDeleting) return;
    _isDeleting = true;
    HapticFeedback.mediumImpact();

    final screenSize = MediaQuery.of(context).size;
    final flyTarget = Offset(screenSize.width + 200, -300.0);
    _snapAnimation = Tween<Offset>(
      begin: _cardOffset.value,
      end: flyTarget,
    ).animate(CurvedAnimation(
      parent: _snapController,
      curve: Curves.easeIn,
    ));
    _snapController.duration = const Duration(milliseconds: 280);
    _snapController.forward(from: 0);

    _trashActive.value = true;
    await Future.delayed(const Duration(milliseconds: 140));
    HapticFeedback.heavyImpact();
    _trashShakeController.forward(from: 0);
    await Future.delayed(const Duration(milliseconds: 180));

    final photo = _currentPhoto;
    final total = _photos.length;

    if (total == 1) {
      if (widget.onDelete != null) await widget.onDelete!(photo);
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final nextIndex = _currentIndex < total - 1 ? _currentIndex : _currentIndex - 1;

    if (mounted) {
      _cardOffset.value = Offset.zero;
      _cardRotation.value = 0;
      _trashActive.value = false;
      _snapController.duration = const Duration(milliseconds: 350);

      if (_currentIndex < total - 1) {
        _pageController.nextPage(
            duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
      } else {
        _pageController.previousPage(
            duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
      }
    }

    if (widget.onDelete != null) await widget.onDelete!(photo);
    _photos.removeAt(_currentIndex);

    if (mounted) {
      setState(() {
        _currentIndex = nextIndex.clamp(0, _photos.length - 1);
        _isDeleting = false;
      });
      _preloadPhoto(_currentIndex + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.7),
                Colors.transparent,
              ],
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${_currentIndex + 1} / ${_photos.length}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                _showInfo ? Icons.info : Icons.info_outline,
                key: ValueKey(_showInfo),
                color: _showInfo ? const Color(0xFF5B7FFF) : Colors.white,
              ),
            ),
            onPressed: () => setState(() => _showInfo = !_showInfo),
          ),
          // 垃圾桶
          ValueListenableBuilder<bool>(
            valueListenable: _trashActive,
            builder: (context, active, _) => AnimatedBuilder(
              animation: _trashShake,
              builder: (context, _) => Transform.rotate(
                angle: _trashShake.value,
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: active
                          ? const Color(0xFFE63946).withValues(alpha: 0.9)
                          : Colors.white.withValues(alpha: 0.15),
                      boxShadow: active
                          ? [BoxShadow(
                              color: const Color(0xFFE63946).withValues(alpha: 0.5),
                              blurRadius: 16, spreadRadius: 3)]
                          : [],
                    ),
                    child: Icon(
                      active ? Icons.delete : Icons.delete_outline,
                      color: Colors.white, size: 22,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Listener(
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerCancel: (_) {
          _isDragging.value = false;
          _trashActive.value = false;
          _snapBack();
        },
        child: Stack(
          children: [
            // 背景 PageView（只在非拖拽时可滑动）
            ValueListenableBuilder<bool>(
              valueListenable: _isDragging,
              builder: (context, dragging, _) => PageView.builder(
                controller: _pageController,
                physics: (_isDeleting || dragging)
                    ? const NeverScrollableScrollPhysics()
                    : const BouncingScrollPhysics(),
                onPageChanged: (i) {
                  if (!_isDeleting) {
                    setState(() => _currentIndex = i);
                    _preloadPhoto(i + 1);
                  }
                },
                itemCount: _photos.length,
                itemBuilder: (context, index) {
                  final photo = _photos[index];
                  return InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4.0,
                    child: Center(
                      child: FutureBuilder<Uint8List?>(
                        future: _getPhotoData(photo.assetId),
                        builder: (context, snap) {
                          if (snap.hasData && snap.data != null) {
                            return Image.memory(snap.data!,
                                fit: BoxFit.contain,
                                gaplessPlayback: true);
                          }
                          if (_thumbCache.containsKey(photo.assetId)) {
                            return Image.memory(_thumbCache[photo.assetId]!,
                                fit: BoxFit.contain, gaplessPlayback: true);
                          }
                          return const CircularProgressIndicator(
                              color: Colors.white54);
                        },
                      ),
                    ),
                  );
                },
              ),
            ),

            // 拖拽中的卡片覆盖层
            ValueListenableBuilder<bool>(
              valueListenable: _isDragging,
              builder: (context, dragging, _) {
                if (!dragging) return const SizedBox.shrink();
                return ValueListenableBuilder<Offset>(
                  valueListenable: _cardOffset,
                  builder: (context, offset, _) =>
                      ValueListenableBuilder<double>(
                    valueListenable: _cardRotation,
                    builder: (context, rotation, _) {
                      final progress =
                          (offset.distance / _triggerDistance).clamp(0.0, 1.0);
                      return Positioned.fill(
                        child: IgnorePointer(
                          child: Transform.translate(
                            offset: offset,
                            child: Transform.rotate(
                              angle: rotation,
                              child: Opacity(
                                opacity: (1.0 - progress * 0.2).clamp(0.0, 1.0),
                                child: FutureBuilder<Uint8List?>(
                                  future: _getThumb(_currentPhoto.assetId),
                                  builder: (context, snap) {
                                    if (snap.hasData && snap.data != null) {
                                      return Image.memory(snap.data!,
                                          fit: BoxFit.contain,
                                          gaplessPlayback: true);
                                    }
                                    return const SizedBox.shrink();
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),

            // 底部提示
            ValueListenableBuilder<bool>(
              valueListenable: _isDragging,
              builder: (context, dragging, _) {
                if (dragging || _isDeleting) return const SizedBox.shrink();
                return Positioned(
                  bottom: 48, left: 0, right: 0,
                  child: Center(
                    child: Platform.isIOS
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                              child: _buildHintBar(),
                            ),
                          )
                        : _buildHintBar(),
                  ),
                );
              },
            ),

            // 照片信息面板
            if (_showInfo && !_isDeleting)
              ValueListenableBuilder<bool>(
                valueListenable: _isDragging,
                builder: (context, dragging, _) {
                  if (dragging) return const SizedBox.shrink();
                  return Positioned(
                    left: 0, right: 0, bottom: 0,
                    child: PhotoInfoPanel(
                      photoDate: AppDateUtils.formatFull(_currentPhoto.takenAt),
                      photoSize: _currentPhoto.fileSizeFormatted,
                      photoResolution: _currentPhoto.resolutionFormatted,
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHintBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Platform.isIOS
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.swipe, size: 14, color: Colors.white.withAlpha(178)),
          const SizedBox(width: 6),
          Text('左右滑动浏览',
              style: TextStyle(
                  color: Colors.white.withAlpha(178), fontSize: 12)),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            width: 1, height: 12,
            color: Colors.white.withAlpha(64),
          ),
          Icon(Icons.north_east, size: 14, color: Colors.white.withAlpha(178)),
          const SizedBox(width: 6),
          Text('右上划移入垃圾箱',
              style: TextStyle(
                  color: Colors.white.withAlpha(178), fontSize: 12)),
        ],
      ),
    );
  }
}
