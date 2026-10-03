import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/budget_math.dart';
import '../app/theme.dart';

/// Mochi, the money pet. A soft blob that breathes and blinks; colour and
/// expression follow budget health.
class Mochi extends StatefulWidget {
  const Mochi({super.key, required this.mood, this.size = 150});
  final PetMood mood;
  final double size;

  @override
  State<Mochi> createState() => _MochiState();
}

class _MochiState extends State<Mochi> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3800),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Mochi the money pet, feeling ${widget.mood.label.toLowerCase()}',
      child: RepaintBoundary(
        child: SizedBox.square(
          dimension: widget.size,
          child: CustomPaint(painter: _MochiPainter(_controller, widget.mood)),
        ),
      ),
    );
  }
}

class _MochiPainter extends CustomPainter {
  _MochiPainter(this.t, this.mood) : super(repaint: t);
  final Animation<double> t;
  final PetMood mood;

  List<Color> get _colors => switch (mood) {
    PetMood.thriving => const [Color(0xFFE2FF94), AppColors.lime],
    PetMood.chill => const [Color(0xFFD6CAFF), Color(0xFF8F78FF)],
    PetMood.worried => const [AppColors.butter, AppColors.red],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final v = t.value;
    final breath = math.sin(v * 2 * math.pi);
    // Blink twice per cycle-ish: a quick close near the end of the loop.
    final blinkPhase = ((v - 0.86) / 0.06).clamp(0.0, 1.0);
    final eyeOpen = 1 - math.sin(blinkPhase * math.pi);

    final w = size.width;
    final cx = w / 2;
    final baseY = size.height * 0.86;
    final rx = w * 0.38 * (1 - 0.025 * breath);
    final ry = w * 0.34 * (1 + 0.045 * breath);
    final cy = baseY - ry * 0.8;
    final top = cy - ry;
    final bottom = baseY;

    // Ground shadow + neon glow.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, baseY + 4),
        width: rx * 1.7,
        height: w * 0.07,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.35),
    );
    canvas.drawCircle(
      Offset(cx, cy),
      rx * 1.35,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                _colors.last.withValues(alpha: 0.35),
                _colors.last.withValues(alpha: 0),
              ],
            ).createShader(
              Rect.fromCircle(center: Offset(cx, cy), radius: rx * 1.35),
            ),
    );

    // Body.
    final body = Path()
      ..moveTo(cx, top)
      ..cubicTo(
        cx + rx * 0.78,
        top,
        cx + rx,
        cy - ry * 0.35,
        cx + rx,
        cy + ry * 0.2,
      )
      ..cubicTo(cx + rx, cy + ry * 0.72, cx + rx * 0.62, bottom, cx, bottom)
      ..cubicTo(
        cx - rx * 0.62,
        bottom,
        cx - rx,
        cy + ry * 0.72,
        cx - rx,
        cy + ry * 0.2,
      )
      ..cubicTo(cx - rx, cy - ry * 0.35, cx - rx * 0.78, top, cx, top)
      ..close();
    final bounds = body.getBounds();
    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _colors,
        ).createShader(bounds),
    );
    // Soft top highlight.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx - rx * 0.35, top + ry * 0.38),
        width: rx * 0.55,
        height: ry * 0.26,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.35),
    );

    // Face.
    final eyeY = cy + ry * 0.05;
    final eyeDx = rx * 0.36;
    final eyeR = w * 0.045;
    final ink = Paint()..color = const Color(0xFF1A1030);
    for (final side in [-1, 1]) {
      final c = Offset(cx + side * eyeDx, eyeY);
      if (mood == PetMood.thriving && eyeOpen > 0.5) {
        // Happy ^ ^ eyes.
        final p = Path()
          ..moveTo(c.dx - eyeR, c.dy + eyeR * 0.4)
          ..quadraticBezierTo(
            c.dx,
            c.dy - eyeR * 1.4,
            c.dx + eyeR,
            c.dy + eyeR * 0.4,
          );
        canvas.drawPath(
          p,
          Paint()
            ..color = ink.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = w * 0.022
            ..strokeCap = StrokeCap.round,
        );
      } else {
        canvas.drawOval(
          Rect.fromCenter(
            center: c,
            width: eyeR * 2,
            height: math.max(w * 0.012, eyeR * 2.2 * eyeOpen),
          ),
          ink,
        );
        if (eyeOpen > 0.6) {
          canvas.drawCircle(
            c.translate(-eyeR * 0.3, -eyeR * 0.4),
            eyeR * 0.35,
            Paint()..color = Colors.white,
          );
        }
      }
      // Blush.
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx + side * eyeDx * 1.55, eyeY + eyeR * 2.0),
          width: eyeR * 2.4,
          height: eyeR * 1.2,
        ),
        Paint()..color = AppColors.pink.withValues(alpha: 0.45),
      );
    }

    // Mouth.
    final mouthY = eyeY + eyeR * 2.3;
    final mw = rx * 0.22;
    final mouth = Path()..moveTo(cx - mw, mouthY);
    switch (mood) {
      case PetMood.thriving:
        mouth.quadraticBezierTo(cx, mouthY + mw * 1.3, cx + mw, mouthY);
      case PetMood.chill:
        mouth.quadraticBezierTo(cx, mouthY + mw * 0.6, cx + mw, mouthY);
      case PetMood.worried:
        mouth
          ..moveTo(cx - mw, mouthY + mw * 0.3)
          ..quadraticBezierTo(
            cx - mw / 2,
            mouthY - mw * 0.3,
            cx,
            mouthY + mw * 0.2,
          )
          ..quadraticBezierTo(cx + mw / 2, mouthY + mw * 0.7, cx + mw, mouthY);
    }
    canvas.drawPath(
      mouth,
      Paint()
        ..color = ink.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.02
        ..strokeCap = StrokeCap.round,
    );

    if (mood == PetMood.worried) {
      // Sweat drop.
      final d = Offset(cx + rx * 0.7, top + ry * 0.5 + 3 * breath);
      final drop = Path()
        ..moveTo(d.dx, d.dy - eyeR * 1.4)
        ..quadraticBezierTo(d.dx + eyeR, d.dy, d.dx, d.dy + eyeR * 0.6)
        ..quadraticBezierTo(d.dx - eyeR, d.dy, d.dx, d.dy - eyeR * 1.4);
      canvas.drawPath(
        drop,
        Paint()..color = AppColors.lime.withValues(alpha: 0.85),
      );
    }
  }

  @override
  bool shouldRepaint(_MochiPainter old) => old.mood != mood;
}
