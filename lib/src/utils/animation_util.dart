import 'package:flutter/material.dart';

/// iOS风格页面过渡动画
/// 遵循Apple Human Interface Guidelines的动画规范

/// iOS风格的页面路由 - 从右滑入
class IOSPageRoute<T> extends PageRouteBuilder<T> {
  IOSPageRoute({
    required this.page,
    super.settings,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 300),
        );

  final Widget page;
}

/// 淡入淡出页面路由
class FadePageRoute<T> extends PageRouteBuilder<T> {
  FadePageRoute({
    required this.page,
    super.settings,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOut,
              ),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 250),
        );

  final Widget page;
}

/// 缩放淡入页面路由 - 适用于模态页面
class ScaleFadePageRoute<T> extends PageRouteBuilder<T> {
  ScaleFadePageRoute({
    required this.page,
    super.settings,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return ScaleTransition(
              scale: Tween<double>(
                begin: 0.9,
                end: 1.0,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: FadeTransition(
                opacity: animation,
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        );

  final Widget page;
}

/// 底部弹出页面路由 - 适用于底部弹窗全屏化
class BottomSheetPageRoute<T> extends PageRouteBuilder<T> {
  BottomSheetPageRoute({
    required this.page,
    super.settings,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 1.0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          opaque: false,
          barrierColor: Colors.black54,
          barrierDismissible: true,
        );

  final Widget page;
}

/// 动画工具类
class AnimationUtil {
  /// iOS标准动画曲线
  static const Curve iosEaseOut = Curves.easeOutCubic;
  static const Curve iosEaseIn = Curves.easeInCubic;
  static const Curve iosEaseInOut = Curves.easeInOutCubic;
  static const Curve iosSpring = Curves.elasticOut;

  /// iOS标准动画时长
  static const Duration shortDuration = Duration(milliseconds: 200);
  static const Duration mediumDuration = Duration(milliseconds: 350);
  static const Duration longDuration = Duration(milliseconds: 500);

  /// 创建弹性动画控制器
  static AnimationController createSpringController(
    TickerProvider vsync, {
    Duration duration = const Duration(milliseconds: 400),
  }) {
    return AnimationController(
      vsync: vsync,
      duration: duration,
    );
  }

  /// 创建淡入动画
  static Animation<double> createFadeIn(AnimationController controller) {
    return Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: controller, curve: iosEaseOut),
    );
  }

  /// 创建滑动动画
  static Animation<Offset> createSlideIn(
    AnimationController controller, {
    Offset begin = const Offset(0.0, 0.1),
  }) {
    return Tween<Offset>(begin: begin, end: Offset.zero).animate(
      CurvedAnimation(parent: controller, curve: iosEaseOut),
    );
  }

  /// 创建缩放动画
  static Animation<double> createScale(
    AnimationController controller, {
    double begin = 0.95,
    double end = 1.0,
  }) {
    return Tween<double>(begin: begin, end: end).animate(
      CurvedAnimation(parent: controller, curve: iosEaseOut),
    );
  }
}

/// 交错动画列表项
/// 用于列表项依次出现的效果
class StaggeredListItem extends StatefulWidget {
  const StaggeredListItem({
    super.key,
    required this.index,
    required this.child,
    this.duration = const Duration(milliseconds: 400),
    this.delay = const Duration(milliseconds: 50),
  });

  final int index;
  final Widget child;
  final Duration duration;
  final Duration delay;

  @override
  State<StaggeredListItem> createState() => _StaggeredListItemState();
}

class _StaggeredListItemState extends State<StaggeredListItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    // 延迟启动动画
    Future.delayed(widget.delay * widget.index, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}

/// 脉冲动画组件 - 用于强调重要元素
class PulseAnimation extends StatefulWidget {
  const PulseAnimation({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1500),
    this.minScale = 0.95,
    this.maxScale = 1.05,
  });

  final Widget child;
  final Duration duration;
  final double minScale;
  final double maxScale;

  @override
  State<PulseAnimation> createState() => _PulseAnimationState();
}

class _PulseAnimationState extends State<PulseAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _animation = Tween<double>(
      begin: widget.minScale,
      end: widget.maxScale,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _animation,
      child: widget.child,
    );
  }
}

/// 抖动动画组件 - 用于错误提示
class ShakeAnimation extends StatefulWidget {
  const ShakeAnimation({
    super.key,
    required this.child,
    this.shakeCount = 3,
    this.shakeOffset = 10.0,
    required this.animate,
  });

  final Widget child;
  final int shakeCount;
  final double shakeOffset;
  final bool animate;

  @override
  State<ShakeAnimation> createState() => _ShakeAnimationState();
}

class _ShakeAnimationState extends State<ShakeAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticIn),
    );
  }

  @override
  void didUpdateWidget(ShakeAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !oldWidget.animate) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final sineValue = _animation.value * widget.shakeCount * 3.14159;
        return Transform.translate(
          offset: Offset(
            widget.shakeOffset * (1 - _animation.value) * 
                (sineValue != 0 ? (sineValue / sineValue.abs()) * 
                (1 - (_animation.value)) : 0),
            0,
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// 成功打勾动画组件
class CheckmarkAnimation extends StatefulWidget {
  const CheckmarkAnimation({
    super.key,
    this.size = 80,
    this.color,
    this.autoPlay = true,
  });

  final double size;
  final Color? color;
  final bool autoPlay;

  @override
  State<CheckmarkAnimation> createState() => _CheckmarkAnimationState();
}

class _CheckmarkAnimationState extends State<CheckmarkAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    if (widget.autoPlay) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Colors.green;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _CheckmarkPainter(
              progress: _controller.value,
              color: color,
            ),
          );
        },
      ),
    );
  }
}

class _CheckmarkPainter extends CustomPainter {
  _CheckmarkPainter({
    required this.progress,
    required this.color,
  });

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.08
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - paint.strokeWidth;

    // 绘制圆圈
    if (progress > 0) {
      final circleProgress = (progress * 2).clamp(0.0, 1.0);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -1.5708, // -90度，从顶部开始
        6.2832 * circleProgress, // 360度
        false,
        paint,
      );
    }

    // 绘制勾
    if (progress > 0.5) {
      final checkProgress = ((progress - 0.5) * 2).clamp(0.0, 1.0);

      final path = Path();
      final startPoint = Offset(size.width * 0.25, size.height * 0.5);
      final middlePoint = Offset(size.width * 0.45, size.height * 0.7);
      final endPoint = Offset(size.width * 0.75, size.height * 0.35);

      if (checkProgress <= 0.5) {
        final firstPartProgress = checkProgress * 2;
        final currentPoint = Offset(
          startPoint.dx + (middlePoint.dx - startPoint.dx) * firstPartProgress,
          startPoint.dy + (middlePoint.dy - startPoint.dy) * firstPartProgress,
        );
        path.moveTo(startPoint.dx, startPoint.dy);
        path.lineTo(currentPoint.dx, currentPoint.dy);
      } else {
        final secondPartProgress = (checkProgress - 0.5) * 2;
        final currentPoint = Offset(
          middlePoint.dx + (endPoint.dx - middlePoint.dx) * secondPartProgress,
          middlePoint.dy + (endPoint.dy - middlePoint.dy) * secondPartProgress,
        );
        path.moveTo(startPoint.dx, startPoint.dy);
        path.lineTo(middlePoint.dx, middlePoint.dy);
        path.lineTo(currentPoint.dx, currentPoint.dy);
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_CheckmarkPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
