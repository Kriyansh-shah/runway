import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../app/theme.dart';

/// "Mochi's Takeoff" — the launch intro.
///
/// Everything is a pure function of time `t` (seconds), ported beat for beat
/// from the approved web prototype, so skipping or scrubbing is just setting
/// `t`. Beats:
///   0.00–0.60  runway draws, landing lights blink on
///   0.55–2.22  Mochi hops in; each letter of "runway" pops up to catch it
///   2.22–2.95  Mochi flattens the y, looks at you, blinks, hops it back up
///   2.95–3.60  lights race, Mochi zooms off, the word glides up into the logo
///   3.60–4.30  Mochi lands on the logo's y; the login card rises
const double kTakeoffEnd = 4.3;

/// When Mochi has landed on the logo (used to start the reveal into Home).
const double kTakeoffLanded = 4.15;

const _word = 'runway';
const _fontSize = 58.0;
const _xHeightEm = 0.528; // Bricolage Grotesque OS/2 sxHeight / unitsPerEm
const logoScale = 0.78;

const _land = [0.95, 1.20, 1.45, 1.70, 1.95, 2.20];
const _lights = 11;

// --------------------------------------------------------------------- maths

double _clamp(double v, [double a = 0, double b = 1]) =>
    v < a ? a : (v > b ? b : v);
double _lerp(double a, double b, double t) => a + (b - a) * t;
double _prog(double t, double a, double b) => _clamp((t - a) / (b - a));
double _easeOutCubic(double t) => 1 - math.pow(1 - t, 3).toDouble();
double _easeInCubic(double t) => t * t * t;
double _easeInOut(double t) =>
    t < .5 ? 4 * t * t * t : 1 - math.pow(-2 * t + 2, 3) / 2;

/// Damped spring 0 → 1 with overshoot.
double _spring(double tau, [double w = 22, double z = 0.42]) => tau <= 0
    ? 0
    : 1 - math.exp(-z * w * tau) * math.cos(w * math.sqrt(1 - z * z) * tau);

/// Decaying wobble that starts at 1.
double _wobble(double tau, [double k = 11, double w = 24]) =>
    tau < 0 ? 0 : math.exp(-k * tau) * math.cos(w * tau);

// -------------------------------------------------------------- the wordmark

/// Measured "runway" letters in the logo face.
class LogoLetters {
  LogoLetters._(this.letters, this.width);

  factory LogoLetters.measure() {
    TextPainter tp(String s, Color c) => TextPainter(
      text: TextSpan(text: s, style: _style(c)),
      textDirection: TextDirection.ltr,
    )..layout();
    final full = tp(_word, AppColors.text);
    final width = full.width;
    final letters = <LogoLetter>[];
    for (var i = 0; i < _word.length; i++) {
      final x = i == 0 ? 0.0 : tp(_word.substring(0, i), AppColors.text).width;
      final painter = tp(_word[i], i == 5 ? AppColors.lime : AppColors.text);
      letters.add(
        LogoLetter(
          painter,
          x - width / 2 + painter.width / 2,
          painter.computeDistanceToActualBaseline(TextBaseline.alphabetic),
        ),
      );
    }
    return LogoLetters._(letters, width);
  }

  static TextStyle _style(Color c) => TextStyle(
    fontFamily: 'Bricolage',
    fontSize: _fontSize,
    height: 1,
    color: c,
    letterSpacing: -1.5,
    fontVariations: const [
      FontVariation('wght', 800),
      FontVariation('opsz', 96),
    ],
  );

  final List<LogoLetter> letters;

  /// Total word width at scale 1.
  final double width;

  double get xHeight => _fontSize * _xHeightEm;

  /// Paints the word with its baseline centred on [origin].
  void paint(
    Canvas canvas,
    Offset origin,
    double scale,
    List<({double sx, double sy})> letterScales,
  ) {
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(scale);
    for (var i = 0; i < letters.length; i++) {
      final l = letters[i];
      final s = letterScales[i];
      if (s.sy <= 0.001) continue;
      canvas.save();
      canvas.translate(l.cx, 0);
      canvas.scale(s.sx, s.sy);
      l.painter.paint(canvas, Offset(-l.painter.width / 2, -l.baseline));
      canvas.restore();
    }
    canvas.restore();
  }
}

