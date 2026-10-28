import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/theme.dart';
import 'pointer_glow.dart';

/// Slowly drifting aurora: a few radial-gradient blobs painted directly.
/// No blur filters, so it's cheap to repaint every frame. On the web it's
/// brighter, like the website, with a soft lime glow under the mouse.
class AuroraBackground extends StatefulWidget {
  const AuroraBackground({super.key, required this.child});
  final Widget child;

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 28),
  )..repeat();

  /// Holds still when the phone asks for reduced motion.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: AppColors.bg),
        RepaintBoundary(
          child: CustomPaint(painter: _AuroraPainter(_controller)),
        ),
        widget.child,
      ],
    );
  }
}

class _Blob {
  const _Blob(
    this.color,
    this.anchor,
    this.radius,
    this.orbit,
    this.phase,
    this.alpha,
  );
  final Color color;
  final Offset anchor; // fraction of size
  final double radius; // fraction of shortest side
  final Offset orbit; // fraction of size
  final double phase;
  final double alpha;
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter(this.t)
    : super(repaint: Listenable.merge([t, PointerGlow.position]));
  final Animation<double> t;

  static const _blobs = [
    _Blob(
      AppColors.lilac,
      Offset(0.15, 0.08),
      0.95,
      Offset(0.10, 0.06),
      0,
      0.20,
    ),
    _Blob(
      AppColors.lime,
      Offset(0.95, 0.22),
      0.75,
      Offset(0.08, 0.08),
      2.1,
      0.05,
    ),
    _Blob(
      AppColors.pink,
      Offset(0.75, 0.85),
      0.85,
      Offset(0.12, 0.05),
      4.2,
      0.07,
    ),
    _Blob(
      AppColors.lilac,
      Offset(0.05, 0.70),
      0.70,
      Offset(0.06, 0.10),
      1.3,
      0.09,
    ),
  ];

  static const _webBlobs = [
    _Blob(
      AppColors.lilac,
      Offset(0.15, 0.08),
      0.95,
      Offset(0.10, 0.06),
      0,
      0.30,
    ),
    _Blob(
      AppColors.lime,
      Offset(0.95, 0.22),
      0.75,
      Offset(0.08, 0.08),
      2.1,
      0.10,
    ),
    _Blob(
      AppColors.pink,
      Offset(0.75, 0.85),
      0.85,
      Offset(0.12, 0.05),
      4.2,
      0.13,
    ),
    _Blob(
      AppColors.lilac,
      Offset(0.05, 0.70),
      0.70,
      Offset(0.06, 0.10),
      1.3,
      0.09,
    ),
    _Blob(
      Color(0xFF5EC8FF),
      Offset(0.10, 0.55),
      0.65,
      Offset(0.08, 0.06),
      3.4,
      0.08,
    ),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final a = t.value * 2 * math.pi;
    final shortest = size.shortestSide;
    for (final b in PointerGlow.web ? _webBlobs : _blobs) {
      final center = Offset(
        (b.anchor.dx + b.orbit.dx * math.sin(a + b.phase)) * size.width,
        (b.anchor.dy + b.orbit.dy * math.cos(a * 1.0 + b.phase * 0.7)) *
            size.height,
      );
      final r = b.radius * shortest * (1 + 0.06 * math.sin(a * 2 + b.phase));
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            b.color.withValues(alpha: b.alpha),
            b.color.withValues(alpha: b.alpha * 0.35),
            b.color.withValues(alpha: 0),
          ],
          stops: const [0, 0.45, 1],
        ).createShader(Rect.fromCircle(center: center, radius: r));
      canvas.drawCircle(center, r, paint);
    }
    // Assumes the aurora fills the window, as it does on every screen.
    if (PointerGlow.position.value case final mouse?) {
      const r = 260.0;
      canvas.drawCircle(
        mouse,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [
              AppColors.lime.withValues(alpha: 0.10),
              AppColors.lime.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: mouse, radius: r)),
      );
    }
  }

  @override
  bool shouldRepaint(_AuroraPainter old) => false;
}
