import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

enum SwipeState { idle, tracking, nearTrigger, triggered, cancelled }

class SwipeToDeleteDetector extends StatefulWidget {
  final Widget child;
  final VoidCallback onDeleted;
  final bool enabled;

  const SwipeToDeleteDetector({
    super.key,
    required this.child,
    required this.onDeleted,
    this.enabled = true,
  });

  @override
  State<SwipeToDeleteDetector> createState() => _SwipeToDeleteDetectorState();
}

class _SwipeToDeleteDetectorState extends State<SwipeToDeleteDetector>
    with SingleTickerProviderStateMixin {
  SwipeState _state = SwipeState.idle;
  Offset _startPos = Offset.zero;
  Offset _currentPos = Offset.zero;
  late AnimationController _resetController;
  late Animation<Offset> _resetAnimation;

  // 手势判断参数
  static const double _minDistance = 100.0;
  static const double _minAngle = 30.0 * math.pi / 180;
  static const double _maxAngle = 60.0 * math.pi / 180;

  @override
  void initState() {
    super.initState();
    _resetController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _resetAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _resetController,
      curve: Curves.elasticOut,
    ));
    _resetController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _resetController.dispose();
    super.dispose();
  }

  Offset get _dragOffset {
    if (_state == SwipeState.idle || _state == SwipeState.cancelled) {
      return _resetAnimation.value;
    }
    return _currentPos - _startPos;
  }

  bool _isValidSwipe(Offset start, Offset end, Size screenSize) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final distance = math.sqrt(dx * dx + dy * dy);

    if (distance < _minDistance) return false;

    // 方向：右上方（dx > 0, dy < 0）
    if (dx <= 0 || dy >= 0) return false;

    // 角度检查（以水平为基准，向上为负 y）
    final angle = math.atan2(-dy, dx);
    return angle >= _minAngle && angle <= _maxAngle;
  }

  void _onPanStart(DragStartDetails details) {
    if (!widget.enabled) return;
    _startPos = details.localPosition;
    _currentPos = details.localPosition;
    setState(() => _state = SwipeState.tracking);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_state == SwipeState.idle || _state == SwipeState.cancelled) return;
    _currentPos = details.localPosition;
    final dx = _currentPos.dx - _startPos.dx;
    final dy = _currentPos.dy - _startPos.dy;
    final distance = math.sqrt(dx * dx + dy * dy);

    if (distance > _minDistance * 0.7 && dx > 0 && dy < 0) {
      setState(() => _state = SwipeState.nearTrigger);
    } else {
      setState(() => _state = SwipeState.tracking);
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (_state == SwipeState.idle) return;
    final screenSize = MediaQuery.of(context).size;
    if (_isValidSwipe(_startPos, _currentPos, screenSize)) {
      HapticFeedback.mediumImpact();
      setState(() => _state = SwipeState.triggered);
      widget.onDeleted();
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) setState(() => _state = SwipeState.idle);
      });
    } else {
      _resetAnimation = Tween<Offset>(
        begin: _currentPos - _startPos,
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _resetController,
        curve: Curves.elasticOut,
      ));
      setState(() => _state = SwipeState.cancelled);
      _resetController.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final offset = _dragOffset;
    final progress = _state == SwipeState.nearTrigger ||
            _state == SwipeState.triggered
        ? 1.0
        : 0.0;

    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Transform.translate(
            offset: offset,
            child: Transform.scale(
              scale: _state == SwipeState.tracking ||
                      _state == SwipeState.nearTrigger
                  ? 0.95
                  : 1.0,
              child: Opacity(
                opacity: _state == SwipeState.triggered ? 0.0 : 1.0,
                child: widget.child,
              ),
            ),
          ),
          // 轨迹绘制
          if (_state == SwipeState.tracking ||
              _state == SwipeState.nearTrigger)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _TrajectoryPainter(
                    start: _startPos,
                    end: _currentPos,
                    progress: progress,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TrajectoryPainter extends CustomPainter {
  final Offset start;
  final Offset end;
  final double progress;

  _TrajectoryPainter({
    required this.start,
    required this.end,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Color.lerp(
        const Color(0xFFFF5252),
        const Color(0xFFFF1744),
        progress,
      )!
          .withOpacity(0.7)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // 虚线轨迹
    const dashLen = 8.0;
    const gapLen = 4.0;
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final dist = math.sqrt(dx * dx + dy * dy);
    if (dist < 1) return;
    final ux = dx / dist;
    final uy = dy / dist;
    double drawn = 0;
    while (drawn < dist) {
      final segEnd = math.min(drawn + dashLen, dist);
      canvas.drawLine(
        Offset(start.dx + ux * drawn, start.dy + uy * drawn),
        Offset(start.dx + ux * segEnd, start.dy + uy * segEnd),
        paint,
      );
      drawn += dashLen + gapLen;
    }

    // 终点箭头圆圈
    canvas.drawCircle(
      end,
      progress > 0.5 ? 12 : 8,
      paint..style = PaintingStyle.fill..color = paint.color.withOpacity(0.5),
    );
  }

  @override
  bool shouldRepaint(_TrajectoryPainter old) =>
      old.start != start || old.end != end || old.progress != progress;
}