class LogoLetter {
  LogoLetter(this.painter, this.cx, this.baseline);
  final TextPainter painter;

  /// Centre x relative to the word's centre (scale 1).
  final double cx;
  final double baseline;
}

// ---------------------------------------------------------------------- Mochi

class MochiPose {
  const MochiPose({
    required this.x,
    required this.y,
    this.sx = 1,
    this.sy = 1,
    this.scale = 1,
    this.lean = 0,
    this.face = 1,
    this.look = 0,
    this.blink = 1,
    this.smile = 0,
    this.speed = 0,
  });

  /// Bottom-centre of Mochi.
  final double x, y;
  final double sx, sy, scale, lean;

  /// 1 = looking right (hopping), 0 = looking at you.
  final double face;
  final double look, blink, smile, speed;
}

void paintMochi(Canvas canvas, MochiPose m) {
  const rx = 19.0, ry = 17.0;
  canvas.save();
  canvas.translate(m.x, m.y);
  canvas.rotate(m.lean);
  canvas.scale(m.scale * m.sx, m.scale * m.sy);
  const cy = -ry * 0.8, top = cy - ry;

  if (m.speed > 0) {
    for (var k = 0; k < 3; k++) {
      final yy = cy + (k - 1) * 9;
      canvas.drawLine(
        Offset(-rx - 6, yy),
        Offset(-rx - 10 - 70 * m.speed * (1 - k * 0.2), yy + 12 * m.speed),
        Paint()
          ..color = AppColors.lime.withValues(
            alpha: 0.55 * m.speed * (1 - k * 0.25),
          )
          ..strokeWidth = 3 - k * 0.6
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  canvas.drawCircle(
    const Offset(0, cy),
    rx * 1.9,
    Paint()
      ..shader =
          RadialGradient(
            colors: [
              AppColors.lilac.withValues(alpha: 0.35),
              AppColors.lilac.withValues(alpha: 0),
            ],
          ).createShader(
            Rect.fromCircle(center: const Offset(0, cy), radius: rx * 1.9),
          ),
  );

  final body = Path()
    ..moveTo(0, top)
    ..cubicTo(rx * .78, top, rx, cy - ry * .35, rx, cy + ry * .2)
    ..cubicTo(rx, cy + ry * .72, rx * .62, 0, 0, 0)
    ..cubicTo(-rx * .62, 0, -rx, cy + ry * .72, -rx, cy + ry * .2)
    ..cubicTo(-rx, cy - ry * .35, -rx * .78, top, 0, top)
    ..close();
  canvas.drawPath(
    body,
    Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFD6CAFF), Color(0xFF8F78FF)],
      ).createShader(const Rect.fromLTRB(-rx, top, rx, 0)),
  );
  canvas.drawOval(
    Rect.fromCenter(
      center: const Offset(-rx * .35, top + ry * .38),
      width: rx * .54,
      height: ry * .26,
    ),
    Paint()..color = Colors.white.withValues(alpha: 0.38),
  );

  final face = m.face * 4;
  const eyeY = cy + ry * .05, eyeDx = rx * .36;
  final eyeR = 2.4 + m.look * 0.5;
  const ink = Color(0xFF1A1030);
  for (final side in [-1.0, 1.0]) {
    final ex = side * eyeDx + face;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(ex, eyeY),
        width: eyeR * 2,
        height: math.max(1, eyeR * 2.3 * m.blink),
      ),
      Paint()..color = ink,
    );
    if (m.blink > 0.6) {
      canvas.drawCircle(
        Offset(ex - 0.8, eyeY - 1.1),
        0.9,
        Paint()..color = Colors.white,
      );
    }
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(side * eyeDx * 1.55 + face, eyeY + eyeR * 2),
        width: 6,
        height: 3,
      ),
      Paint()..color = AppColors.pink.withValues(alpha: 0.55),
    );
  }
  const mw = rx * .2, my = eyeY + 5.5;
  final sm = 0.6 + m.smile * 0.8;
  canvas.drawPath(
    Path()
      ..moveTo(face - mw, my)
      ..quadraticBezierTo(face, my + mw * sm, face + mw, my),
    Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round,
  );
  canvas.restore();
}

