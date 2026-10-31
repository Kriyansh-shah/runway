import 'package:flutter/material.dart';

import '../app/theme.dart';
import 'pointer_glow.dart';
import 'pressable.dart';

/// Gradient CTA with a soft neon glow.
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onTap,
    this.gradient = AppGradients.brand,
    this.glow = AppColors.lime,
    this.icon,
    this.height = 56,
  });

  final String label;
  final VoidCallback? onTap;
  final Gradient gradient;
  final Color glow;
  final IconData? icon;
  final double height;

  /// Dark ink on light gradients (lime, lilac), white on dark ones.
  Color get _ink {
    final first = gradient is LinearGradient
        ? (gradient as LinearGradient).colors.first
        : AppColors.lime;
    return ThemeData.estimateBrightnessForColor(first) == Brightness.light
        ? AppColors.onLime
        : Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Pressable(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: Motion.med,
        opacity: enabled ? 1 : 0.4,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(height / 2),
            boxShadow: [
              BoxShadow(
                color: glow.withValues(
                  alpha: enabled ? (PointerGlow.web ? 0.45 : 0.28) : 0,
                ),
                blurRadius: PointerGlow.web ? 30 : 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: _ink, size: 20),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: AppText.heading.copyWith(
                      color: _ink,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
