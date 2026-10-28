import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../app/theme.dart';
import 'pointer_glow.dart';

/// Translucent card with a hairline border. Deliberately *no* blur — real
/// backdrop blur is reserved for the nav bar and sheets to keep scrolling cheap.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 24,
    this.strong = false,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool strong;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final card = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: strong ? 0.10 : 0.08),
            Colors.white.withValues(alpha: strong ? 0.07 : 0.05),
          ],
        ),
        border: Border.all(color: borderColor ?? AppColors.hairline, width: 1),
      ),
      child: Padding(padding: padding, child: child),
    );
    return PointerGlow.web ? EdgeGlow(radius: radius, child: card) : card;
  }
}

/// Real frosted glass (BackdropFilter). Use sparingly.
class FrostedGlass extends StatelessWidget {
  const FrostedGlass({
    super.key,
    required this.child,
    this.borderRadius = BorderRadius.zero,
    this.sigma = 24,
    this.tint,
    this.border,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final double sigma;
  final Color? tint;
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tint ?? AppColors.surface.withValues(alpha: 0.62),
            borderRadius: borderRadius,
            border: border ?? Border.all(color: AppColors.hairline),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Small rounded label, e.g. "14 days short" or "🔥 12".
class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.label,
    required this.color,
    this.filled = false,
  });

  final String label;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: filled ? 0.22 : 0.14),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 14),
        ],
      ),
      child: Text(
        label,
        style: AppText.label.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
      child: Row(
        children: [
          Expanded(child: Text(title, style: AppText.heading)),
          ?trailing,
        ],
      ),
    );
  }
}

/// Text painted with a gradient.
class GradientText extends StatelessWidget {
  const GradientText(
    this.text, {
    super.key,
    required this.style,
    this.gradient = AppGradients.brand,
  });
  final String text;
  final TextStyle style;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: gradient.createShader,
      child: Text(text, style: style),
    );
  }
}