// ---------------------------------------------------------------------- scene

/// Positions of everything at time `t`, for a given screen size and the spot
/// where the logo should end up.
class TakeoffScene {
  TakeoffScene({
    required this.size,
    required this.logoBaseline,
    required this.letters,
  }) : ground = size.height * 0.55;

  final Size size;

  /// Where the logo's baseline centre lands (in this canvas's coordinates).
  final Offset logoBaseline;
  final LogoLetters letters;
  final double ground;

  double get _cx => size.width / 2;
  double _letterX(int i) => _cx + letters.letters[i].cx;

  ({double sx, double sy}) letterScale(int i, double t) {
    var sy = _spring(t - (_land[i] - 0.16));
    var sx = sy > 0 ? 1 + (1 - math.min(sy, 1)) * 0.25 : 1.0;
    final d = 0.16 * _wobble(t - _land[i]);
    sy *= 1 - d;
    sx *= 1 + d * 0.5;
    if (i == 5) {
      // The y: flattened during the beat, springs back on Mochi's hop.
      final flat = t < 2.62
          ? _easeOutCubic(_prog(t, 2.2, 2.3))
          : 1 - _spring(t - 2.62, 20, 0.35);
      final f = _clamp(flat, -0.3, 1);
      sy *= 1 - 0.55 * f;
      sx *= 1 + 0.22 * f;
      final d2 = 0.14 * _wobble(t - 4.02);
      sy *= 1 - d2;
      sx *= 1 + d2 * 0.4;
    }
    return (sx: sx, sy: sy);
  }

  double letterTop(int i, double t) =>
      ground - letters.xHeight * letterScale(i, t).sy;

  /// Word position: glides from the runway to [logoBaseline].
  ({Offset origin, double scale, double g}) word(double t) {
    final g = _easeInOut(_prog(t, 3.12, 3.72));
    return (
      origin: Offset(
        _lerp(_cx, logoBaseline.dx, g),
        _lerp(ground, logoBaseline.dy, g),
      ),
      scale: _lerp(1, logoScale, g),
      g: g,
    );
  }

  Offset _toScreen(double x, double y, double t) {
    final w = word(t);
    return Offset(
      w.origin.dx + (x - _cx) * w.scale,
      w.origin.dy + (y - ground) * w.scale,
    );
  }

  ({double sx, double sy}) _landSquash(double tau) {
    final s = 0.3 * _wobble(tau, 12, 25);
    return (sx: 1 + s * 0.8, sy: 1 - s);
  }

