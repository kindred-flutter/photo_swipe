import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:io';

/// iOS 风格的毛玻璃容器
///
/// 提供模糊背景效果，适用于浮动面板、底部导航栏等 UI 元素
class GlassmorphicContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final Color color;
  final double opacity;
  final BorderRadius? borderRadius;
  final EdgeInsets padding;
  final BoxBorder? border;
  final List<BoxShadow>? boxShadow;

  const GlassmorphicContainer({
    super.key,
    required this.child,
    this.blur = 20.0,
    this.color = const Color(0xFFFFFFFF),
    this.opacity = 0.15,
    this.borderRadius,
    this.padding = const EdgeInsets.all(0),
    this.border,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = color.withAlpha((opacity * 255).round());

    // 非 iOS 平台退回普通半透明容器
    if (!Platform.isIOS) {
      return Container(
        padding: padding,
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: borderRadius,
          border: border,
          boxShadow: boxShadow,
        ),
        child: child,
      );
    }

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: borderRadius,
            border: border,
            boxShadow: boxShadow,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// 预设的毛玻璃样式
class GlassmorphicStyle {
  GlassmorphicStyle._();

  /// 浅色主题 - 底部导航栏风格
  static GlassmorphicContainer lightNavBar({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(0),
  }) {
    return GlassmorphicContainer(
      blur: 25.0,
      color: const Color(0xFFFFFFFF),
      opacity: 0.72,
      padding: padding,
      border: Border(
        top: BorderSide(
          color: Colors.white.withAlpha(76), // 0.3 * 255
          width: 1,
        ),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withAlpha(20), // 0.08 * 255
          blurRadius: 12,
          offset: const Offset(0, -2),
        ),
      ],
      child: child,
    );
  }

  /// 深色主题 - 底部导航栏风格
  static GlassmorphicContainer darkNavBar({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(0),
  }) {
    return GlassmorphicContainer(
      blur: 25.0,
      color: const Color(0xFF1A1A1A),
      opacity: 0.72,
      padding: padding,
      border: Border(
        top: BorderSide(
          color: Colors.white.withAlpha(25), // 0.1 * 255
          width: 1,
        ),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withAlpha(76), // 0.3 * 255
          blurRadius: 12,
          offset: const Offset(0, -2),
        ),
      ],
      child: child,
    );
  }

  /// 浅色主题 - 模态框/面板风格
  static GlassmorphicContainer lightPanel({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(16),
    BorderRadius? borderRadius,
  }) {
    return GlassmorphicContainer(
      blur: 20.0,
      color: const Color(0xFFFFFFFF),
      opacity: 0.85,
      padding: padding,
      borderRadius: borderRadius ?? BorderRadius.circular(20),
      border: Border.all(
        color: Colors.white.withAlpha(102), // 0.4 * 255
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withAlpha(25), // 0.1 * 255
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ],
      child: child,
    );
  }

  /// 深色主题 - 模态框/面板风格
  static GlassmorphicContainer darkPanel({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(16),
    BorderRadius? borderRadius,
  }) {
    return GlassmorphicContainer(
      blur: 20.0,
      color: const Color(0xFF2A2A2A),
      opacity: 0.85,
      padding: padding,
      borderRadius: borderRadius ?? BorderRadius.circular(20),
      border: Border.all(
        color: Colors.white.withAlpha(38), // 0.15 * 255
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withAlpha(76), // 0.3 * 255
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ],
      child: child,
    );
  }

  /// 浅色主题 - 浮动按钮风格
  static GlassmorphicContainer lightFloating({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(12),
    BorderRadius? borderRadius,
  }) {
    return GlassmorphicContainer(
      blur: 15.0,
      color: const Color(0xFFFFFFFF),
      opacity: 0.8,
      padding: padding,
      borderRadius: borderRadius ?? BorderRadius.circular(16),
      border: Border.all(
        color: Colors.white.withAlpha(127), // 0.5 * 255
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withAlpha(30), // 0.12 * 255
          blurRadius: 16,
          offset: const Offset(0, 2),
        ),
      ],
      child: child,
    );
  }

  /// 深色主题 - 浮动按钮风格
  static GlassmorphicContainer darkFloating({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(12),
    BorderRadius? borderRadius,
  }) {
    return GlassmorphicContainer(
      blur: 15.0,
      color: const Color(0xFF333333),
      opacity: 0.8,
      padding: padding,
      borderRadius: borderRadius ?? BorderRadius.circular(16),
      border: Border.all(
        color: Colors.white.withAlpha(51), // 0.2 * 255
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withAlpha(63), // 0.25 * 255
          blurRadius: 16,
          offset: const Offset(0, 2),
        ),
      ],
      child: child,
    );
  }
}
