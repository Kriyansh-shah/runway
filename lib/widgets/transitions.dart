import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Reveals the next page through an expanding circle that starts at
/// [center] (global coordinates), with a neon ring riding the edge.
class CircularRevealRoute<T> extends PageRouteBuilder<T> {
  CircularRevealRoute({required this.center, required WidgetBuilder builder})
    : super(
        transitionDuration: const Duration(milliseconds: 950),
        reverseTransitionDuration: Motion.slow,
        pageBuilder: (context, _, _) => builder(context),
      );

  final Offset center;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeInOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return AnimatedBuilder(
      animation: curved,
      child: child,
      builder: (context, child) {
        final t = curved.value;
        if (t >= 1) return child!;
        final size = MediaQuery.sizeOf(context);
        final maxRadius = _farthestCorner(center, size);
        final radius = maxRadius * t;
        return Stack(
          children: [
            ClipPath(
              clipper: _CircleClipper(center, radius),
              // Content settles in from a slight zoom as the circle opens.
              child: Transform.scale(scale: 1.08 - 0.08 * t, child: child),
            ),
            IgnorePointer(
              child: CustomPaint(
                size: size,
                painter: _RingPainter(center, radius, 1 - t),
              ),
            ),
          ],
        );
      },
    );
  }

  static double _farthestCorner(Offset c, Size s) => [
    Offset.zero,
    Offset(s.width, 0),
    Offset(0, s.height),
    Offset(s.width, s.height),
  ].map((p) => (p - c).distance).reduce(math.max);
}

class _CircleClipper extends CustomClipper<Path> {
  _CircleClipper(this.center, this.radius);
  final Offset center;
  final double radius;

  @override
  Path getClip(Size size) =>
      Path()..addOval(Rect.fromCircle(center: center, radius: radius));

  @override
  bool shouldReclip(_CircleClipper old) =>
      old.radius != radius || old.center != center;
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.center, this.radius, this.strength);
  final Offset center;
  final double radius;
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    if (radius <= 0 || strength <= 0) return;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final shader = const SweepGradient(
      colors: [
        AppColors.violet,
        AppColors.cyan,
        AppColors.pink,
        AppColors.violet,
      ],
    ).createShader(rect);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18
        ..shader = shader
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14)
        ..color = Colors.white.withValues(alpha: strength),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..shader = shader,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.radius != radius || old.strength != strength;
}

/// Gentle fade + zoom-out, used when signing out.
class FadeScaleRoute<T> extends PageRouteBuilder<T> {
  FadeScaleRoute({required WidgetBuilder builder})
    : super(
        transitionDuration: Motion.slow,
        reverseTransitionDuration: Motion.med,
        pageBuilder: (context, _, _) => builder(context),
        transitionsBuilder: (context, animation, _, child) {
          final a = CurvedAnimation(parent: animation, curve: Motion.out);
          return FadeTransition(
            opacity: a,
            child: ScaleTransition(
              scale: Tween(begin: 1.06, end: 1.0).animate(a),
              child: child,
            ),
          );
        },
      );
}
