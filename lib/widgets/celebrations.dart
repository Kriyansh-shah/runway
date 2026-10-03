import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../app/theme.dart';

/// The Home ring's key, so a logged expense can fly into it.
final homeRingKey = GlobalKey(debugLabel: 'homeRing');

/// Bumps each time a coin lands in the ring; [RingPulse] listens.
final ringPulse = ValueNotifier<int>(0);

/// Flies a lime coin from [from] (global position, e.g. the Log button)
/// into the Home ring, then makes the ring pulse. Falls back to just the
/// pulse when motion is reduced or the ring is scrolled out of view.
void flyCoinToRing(BuildContext context, {required Offset from}) {
  final overlay = Overlay.maybeOf(context);
  final ring = homeRingKey.currentContext?.findRenderObject() as RenderBox?;
  final overlayBox = overlay?.context.findRenderObject() as RenderBox?;
  if (overlay == null || ring == null || overlayBox == null || !ring.attached) {
    return;
  }
  final to = overlayBox.globalToLocal(
    ring.localToGlobal(ring.size.center(Offset.zero)),
  );
  final visible = to.dy > 0 && to.dy < overlayBox.size.height;
  if (Motion.reduced(context) || !visible) {
    ringPulse.value++;
    return;
  }
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _Coin(
      from: overlayBox.globalToLocal(from),
      to: to,
      onArrive: () {
        entry.remove();
        HapticFeedback.lightImpact();
        ringPulse.value++;
      },
    ),
  );
  overlay.insert(entry);
}

class _Coin extends StatefulWidget {
  const _Coin({required this.from, required this.to, required this.onArrive});
  final Offset from, to;
  final VoidCallback onArrive;

  @override
  State<_Coin> createState() => _CoinState();
}

class _CoinState extends State<_Coin> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 720),
  )..forward().whenComplete(widget.onArrive);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Arcs up and over, like it's been tossed into the ring.
  Offset _at(double t) {
    final a = widget.from, b = widget.to;
    final ctrl = Offset((a.dx + b.dx) / 2, math.min(a.dy, b.dy) - 150);
    final u = 1 - t;
    return a * (u * u) + ctrl * (2 * u * t) + b * (t * t);
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = Curves.easeInOutCubic.transform(_c.value);
          return Stack(
            children: [
              // A short fading trail behind the coin.
              for (var k = 3; k >= 0; k--)
                _coinAt(
                  _at(math.max(0, t - k * 0.045)),
                  scale: (1 - 0.45 * t) * (1 - k * 0.12),
                  opacity: k == 0 ? 1 : 0.18 / k,
                  spin: t,
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _coinAt(
    Offset p, {
    required double scale,
    required double opacity,
    required double spin,
  }) {
    const d = 34.0;
    return Positioned(
      left: p.dx - d / 2,
      top: p.dy - d / 2,
      child: Opacity(
        opacity: opacity,
        child: Transform(
          alignment: Alignment.center,
          // A gentle flip so it reads as a spinning coin.
          transform: Matrix4.diagonal3Values(
            scale * (0.35 + 0.65 * math.cos(spin * math.pi * 3).abs()),
            scale,
            1,
          ),
          child: Container(
            width: d,
            height: d,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppGradients.brand,
              boxShadow: [
                BoxShadow(
                  color: AppColors.lime.withValues(alpha: 0.5),
                  blurRadius: 16,
                ),
              ],
            ),
            child: const Text(
              r'$',
              style: TextStyle(
                color: AppColors.onLime,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Wraps the Home ring: springs up and glows lime whenever [ringPulse] fires.
class RingPulse extends StatefulWidget {
  const RingPulse({super.key, required this.child});
  final Widget child;

  @override
  State<RingPulse> createState() => _RingPulseState();
}

class _RingPulseState extends State<RingPulse>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController.unbounded(vsync: this, value: 1);

  @override
  void initState() {
    super.initState();
    ringPulse.addListener(_pulse);
  }

  void _pulse() {
    if (!mounted) return;
    _c.animateWith(SpringSimulation(Motion.pressSpring, 1, 1, 2.2));
  }

  @override
  void dispose() {
    ringPulse.removeListener(_pulse);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final bump = (_c.value - 1).clamp(0.0, 0.2);
        return Transform.scale(
          scale: _c.value,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.lime.withValues(alpha: bump * 2.5),
                  blurRadius: 40,
                  spreadRadius: -20,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
    );
  }
}
