import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'dart:typed_data';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../../providers/trash_provider.dart';
import '../../../data/models/photo_model.dart';
import '../../../core/utils/date_utils.dart';
import 'delete_photo_session.dart';
import 'widgets/photo_info_panel.dart';

class PhotoViewerScreen extends StatefulWidget {
  final List<PhotoModel> photos;
  final int initialIndex;
  final Future<DeletePhotoSession> Function(PhotoModel)? onDelete;

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
  final ValueNotifier<bool> _showDragCard = ValueNotifier(false);
  bool _isDeleteDragIntent = false;
  Offset _dragStart = Offset.zero;

  // 回弹/飞出动画
  late AnimationController _snapController;
  late Animation<Offset> _snapAnimation;

  // 垃圾桶状态
  final ValueNotifier<bool> _trashActive = ValueNotifier(false);
  final ValueNotifier<bool> _isArmed = ValueNotifier(false);
  late AnimationController _trashShakeController;
  late Animation<double> _trashShake;

  // 图片缓存
  final Map<String, Uint8List> _thumbCache = {};
  final Map<String, Uint8List> _photoCache = {};
  final Map<String, int> _reloadVersions = {};
  final Map<String, VideoPlayerController> _videoControllers = {};

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
    for (final controller in _videoControllers.values) {
      controller.dispose();
    }
    _pageController.dispose();
    _snapController.dispose();
    _trashShakeController.dispose();
    _cardOffset.dispose();
    _cardRotation.dispose();
    _isDragging.dispose();
    _showDragCard.dispose();
    _trashActive.dispose();
    _isArmed.dispose();
    super.dispose();
  }

  PhotoModel get _currentPhoto => _photos[_currentIndex];

  Future<void> _preloadPhoto(int index) async {
    if (index < 0 || index >= _photos.length) return;
    final photo = _photos[index];
    final assetId = photo.assetId;

    try {
      final asset = await AssetEntity.fromId(assetId);
      if (asset == null) return;

      if (!_thumbCache.containsKey(assetId)) {
        final thumb = await asset.thumbnailDataWithSize(
          const ThumbnailSize.square(400),
        );
        if (thumb != null) {
          _thumbCache[assetId] = thumb;
        }
      }

      if (photo.mediaType == 'video' || photo.mediaType == 'live') {
        await _ensureVideoController(photo);
        return;
      }

      if (!_photoCache.containsKey(assetId)) {
        final bytes = await asset.originBytes;
        if (bytes != null) {
          _photoCache[assetId] = bytes;
        }
      }
    } catch (_) {}
  }

  Future<VideoPlayerController?> _ensureVideoController(PhotoModel photo) async {
    final existing = _videoControllers[photo.assetId];
    if (existing != null) return existing;

    try {
      final asset = await AssetEntity.fromId(photo.assetId);
      if (asset == null) return null;

      File? file;
      if (photo.mediaType == 'live' || asset.isLivePhoto) {
        file = await asset.fileWithSubtype;
        file ??= await asset.originFileWithSubtype;
        file ??= await asset.loadFile(withSubtype: true);
      } else {
        file = await asset.file;
      }
      if (file == null) return null;

      final controller = VideoPlayerController.file(file);
      await controller.initialize();
      await controller.setLooping(false);
      _videoControllers[photo.assetId] = controller;
      return controller;
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> _getPhotoData(String assetId) async {
    if (_photoCache.containsKey(assetId)) return _photoCache[assetId];
    try {
      final asset = await AssetEntity.fromId(assetId);
      if (asset == null) return null;

      final thumb = await asset.thumbnailDataWithSize(
        const ThumbnailSize.square(400),
      );
      if (thumb != null) {
        _thumbCache[assetId] = thumb;
      }

      final bytes = await asset.originBytes;
      if (bytes != null) {
        _photoCache[assetId] = bytes;
      }
      return bytes;
    } catch (_) {
      return null;
    }
  }

  void _reloadCurrentPhoto() {
    final assetId = _currentPhoto.assetId;
    _videoControllers.remove(assetId)?.dispose();
    _photoCache.remove(assetId);
    _thumbCache.remove(assetId);
    _reloadVersions[assetId] = (_reloadVersions[assetId] ?? 0) + 1;
    setState(() {});
    _preloadPhoto(_currentIndex);
  }

  void _restoreDeletedPhoto({
    required PhotoModel photo,
    required int restoreIndex,
  }) {
    if (_photos.any((p) => p.id == photo.id)) return;

    final safeIndex = restoreIndex.clamp(0, _photos.length);
    if (_photos.isEmpty) {
      setState(() {
        _photos.insert(0, photo);
        _currentIndex = 0;
        _isDeleting = false;
      });
      return;
    }

    setState(() {
      _photos.insert(safeIndex, photo);
      if (safeIndex <= _currentIndex) {
        _currentIndex += 1;
      }
      _currentIndex = _currentIndex.clamp(0, _photos.length - 1);
      _isDeleting = false;
    });
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
    _isDeleteDragIntent = false;
    _cardOffset.value = Offset.zero;
    _cardRotation.value = 0;
    _showDragCard.value = false;
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (_isDeleting) return;
    final rawDelta = e.localPosition - _dragStart;

    if (!_isDeleteDragIntent) {
      final isIntent = rawDelta.dx > 18 && rawDelta.dy < -18;
      if (!isIntent) return;
      _isDeleteDragIntent = true;
      _isDragging.value = true;
      _showDragCard.value = true;
    }

    final armed = _isDeleteGesture(rawDelta);
    _isArmed.value = armed;
    _trashActive.value = armed;

    if (armed) {
      final screenSize = MediaQuery.of(context).size;
      final trashTarget = Offset(screenSize.width / 2 - 34, -screenSize.height / 2 + 72);
      final pull = ((rawDelta.distance - _triggerDistance) / 140).clamp(0.0, 1.0);
      _cardOffset.value = Offset.lerp(rawDelta, trashTarget, 0.18 + pull * 0.42)!;
      _cardRotation.value = (rawDelta.dx / 380).clamp(0.08, 0.22);
      return;
    }

    _cardOffset.value = rawDelta;
    _cardRotation.value = (rawDelta.dx / 300).clamp(-0.18, 0.18);
  }

  void _onPointerUp(PointerUpEvent e) {
    if (_isDeleting) return;
    if (!_isDeleteDragIntent) return;

    _isDragging.value = false;
    _isDeleteDragIntent = false;

    if (_isArmed.value) {
      _triggerDelete();
      return;
    }

    _showDragCard.value = false;
    _trashActive.value = false;
    _snapBack();
  }

  void _snapBack() {
    _isArmed.value = false;
    _snapAnimation = Tween<Offset>(
      begin: _cardOffset.value,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _snapController,
      curve: Curves.elasticOut,
    ));
    _cardRotation.value = 0;
    _snapController.forward(from: 0).whenComplete(() {
      _showDragCard.value = false;
    });
  }

  Future<void> _triggerDelete() async {
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
    _isArmed.value = true;
    await Future.delayed(const Duration(milliseconds: 140));
    HapticFeedback.heavyImpact();
    _trashShakeController.forward(from: 0);
    await Future.delayed(const Duration(milliseconds: 180));

    final photo = _currentPhoto;
    final deletedIndex = _currentIndex;
    final total = _photos.length;

    if (total == 1) {
      if (widget.onDelete != null) {
        final session = await widget.onDelete!(photo);
        VoidCallback? listener;
        listener = () {
          if (!mounted || !session.undone.value) return;
          session.undone.removeListener(listener!);
          _restoreDeletedPhoto(photo: photo, restoreIndex: deletedIndex);
        };
        session.undone.addListener(listener);
      }
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final nextIndex = _currentIndex < total - 1 ? _currentIndex : _currentIndex - 1;

    if (mounted) {
      _cardOffset.value = Offset.zero;
      _cardRotation.value = 0;
      _trashActive.value = false;
      _isArmed.value = false;
      _showDragCard.value = false;
      _snapController.duration = const Duration(milliseconds: 350);

      if (_currentIndex < total - 1) {
        _pageController.nextPage(
            duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
      } else {
        _pageController.previousPage(
            duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
      }
    }

    DeletePhotoSession? session;
    if (widget.onDelete != null) {
      session = await widget.onDelete!(photo);
    }
    _photos.removeAt(_currentIndex);

    if (session != null) {
      final activeSession = session;
      VoidCallback? listener;
      listener = () {
        if (!mounted || !activeSession.undone.value) return;
        activeSession.undone.removeListener(listener!);
        _restoreDeletedPhoto(photo: photo, restoreIndex: deletedIndex);
      };
      activeSession.undone.addListener(listener);
    }

    if (mounted) {
      setState(() {
        _currentIndex = nextIndex.clamp(0, _photos.length - 1);
        _isDeleting = false;
      });
      _preloadPhoto(_currentIndex + 1);
    }
  }

  Widget _buildVideoContent(PhotoModel photo) {
    return FutureBuilder<VideoPlayerController?>(
      future: _ensureVideoController(photo),
      builder: (context, snap) {
        final controller = snap.data;
        if (snap.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator(color: Colors.white54);
        }
        if (controller == null || !controller.value.isInitialized) {
          if (photo.mediaType == 'live') {
            return FutureBuilder<Uint8List?>(
              future: _getPhotoData(photo.assetId),
              builder: (context, snap) {
                if (snap.hasData && snap.data != null) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.memory(
                        snap.data!,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          '当前仅展示实况主图，暂未取到动态视频片段',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  );
                }
                return const CircularProgressIndicator(color: Colors.white54);
              },
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.play_circle_outline_rounded,
                color: Colors.white70,
                size: 44,
              ),
              const SizedBox(height: 12),
              const Text(
                '动态内容暂时不可播放',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '可能仍在从 iCloud 同步，稍后可重新加载',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.tonal(
                onPressed: () => _reloadCurrentPhoto(),
                style: FilledButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.white.withValues(alpha: 0.18),
                ),
                child: const Text('重新加载'),
              ),
            ],
          );
        }

        return GestureDetector(
          onTap: () {
            if (controller.value.isPlaying) {
              controller.pause();
            } else {
              controller.play();
            }
            setState(() {});
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              AspectRatio(
                aspectRatio: controller.value.aspectRatio == 0
                    ? 1
                    : controller.value.aspectRatio,
                child: VideoPlayer(controller),
              ),
              if (!controller.value.isPlaying)
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 42,
                  ),
                ),
              Positioned(
                bottom: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    photo.mediaType == 'live'
                        ? (controller.value.isPlaying ? '点击暂停动图' : '点击播放动图')
                        : (controller.value.isPlaying ? '点击暂停视频' : '点击播放视频'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
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
          // 垃圾桶（带暂存数量角标）
          Consumer<TrashProvider>(
            builder: (context, trashProvider, _) {
              final trashCount = trashProvider.items.length;
              return ValueListenableBuilder<bool>(
                valueListenable: _trashActive,
                builder: (context, active, _) => AnimatedBuilder(
                  animation: _trashShake,
                  builder: (context, _) => Transform.rotate(
                    angle: _trashShake.value,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: active
                                  ? const Color(0xFFE63946).withValues(alpha: 0.9)
                                  : Colors.white.withValues(alpha: 0.15),
                              boxShadow: active
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFFE63946)
                                            .withValues(alpha: 0.5),
                                        blurRadius: 16,
                                        spreadRadius: 3,
                                      )
                                    ]
                                  : [],
                            ),
                            child: Icon(
                              active ? Icons.delete : Icons.delete_outline,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          if (trashCount > 0)
                            Positioned(
                              right: -6,
                              top: -6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 20,
                                  minHeight: 20,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFB703),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: Colors.black,
                                    width: 1.5,
                                  ),
                                ),
                                child: Text(
                                  trashCount > 99 ? '99+' : '$trashCount',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
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
            },
          ),
        ],
      ),
      body: Listener(
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerCancel: (_) {
          _isDragging.value = false;
          _isDeleteDragIntent = false;
          _trashActive.value = false;
          _isArmed.value = false;
          _snapBack();
        },
        child: Stack(
          children: [
            // 背景 PageView（只在非拖拽时可滑动）
            ValueListenableBuilder<bool>(
              valueListenable: _showDragCard,
              builder: (context, showDragCard, _) => PageView.builder(
                controller: _pageController,
                physics: (_isDeleting || showDragCard)
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
                  final reloadVersion = _reloadVersions[photo.assetId] ?? 0;
                  final isCurrentDragging = index == _currentIndex && _showDragCard.value;
                  return Opacity(
                    opacity: isCurrentDragging ? 0.18 : 1.0,
                    child: InteractiveViewer(
                      minScale: photo.mediaType == 'video' ? 1.0 : 0.8,
                      maxScale: photo.mediaType == 'video' ? 1.0 : 4.0,
                      child: Center(
                        child: (photo.mediaType == 'video' || photo.mediaType == 'live')
                            ? _buildVideoContent(photo)
                            : FutureBuilder<Uint8List?>(
                                key: ValueKey('${photo.assetId}-$reloadVersion'),
                                future: _getPhotoData(photo.assetId),
                                builder: (context, snap) {
                            if (snap.hasData && snap.data != null) {
                              return Image.memory(
                                snap.data!,
                                fit: BoxFit.contain,
                                gaplessPlayback: true,
                              );
                            }

                            final cachedThumb = _thumbCache[photo.assetId];
                            if (cachedThumb != null) {
                              return Stack(
                                alignment: Alignment.center,
                                children: [
                                  Image.memory(
                                    cachedThumb,
                                    fit: BoxFit.contain,
                                    gaplessPlayback: true,
                                  ),
                                  if (snap.connectionState == ConnectionState.waiting)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.45),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white70,
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            '正在加载原图',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              );
                            }

                            if (snap.connectionState == ConnectionState.waiting) {
                              return const CircularProgressIndicator(
                                color: Colors.white54,
                              );
                            }

                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.cloud_download_outlined,
                                  color: Colors.white70,
                                  size: 36,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  '原图暂时不可用',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  '可能仍在从 iCloud 同步，稍后可重新加载',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                FilledButton.tonal(
                                  onPressed: index == _currentIndex
                                      ? () => _reloadCurrentPhoto()
                                      : null,
                                  style: FilledButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    backgroundColor: Colors.white.withValues(alpha: 0.18),
                                  ),
                                  child: const Text('重新加载'),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // 拖拽中的卡片覆盖层
            ValueListenableBuilder<bool>(
              valueListenable: _showDragCard,
              builder: (context, showDragCard, _) {
                if (!showDragCard) return const SizedBox.shrink();
                return ValueListenableBuilder<Offset>(
                  valueListenable: _cardOffset,
                  builder: (context, offset, _) =>
                      ValueListenableBuilder<double>(
                    valueListenable: _cardRotation,
                    builder: (context, rotation, _) {
                      final progress =
                          (offset.distance / _triggerDistance).clamp(0.0, 1.0);
                      final armed = _isArmed.value;
                      final scale = armed ? (1.0 - progress * 0.18).clamp(0.78, 1.0) : 1.0;
                      final opacity = armed
                          ? (1.0 - progress * 0.32).clamp(0.62, 1.0)
                          : (1.0 - progress * 0.2).clamp(0.0, 1.0);
                      return Positioned.fill(
                        child: IgnorePointer(
                          child: Transform.translate(
                            offset: offset,
                            child: Transform.rotate(
                              angle: rotation,
                              child: Transform.scale(
                                scale: scale,
                                child: Opacity(
                                  opacity: opacity,
                                  child: Builder(
                                    builder: (context) {
                                      final cachedThumb = _thumbCache[_currentPhoto.assetId];
                                      if (cachedThumb != null) {
                                        return Image.memory(
                                          cachedThumb,
                                          fit: BoxFit.contain,
                                          gaplessPlayback: true,
                                        );
                                      }
                                      return const SizedBox.shrink();
                                    },
                                  ),
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
              valueListenable: _showDragCard,
              builder: (context, showDragCard, _) {
                if (showDragCard || _isDeleting) return const SizedBox.shrink();
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
                valueListenable: _showDragCard,
                builder: (context, showDragCard, _) {
                  if (showDragCard) return const SizedBox.shrink();
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