  MochiPose? mochi(double t) {
    if (t < 0.55) return null;
    // Hops: from off-screen left onto each letter in turn.
    for (var k = 0; k < 6; k++) {
      final bx = _letterX(k);
      final start = k == 0 ? 0.55 : _land[k - 1] + 0.06;
      if (t < _land[k]) {
        final ax = k == 0 ? -34.0 : _letterX(k - 1);
        if (t < start) {
          final sq = _landSquash(t - _land[k - 1]);
          return MochiPose(x: ax, y: letterTop(k - 1, t), sx: sq.sx, sy: sq.sy);
        }
        final u = _prog(t, start, _land[k]);
        final y0 = k == 0 ? ground : letterTop(k - 1, t);
        final y1 = letterTop(k, t);
        final h = k == 0 ? 92.0 : 58.0;
        final st = 0.14 * (1 - 2 * u).abs();
        return MochiPose(
          x: _lerp(ax, bx, u),
          y: _lerp(y0, y1, u) - h * 4 * u * (1 - u),
          sx: 1 - st * 0.6,
          sy: 1 + st,
        );
      }
    }
    final lastX = _letterX(5);
    if (t < 2.62) {
      // The beat: sitting on the flattened y, turning to look at you.
      final look = _easeOutCubic(_prog(t, 2.32, 2.45));
      final blink = t > 2.48 && t < 2.56
          ? 1 - math.sin(_prog(t, 2.48, 2.56) * math.pi)
          : 1.0;
      final crouch = _easeInOut(_prog(t, 2.52, 2.62));
      final sq = _landSquash(t - _land[5]);
      return MochiPose(
        x: lastX,
        y: letterTop(5, t),
        sx: sq.sx * (1 + 0.12 * crouch),
        sy: sq.sy * (1 - 0.16 * crouch),
        face: 1 - look,
        look: look,
        blink: blink,
        smile: look,
      );
    }
    if (t < 2.95) {
      // Little hop in place while the y springs back.
      final u = _prog(t, 2.62, 2.92);
      final st = 0.14 * (1 - 2 * u).abs();
      return MochiPose(
        x: lastX,
        y: letterTop(5, t) - 46 * 4 * u * (1 - u),
        sx: 1 - st * 0.6,
        sy: 1 + st,
        face: 0.3,
        smile: 1,
      );
    }
    if (t < 3.45) {
      // Takeoff: lean forward and zoom off to the right.
      final u = _prog(t, 2.95, 3.45);
      final e = _easeInCubic(u);
      return MochiPose(
        x: _lerp(lastX, size.width + 70, e),
        y: letterTop(5, t) - 150 * e - 6 * math.sin(u * math.pi),
        sx: 1 + 0.25 * e,
        sy: 1 - 0.18 * e,
        lean: _easeOutCubic(_prog(t, 2.95, 3.1)) * 0.32,
        smile: 1,
        speed: e,
      );
    }
    if (t < 3.72) return null;
    final perch = _toScreen(lastX, letterTop(5, t), t);
    if (t < 4.02) {
      // Drop onto the logo's y.
      final u = _easeInCubic(_prog(t, 3.72, 4.02));
      return MochiPose(
        x: perch.dx,
        y: _lerp(-40, perch.dy, u),
        sx: 0.9,
        sy: 1.12,
        scale: 0.8,
        face: 0,
      );
    }
    return perchedMochi(perch, t - 4.02);
  }

  /// Mochi sitting on the logo, breathing and blinking. [since] = seconds
  /// since it landed (keeps the idle loop continuous after the intro).
  static MochiPose perchedMochi(Offset perch, double since) {
    final s = 0.3 * _wobble(since, 12, 25);
    final breathe = math.sin(since * 2.4) * 0.025;
    final cycle = since % 3.6;
    final blink = cycle > 3.3
        ? 1 - math.sin(_prog(cycle, 3.3, 3.45) * math.pi)
        : 1.0;
    return MochiPose(
      x: perch.dx,
      y: perch.dy,
      sx: (1 + s * 0.8) * (1 - breathe),
      sy: (1 - s) * (1 + breathe),
      scale: 0.8,
      face: 0,
      smile: 0.6,
      blink: blink,
    );
  }

  /// Runway, lights, puffs, word and Mochi. [backdrop] is the opaque stage
  /// colour, which fades out at the end to reveal the real screen behind.
  void paint(Canvas canvas, double t) {
    final w = word(t);
    _paintBackdrop(canvas, t);
    _paintRunway(canvas, t, w.g);
    letters.paint(canvas, w.origin, w.scale, [
      for (var i = 0; i < 6; i++) letterScale(i, t),
    ]);
    if (t < 3) _paintPuffs(canvas, t);
    final m = mochi(t);
    if (m != null) paintMochi(canvas, m);
  }

