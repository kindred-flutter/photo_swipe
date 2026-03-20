import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
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

  // 手势状态
  Offset _dragStart = Offset.zero;
  Offset _dragCurrent = Offset.zero;
  bool _isDragging = false;
  bool _isAnimating = false;

  // 照片飞行动画
  late AnimationController _flyController;
  late Animation<double> _flyProgress;
  Offset _flyStart = Offset.zero;
  Offset _flyEnd = Offset.zero;
  bool _showFlyPhoto = false;
  String? _flyPhotoPath;

  // 垃圾箱抖动
  late AnimationController _trashShakeController;
  late Animation<double> _trashShake;
  bool _trashGlowing = false;

  static const double _minDistance = 100.0;
  static const double _minAngle = 25.0 * math.pi / 180;
  static const double _maxAngle = 65.0 * math.pi / 180;

  @override
  void initState() {
    super.initState();
    _photos = List.from(widget.photos);
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);

    _flyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _flyProgress = CurvedAnimation(
      parent: _flyController,
      curve: Curves.easeInCubic,
    );
    _flyController.addStatusListener((status) {
      if (status == AnimationStatus.completed) _onFlyCompleted();
    });

    _trashShakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _trashShake = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.3), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.3, end: 0.3), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.3, end: -0.2), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -0.2, end: 0.0), weight: 1),
    ]).animate(_trashShakeController);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _flyController.dispose();
    _trashShakeController.dispose();
    super.dispose();
  }

  PhotoModel get _currentPhoto => _photos[_currentIndex];

  bool _isValidDeleteGesture(Offset start, Offset end) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final distance = math.sqrt(dx * dx + dy * dy);
    if (distance < _minDistance) return false;
    if (dx <= 0 || dy >= 0) return false;
    final angle = math.atan2(-dy, dx);
    return angle >= _minAngle && angle <= _maxAngle;
  }

  bool _isDiagonalGesture() {
    if (!_isDragging) return false;
    final dx = _dragCurrent.dx - _dragStart.dx;
    final dy = _dragCurrent.dy - _dragStart.dy;
    // 向右上方的斜向手势才锁定 PageView
    return dx > 20 && dy < -20;
  }

  double get _gestureProgress {
    if (!_isDragging) return 0;
    final dx = _dragCurrent.dx - _dragStart.dx;
    final dy = _dragCurrent.dy - _dragStart.dy;
    final distance = math.sqrt(dx * dx + dy * dy);
    return (dx > 0 && dy < 0)
        ? (distance / _minDistance).clamp(0.0, 1.0)
        : 0;
  }

  void _onPanStart(DragStartDetails d) {
    if (_isAnimating) return;
    setState(() {
      _dragStart = d.localPosition;
      _dragCurrent = d.localPosition;
      _isDragging = true;
    });
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (!_isDragging) return;
    setState(() => _dragCurrent = d.localPosition);
  }

  void _onPanEnd(DragEndDetails d) {
    if (!_isDragging) return;
    if (_isValidDeleteGesture(_dragStart, _dragCurrent)) {
      _startDeleteAnimation();
    } else {
      setState(() => _isDragging = false);
    }
  }

  void _startDeleteAnimation() {
    if (_isAnimating) return;
    setState(() {
      _isAnimating = true;
      _isDragging = false;
    });
    HapticFeedback.heavyImpact();
    final screenSize = MediaQuery.of(context).size;
    _flyStart = Offset(screenSize.width / 2, screenSize.height / 2);
    _flyEnd = Offset(screenSize.width - 36, 56);
    _flyPhotoPath = _currentPhoto.localPath ?? _currentPhoto.thumbnailPath;
    setState(() => _showFlyPhoto = true);
    _flyController.forward(from: 0);
  }

  void _onFlyCompleted() async {
    setState(() => _trashGlowing = true);
    _trashShakeController.forward(from: 0);
    HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 300));
    final photo = _currentPhoto;
    final total = _photos.length;
    if (total == 1) {
      if (widget.onDelete != null) await widget.onDelete!(photo);
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final nextIndex = _currentIndex < total - 1 ? _currentIndex : _currentIndex - 1;
    if (_currentIndex < total - 1) {
      _pageController.nextPage(
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    } else {
      _pageController.previousPage(
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
    if (widget.onDelete != null) await widget.onDelete!(photo);
    _photos.removeAt(_currentIndex);
    if (mounted) {
      setState(() {
        _currentIndex = nextIndex.clamp(0, _photos.length - 1);
        _showFlyPhoto = false;
        _trashGlowing = false;
        _isAnimating = false;
      });
    }
  }

  Widget _buildHintRow() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.swipe, size: 14, color: Colors.white.withAlpha(178)),
        const SizedBox(width: 6),
        Text(
          '左右滑动浏览',
          style: TextStyle(color: Colors.white.withAlpha(178), fontSize: 12),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          width: 1,
          height: 12,
          color: Colors.white.withAlpha(64),
        ),
        Icon(Icons.north_east, size: 14, color: Colors.white.withAlpha(178)),
        const SizedBox(width: 6),
        Text(
          '右上划移入垃圾箱',
          style: TextStyle(color: Colors.white.withAlpha(178), fontSize: 12),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = _gestureProgress;
    final isNearTrigger = progress > 0.7;
    final screenSize = MediaQuery.of(context).size;

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
                Colors.black.withOpacity(0.75),
                Colors.transparent,
              ],
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_currentIndex + 1} / ${_photos.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
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
          // 垃圾箱图标（飞行动画的目标）
          AnimatedBuilder(
            animation: _trashShake,
            builder: (context, child) => Transform.rotate(
              angle: _trashShake.value,
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _trashGlowing
                        ? const Color(0xFFE63946).withOpacity(0.9)
                        : Colors.white.withOpacity(0.15),
                    boxShadow: _trashGlowing
                        ? [
                            BoxShadow(
                              color:
                                  const Color(0xFFE63946).withOpacity(0.6),
                              blurRadius: 20,
                              spreadRadius: 4,
                            )
                          ]
                        : [],
                  ),
                  child: Icon(
                    _trashGlowing ? Icons.delete : Icons.delete_outline,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Listener(
        onPointerDown: (e) {
          if (_isAnimating) return;
          setState(() {
            _dragStart = e.localPosition;
            _dragCurrent = e.localPosition;
            _isDragging = true;
          });
        },
        onPointerMove: (e) {
          if (!_isDragging) return;
          setState(() => _dragCurrent = e.localPosition);
        },
        onPointerUp: (e) {
          if (!_isDragging) return;
          if (_isValidDeleteGesture(_dragStart, _dragCurrent)) {
            _startDeleteAnimation();
          } else {
            setState(() => _isDragging = false);
          }
        },
        onPointerCancel: (_) => setState(() => _isDragging = false),
        child: Stack(
          children: [
            // 照片 PageView
            Opacity(
              opacity: _showFlyPhoto ? 0.0 : 1.0,
              child: PageView.builder(
                controller: _pageController,
                physics: (_isAnimating)
                    ? const NeverScrollableScrollPhysics()
                    : _isDiagonalGesture()
                        ? const NeverScrollableScrollPhysics()
                        : const BouncingScrollPhysics(),
                onPageChanged: (i) {
                  if (!_isAnimating) setState(() => _currentIndex = i);
                },
                itemCount: _photos.length,
                itemBuilder: (context, index) {
                  final photo = _photos[index];
                  final path = photo.localPath ?? photo.thumbnailPath;
                  return InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4.0,
                    child: Center(
                      child: path != null
                          ? Image.file(File(path),
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(
                                  Icons.broken_image,
                                  color: Colors.white54,
                                  size: 64))
                          : const Icon(Icons.broken_image,
                              color: Colors.white54, size: 64),
                    ),
                  );
                },
              ),
            ),

            // 手势轨迹
            if (_isDragging)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _DeleteTrailPainter(
                      start: _dragStart,
                      end: _dragCurrent,
                      progress: progress,
                    ),
                  ),
                ),
              ),

            // 接近触发时的大垃圾桶图标
            if (isNearTrigger)
              Positioned(
                right: screenSize.width * 0.08,
                top: screenSize.height * 0.25,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.5, end: 1.0),
                  duration: const Duration(milliseconds: 150),
                  builder: (_, scale, child) => Transform.scale(
                      scale: scale, child: child),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.85),
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(
                        color: Colors.red.withOpacity(0.5),
                        blurRadius: 24,
                        spreadRadius: 6,
                      )],
                    ),
                    child: const Icon(Icons.delete, color: Colors.white, size: 44),
                  ),
                ),
              ),

            // 照片飞向垃圾箱的动画
            if (_showFlyPhoto && _flyPhotoPath != null)
              AnimatedBuilder(
                animation: _flyProgress,
                builder: (context, _) {
                  final t = _flyProgress.value;
                  final dx = _flyEnd.dx - _flyStart.dx;
                  final dy = _flyEnd.dy - _flyStart.dy;
                  // 抛物线：x 线性，y 加弧线
                  final x = _flyStart.dx + dx * t;
                  final y = _flyStart.dy + dy * t - math.sin(math.pi * t) * 100;
                  final scale = (1.0 - t * 0.88).clamp(0.05, 1.0);
                  final opacity = t > 0.75 ? (1.0 - t) / 0.25 : 1.0;
                  final size = 120.0 * scale;
                  return Positioned(
                    left: x - size / 2,
                    top: y - size / 2,
                    child: Opacity(
                      opacity: opacity.clamp(0.0, 1.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12 * scale),
                        child: Image.file(
                          File(_flyPhotoPath!),
                          width: size,
                          height: size,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: size,
                            height: size,
                            color: Colors.grey[800],
                            child: const Icon(Icons.image, color: Colors.white54),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

            // 底部操作提示（毛玻璃风格，仅 iOS）
            if (!_isDragging && !_isAnimating)
              Positioned(
                bottom: 48,
                left: 0,
                right: 0,
                child: Center(
                  child: Platform.isIOS
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: _buildHintRow(),
                            ),
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                              width: 1,
                            ),
                          ),
                          child: _buildHintRow(),
                        ),
                ),
              ),

            // 照片信息面板
            if (_showInfo && !_isDragging && !_isAnimating)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: PhotoInfoPanel(
                  photoDate: AppDateUtils.formatFull(_currentPhoto.takenAt),
                  photoSize: _currentPhoto.fileSizeFormatted,
                  photoResolution: _currentPhoto.resolutionFormatted,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// 删除手势轨迹绘制
class _DeleteTrailPainter extends CustomPainter {
  final Offset start;
  final Offset end;
  final double progress;

  const _DeleteTrailPainter({
    required this.start,
    required this.end,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final color = Color.lerp(
      const Color(0xFFFF9800),
      const Color(0xFFFF1744),
      progress,
    )!.withOpacity(0.85);

    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final dist = math.sqrt(dx * dx + dy * dy);
    if (dist < 2) return;

    final ux = dx / dist;
    final uy = dy / dist;
    const dash = 12.0;
    const gap = 5.0;
    double drawn = 0;
    while (drawn < dist) {
      final segEnd = math.min(drawn + dash, dist);
      canvas.drawLine(
        Offset(start.dx + ux * drawn, start.dy + uy * drawn),
        Offset(start.dx + ux * segEnd, start.dy + uy * segEnd),
        paint,
      );
      drawn += dash + gap;
    }

    // 起点圆点
    canvas.drawCircle(start, 6,
        Paint()..color = color..style = PaintingStyle.fill);

    // 终点箭头
    final angle = math.atan2(dy, dx);
    final arrowSize = 10.0 + progress * 8;
    final arrowPath = Path()
      ..moveTo(end.dx + math.cos(angle) * arrowSize,
          end.dy + math.sin(angle) * arrowSize)
      ..lineTo(end.dx + math.cos(angle + 2.5) * arrowSize * 0.6,
          end.dy + math.sin(angle + 2.5) * arrowSize * 0.6)
      ..lineTo(end.dx + math.cos(angle - 2.5) * arrowSize * 0.6,
          end.dy + math.sin(angle - 2.5) * arrowSize * 0.6)
      ..close();
    canvas.drawPath(
        arrowPath, Paint()..color = color..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(_DeleteTrailPainter old) =>
      old.start != start || old.end != end || old.progress != progress;
}
