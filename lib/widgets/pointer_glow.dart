import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../app/theme.dart';

/// The website's look, in the web app only: the mouse effects here, plus a
/// brighter aurora, a shinier logo and stronger button glow. The iPhone and
/// Android apps keep their own look.
abstract final class PointerGlow {
  static const web = kIsWeb;

  /// Where the mouse is, in global coordinates, or null when there's no
  /// mouse over the app. [PointerTracker] keeps it up to date; the aurora,
  /// [EdgeGlow] and [PointerTilt] follow it.
  static final position = ValueNotifier<Offset?>(null);
}

/// Feeds [PointerGlow.position] from mouse hovers anywhere below it.
class PointerTracker extends StatelessWidget {
  const PointerTracker({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!PointerGlow.web) return child;
    return MouseRegion(
      opaque: false,
      hitTestBehavior: HitTestBehavior.translucent,
      onHover: (e) => PointerGlow.position.value = e.position,
      onExit: (_) => PointerGlow.position.value = null,
      child: child,
    );
  }
}

/// Paints a glass edge over [child]: a faint sheen along the top, and a lime
/// glow on the border near the mouse, with a soft light inside when the mouse
/// is over it.
class EdgeGlow extends SingleChildRenderObjectWidget {
  const EdgeGlow({super.key, required this.radius, super.child});
  final double radius;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderEdgeGlow(radius);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderEdgeGlow).radius = radius;
  }
}

class _RenderEdgeGlow extends RenderProxyBox {
  _RenderEdgeGlow(this._radius);

  static const _reach = 220.0;

  double _radius;
  set radius(double value) {
    if (value == _radius) return;
    _radius = value;
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    PointerGlow.position.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    PointerGlow.position.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    final rect = offset & size;
    final edge = RRect.fromRectAndRadius(
      rect.deflate(0.5),
      Radius.circular(_radius),
    );
    final canvas = context.canvas;
    canvas.drawRRect(
      edge,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.28),
            Colors.white.withValues(alpha: 0),
          ],
          stops: const [0, 0.45],
        ).createShader(rect),
    );

    final global = PointerGlow.position.value;
    if (global == null) return;
    final mouse = globalToLocal(global) + offset;
    final dx = math.max(
      0.0,
      (mouse.dx - rect.center.dx).abs() - rect.width / 2,
    );
    final dy = math.max(
      0.0,
      (mouse.dy - rect.center.dy).abs() - rect.height / 2,
    );
    if (dx * dx + dy * dy > _reach * _reach) return;

    final spot = Rect.fromCircle(center: mouse, radius: _reach);
    canvas.drawRRect(
      edge,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..shader = RadialGradient(
          colors: [
            AppColors.lime.withValues(alpha: 0.85),
            AppColors.lime.withValues(alpha: 0),
          ],
        ).createShader(spot),
    );
    if (rect.contains(mouse)) {
      canvas.drawRRect(
        edge,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.white.withValues(alpha: 0.07),
              Colors.white.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: mouse, radius: 280)),
      );
    }
  }
}

/// Leans [child] toward the mouse while it's nearby.
class PointerTilt extends StatefulWidget {
  const PointerTilt({super.key, required this.child, this.maxDegrees = 10});
  final Widget child;
  final double maxDegrees;

  @override
  State<PointerTilt> createState() => _PointerTiltState();
}

class _PointerTiltState extends State<PointerTilt> {
  Offset _lean(Offset? global) {
    final box = context.findRenderObject() as RenderBox?;
    if (global == null || box == null || !box.hasSize) return Offset.zero;
    final local = box.globalToLocal(global);
    final x = (local.dx / box.size.width - 0.5) * 2;
    final y = (local.dy / box.size.height - 0.5) * 2;
    if (x.abs() > 1.6 || y.abs() > 1.6) return Offset.zero;
    return Offset(x.clamp(-1.0, 1.0), y.clamp(-1.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    if (!PointerGlow.web || Motion.reduced(context)) return widget.child;
    final max = widget.maxDegrees * math.pi / 180;
    return ValueListenableBuilder<Offset?>(
      valueListenable: PointerGlow.position,
      builder: (context, global, child) => TweenAnimationBuilder<Offset>(
        tween: Tween(end: _lean(global)),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        builder: (context, lean, child) => Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateX(-lean.dy * max)
            ..rotateY(lean.dx * max),
          child: child,
        ),
        child: child,
      ),
      child: widget.child,
    );
  }
}