  void _paintBackdrop(Canvas canvas, double t) {
    final fade = 1 - _easeInOut(_prog(t, 3.45, 3.95));
    if (fade <= 0) return;
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()..color = AppColors.bg.withValues(alpha: fade),
    );
    final a = _easeOutCubic(_prog(t, 0.2, 1.4)) * fade;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.6, -0.76),
          radius: 0.9,
          colors: [
            AppColors.lilac.withValues(alpha: 0.20 * a),
            AppColors.lilac.withValues(alpha: 0),
          ],
        ).createShader(rect),
    );
  }

  void _paintRunway(Canvas canvas, double t, double g) {
    final draw = _easeOutCubic(_prog(t, 0, 0.5));
    const x0 = 18.0;
    final x1 = size.width - 18;
    final halfLogo = letters.width * logoScale / 2;
    final lx0 = _lerp(x0, logoBaseline.dx - halfLogo + 8, g);
    final lx1 = _lerp(_lerp(x0, x1, draw), logoBaseline.dx + halfLogo - 8, g);
    final ly = _lerp(ground + 4, logoBaseline.dy + 14, g);
    if (draw > 0) {
      final line = Paint()
        ..color = AppColors.lime
        ..strokeWidth = _lerp(2.5, 3.5, g)
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(lx0, ly),
        Offset(lx1, ly),
        Paint()
          ..color = AppColors.lime.withValues(alpha: 0.5)
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawLine(Offset(lx0, ly), Offset(lx1, ly), line);
    }
    final fade = 1 - g;
    if (fade <= 0) return;
    for (var i = 0; i < _lights; i++) {
      final x = _lerp(x0 + 6, x1 - 6, i / (_lights - 1));
      final on = _prog(t, 0.08 + i * 0.045, 0.16 + i * 0.045);
      final chase = t > 2.95 && t < 3.55
          ? math.max(
              0.0,
              1 -
                  (((t - 2.95) * 2.6 % 1) * (_lights + 3) - 1.5 - i).abs() /
                      1.5,
            )
          : 0.0;
      final idle = 0.55 + 0.15 * math.sin(t * 3 + i * 0.6);
      final b = on * math.min(1.0, idle + chase) * fade;
      if (b <= 0) continue;
      final c = Offset(x, ground + 16);
      canvas.drawCircle(
        c,
        4 + chase * 4,
        Paint()..color = AppColors.lime.withValues(alpha: 0.25 * b),
      );
      canvas.drawCircle(
        c,
        1.8 + chase * 1.2,
        Paint()..color = AppColors.lime.withValues(alpha: b),
      );
    }
  }

  void _paintPuffs(Canvas canvas, double t) {
    for (var i = 0; i < 6; i++) {
      final tau = t - _land[i];
      if (tau < 0 || tau > 0.38) continue;
      final a = 1 - tau / 0.38;
      for (final dir in [-1.0, 1.0]) {
        for (var k = 0; k < 2; k++) {
          final x =
              _letterX(i) +
              dir * (10 + 46 * _easeOutCubic(tau / 0.38) * (k == 1 ? 0.6 : 1));
          final y = letterTop(i, t) - 4 - 14 * tau - k * 4;
          canvas.drawCircle(
            Offset(x, y),
            2.6 - k * 0.8,
            Paint()..color = AppColors.lilac.withValues(alpha: 0.55 * a),
          );
        }
      }
    }
  }

  /// Where Mochi perches on the final logo.
  Offset perchAt(double t) => _toScreen(_letterX(5), letterTop(5, t), t);
}

// ---------------------------------------------------------------- the widget

/// Plays the intro full-screen. [logoBaseline] says where the logo should end
/// up; [onTime] reports progress (for the login card rising); [onFinished]
/// fires once at [kTakeoffEnd] (or when skipped).
class MochiTakeoff extends StatefulWidget {
  const MochiTakeoff({
    super.key,
    required this.logoBaseline,
    this.onTime,
    this.onLanded,
    required this.onFinished,
  });

  /// Called with the overlay size once laid out.
  final Offset Function(Size size) logoBaseline;
  final ValueChanged<double>? onTime;

  /// Fires when Mochi has landed on the logo, with its position.
  final ValueChanged<Offset>? onLanded;
  final VoidCallback onFinished;

  @override
  State<MochiTakeoff> createState() => _MochiTakeoffState();
}

