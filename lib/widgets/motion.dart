import 'package:flutter/material.dart';

import '../app/format.dart';
import '../app/theme.dart';

/// Number that rolls to its new value (easeOutExpo). Rolls up from zero the
/// first time it appears.
class RollingNumber extends StatelessWidget {
  const RollingNumber({
    super.key,
    required this.value,
    required this.style,
    this.format,
    this.duration = Motion.slow,
  });

  final double value;
  final TextStyle style;
  final String Function(double)? format;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: duration,
      curve: Motion.roll,
      builder: (context, v, _) => Text(
        (format ?? money)(v),
        style: style,
        maxLines: 1,
        softWrap: false,
      ),
    );
  }
}

/// Fade + slide-up entrance, delayed by [index] × [Motion.stagger].
class Entrance extends StatefulWidget {
  const Entrance({super.key, required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curve;

  @override
  void initState() {
    super.initState();
    final delay = Motion.stagger * widget.index;
    final total = delay + Motion.slow;
    _controller = AnimationController(vsync: this, duration: total)..forward();
    _curve = CurvedAnimation(
      parent: _controller,
      curve: Interval(
        delay.inMicroseconds / total.inMicroseconds,
        1,
        curve: Motion.out,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(_curve),
        child: widget.child,
      ),
    );
  }
}
