import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../app/theme.dart';

/// Springy press feedback: dips on touch, then bounces back with real
/// spring physics (interruptible, so fast repeated taps never stutter),
/// plus a light haptic tick.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.95,
    this.haptic = true,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final bool haptic;
  final String? semanticLabel;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable>
    with SingleTickerProviderStateMixin {
  late final _scale = AnimationController.unbounded(vsync: this, value: 1);

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  void _down() {
    if (widget.haptic) HapticFeedback.lightImpact();
    _scale.animateTo(widget.scale, duration: Motion.fast, curve: Motion.out);
  }

  void _up() => _scale.animateWith(
    SpringSimulation(Motion.pressSpring, _scale.value, 1, _scale.velocity),
  );

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _down() : null,
        onTapCancel: _up,
        onTapUp: (_) => _up(),
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: ScaleTransition(scale: _scale, child: widget.child),
      ),
    );
  }
}