class _MochiTakeoffState extends State<MochiTakeoff>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _time = ValueNotifier<double>(0);
  final _letters = LogoLetters.measure();
  Duration? _skipOffset;
  bool _landed = false, _finished = false;
  double _last = 0;
  TakeoffScene? _scene;
  Size? _size;

  // Haptic beats: every other landing light, each landing, the squash.
  static final _taps = <(double, void Function())>[
    for (var i = 0; i < _lights; i += 2)
      (0.08 + i * 0.045, HapticFeedback.selectionClick),
    for (final t in _land) (t, HapticFeedback.lightImpact),
    (2.22, HapticFeedback.mediumImpact),
    (4.02, HapticFeedback.lightImpact),
  ];

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  void _tick(Duration elapsed) {
    final t = (elapsed + (_skipOffset ?? Duration.zero)).inMicroseconds / 1e6;
    for (final (at, tap) in _taps) {
      if (_last < at && t >= at && _skipOffset == null) tap();
    }
    _last = t;
    _time.value = t;
    widget.onTime?.call(math.min(t, kTakeoffEnd));
    final scene = this.scene;
    if (!_landed && t >= kTakeoffLanded && scene != null) {
      _landed = true;
      widget.onLanded?.call(scene.perchAt(t));
    }
    if (!_finished && t >= kTakeoffEnd) {
      _finished = true;
      _ticker.stop();
      widget.onFinished();
    }
  }

  void _skip() {
    if (_time.value >= 3.72) return;
    // Jump to Mochi dropping onto the finished logo, so the ending still
    // plays out smoothly (about half a second) instead of cutting.
    const target = Duration(milliseconds: 3720);
    final now = Duration(microseconds: (_time.value * 1e6).round());
    _skipOffset = (_skipOffset ?? Duration.zero) + (target - now);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Runway intro. Tap to skip.',
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _skip,
        child: LayoutBuilder(
          builder: (context, c) {
            _size = c.biggest;
            return RepaintBoundary(
              child: CustomPaint(
                size: c.biggest,
                painter: _TakeoffPainter(this, _time),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Built on the first tick, once layout is done, so the logo target is
  /// measured from the real screen.
  TakeoffScene? get scene {
    final size = _size;
    if (size == null) return null;
    if (_scene?.size != size) {
      _scene = TakeoffScene(
        size: size,
        logoBaseline: widget.logoBaseline(size),
        letters: _letters,
      );
    }
    return _scene;
  }
}

class _TakeoffPainter extends CustomPainter {
  _TakeoffPainter(this.state, this.time) : super(repaint: time);
  final _MochiTakeoffState state;
  final ValueNotifier<double> time;

  @override
  void paint(Canvas canvas, Size size) =>
      state.scene?.paint(canvas, time.value);

  @override
  bool shouldRepaint(_TakeoffPainter old) => false;
}

/// The finished logo with Mochi perched on the y, breathing. Used on the
/// login screen once the intro is over (and when it's skipped entirely).
/// The logo's baseline sits [baselineFromBottom] above the box bottom.
class LogoMark extends StatefulWidget {
  const LogoMark({super.key});

  static const size = Size(260, 96);
  static const baselineFromBottom = 24.0;

  /// Baseline centre inside the box, matching what the intro lands on.
  static Offset get baseline =>
      Offset(size.width / 2, size.height - baselineFromBottom);

  @override
  State<LogoMark> createState() => _LogoMarkState();
}

class _LogoMarkState extends State<LogoMark>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _since = ValueNotifier<double>(kTakeoffEnd - 4.02);
  final _letters = LogoLetters.measure();

  @override
  void initState() {
    super.initState();
    final start = _since.value;
    _ticker = createTicker((e) => _since.value = start + e.inMicroseconds / 1e6)
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _since.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    _ticker.muted = reduceMotion;
    return Semantics(
      label: 'Runway',
      child: RepaintBoundary(
        child: CustomPaint(
          size: LogoMark.size,
          painter: _LogoMarkPainter(_letters, _since),
        ),
      ),
    );
  }
}

class _LogoMarkPainter extends CustomPainter {
  _LogoMarkPainter(this.letters, this.since) : super(repaint: since);
  final LogoLetters letters;
  final ValueNotifier<double> since;

  @override
  void paint(Canvas canvas, Size size) {
    final base = LogoMark.baseline;
    final scales = [for (var i = 0; i < 6; i++) (sx: 1.0, sy: 1.0)];
    final half = letters.width * logoScale / 2;
    canvas.drawLine(
      Offset(base.dx - half + 8, base.dy + 14),
      Offset(base.dx + half - 8, base.dy + 14),
      Paint()
        ..color = AppColors.lime
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );
    letters.paint(canvas, base, logoScale, scales);
    final y = letters.letters[5];
    final perch = Offset(
      base.dx + y.cx * logoScale,
      base.dy - letters.xHeight * logoScale,
    );
    paintMochi(canvas, TakeoffScene.perchedMochi(perch, since.value));
  }

  @override
  bool shouldRepaint(_LogoMarkPainter old) => false;
}
