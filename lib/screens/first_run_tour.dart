import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_state.dart';
import '../app/budget_math.dart';
import '../app/features.dart';
import '../app/models.dart';
import '../app/theme.dart';
import '../widgets/celebrations.dart';
import '../widgets/gradient_button.dart';
import '../widgets/mochi.dart';
import '../widgets/pressable.dart';

/// What the tour points at, besides the ring ([homeRingKey]).
final tourRunwayKey = GlobalKey(debugLabel: 'tourRunway');
final tourAddKey = GlobalKey(debugLabel: 'tourAdd');
final tourSavingsKey = GlobalKey(debugLabel: 'tourSavings');
final tourCoachKey = GlobalKey(debugLabel: 'tourCoach');
final tourSocialKey = GlobalKey(debugLabel: 'tourSocial');

class _Stop {
  const _Stop(
    this.key, {
    required this.name,
    required this.title,
    required this.body,
    this.round = false,
    this.onHome = false,
  });

  final GlobalKey key;

  /// Finishes "Tap … to continue".
  final String name;
  final String title;
  final String body;

  /// Lit as a circle (the ring, the + button) rather than a rounded box.
  final bool round;

  /// Lives in Home's scroll view, so it's scrolled into view first.
  final bool onHome;
}

List<_Stop> _tourStops() => [
  _Stop(
    homeRingKey,
    name: 'the ring',
    title: 'Your number for today',
    body:
        'Spend under this and your money lasts. It updates every time you '
        'log something.',
    round: true,
    onHome: true,
  ),
  _Stop(
    tourRunwayKey,
    name: 'Runway',
    title: 'Will your money last?',
    body:
        '“Covered” means it lasts to the end. “Days short” means cut back '
        'a little and it catches up.',
    onHome: true,
  ),
  _Stop(
    tourAddKey,
    name: '+',
    title: 'Log spending in two taps',
    body: 'Tap + whenever you buy something. Type it, or just say it.',
    round: true,
  ),
  _Stop(
    tourSavingsKey,
    name: 'Savings',
    title: 'Put money aside',
    body: 'Make a jar for a trip or a concert and watch it fill up.',
  ),
  _Stop(
    tourCoachKey,
    name: 'Coach',
    title: 'Ask about your money',
    body:
        '“Can I afford a \$40 dinner Friday?” Coach answers from your own '
        'budget.',
  ),
  if (Features.socialTab)
    Features.squad
        ? _Stop(
            tourSocialKey,
            name: 'Squad',
            title: 'Budget with friends',
            body: 'Keep a streak going together and split bills.',
          )
        : _Stop(
            tourSocialKey,
            name: 'Friends',
            title: 'Split bills with friends',
            body: 'Add friends with a code, split a bill, and settle up later.',
          ),
];

/// The first-run tour of Home: a handwritten hello from Mochi, then each
/// part of the screen lit up in turn. Tapping the lit part moves on; taps
/// anywhere else do nothing, so nobody skips by accident.
class FirstRunTour extends StatefulWidget {
  const FirstRunTour({
    super.key,
    required this.firstTime,
    required this.onDone,
  });

  /// Never offered before: the welcome offers "Maybe later" (once more on
  /// the next launch) instead of "No thanks".
  final bool firstTime;
  final ValueChanged<TourProgress> onDone;

  @override
  State<FirstRunTour> createState() => _FirstRunTourState();
}

class _FirstRunTourState extends State<FirstRunTour>
    with TickerProviderStateMixin {
  late final _stops = _tourStops();

  /// 0 is the welcome, 1…stops the lit steps, then the goodbye.
  int _page = 0;
  bool _moving = false;

  /// Where the lit hole is, gliding from [_from] to [_to].
  Rect? _from;
  Rect? _to;
  late final _glide = AnimationController(vsync: this, duration: Motion.slow);
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  int get _last => _stops.length + 1;
  _Stop? get _stop =>
      _page >= 1 && _page <= _stops.length ? _stops[_page - 1] : null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _glide.dispose();
    _pulse.dispose();
    super.dispose();
  }

  Rect? _rectOf(GlobalKey key) {
    final target = key.currentContext?.findRenderObject() as RenderBox?;
    final me = context.findRenderObject() as RenderBox?;
    if (target == null || me == null || !target.attached) return null;
    final topLeft = me.globalToLocal(target.localToGlobal(Offset.zero));
    return topLeft & target.size;
  }

  Future<void> _goTo(int page) async {
    if (_moving) return;
    if (page > _last) {
      HapticFeedback.mediumImpact();
      widget.onDone(TourProgress.seen);
      return;
    }
    HapticFeedback.selectionClick();
    final stop = page >= 1 && page <= _stops.length ? _stops[page - 1] : null;
    if (stop == null) {
      setState(() {
        _page = page;
        _from = _to = null;
      });
      return;
    }
    _moving = true;
    final reduced = Motion.reduced(context);
    final target = stop.key.currentContext;
    if (stop.onHome && target != null) {
      await Scrollable.ensureVisible(
        target,
        alignment: 0.3,
        duration: reduced ? Duration.zero : Motion.med,
        curve: Motion.out,
      );
    }
    _moving = false;
    if (!mounted) return;
    final rect = _rectOf(stop.key);
    if (rect == null) {
      // Not on screen (a switched-off tab): skip it.
      return _goTo(page + 1);
    }
    setState(() {
      _page = page;
      _from = _to == null
          ? Rect.fromCenter(center: rect.center, width: 0, height: 0)
          : _current;
      _to = rect.inflate(stop.round ? 8 : 6);
    });
    if (reduced) {
      _glide.value = 1;
    } else {
      _glide.forward(from: 0);
    }
  }

  Rect? get _current {
    if (_to == null) return null;
    return Rect.lerp(_from, _to, Motion.out.transform(_glide.value));
  }

  @override
  Widget build(BuildContext context) {
    final stop = _stop;
    final greeting = _page == 0 || _page == _last;
    return Stack(
      children: [
        // Swallows every tap that isn't on the lit part or a button.
        const Positioned.fill(
          child: ModalBarrier(dismissible: false, color: Colors.transparent),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedOpacity(
              duration: Motion.med,
              opacity: greeting ? 1 : 0,
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 7, sigmaY: 7),
                child: ColoredBox(color: AppColors.bg.withValues(alpha: 0.55)),
              ),
            ),
          ),
        ),
        if (stop != null)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: Listenable.merge([_glide, _pulse]),
                builder: (context, _) => CustomPaint(
                  painter: _HolePainter(
                    hole: _current!,
                    round: stop.round,
                    pulse: Motion.reduced(context) ? null : _pulse.value,
                  ),
                ),
              ),
            ),
          ),
        if (stop != null && _to != null) ...[
          Positioned.fromRect(
            rect: _to!,
            child: Semantics(
              button: true,
              label: 'Tap ${stop.name} to continue',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _goTo(_page + 1),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomSingleChildLayout(
                delegate: _TipLayout(
                  target: _to!,
                  padding: MediaQuery.paddingOf(context),
                ),
                child: AnimatedSwitcher(
                  duration: Motion.fast,
                  child: _Tip(key: ValueKey(_page), stop: stop),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 6, 8, 0),
              child: Row(
                children: [
                  Text(
                    '$_page of ${_stops.length}',
                    style: AppText.label.copyWith(
                      fontFeatures: const [ui.FontFeature.tabularFigures()],
                    ),
                  ),
                  const Spacer(),
                  Pressable(
                    onTap: () => widget.onDone(TourProgress.seen),
                    semanticLabel: 'Skip tour',
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text('Skip tour', style: AppText.label),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (greeting)
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: Motion.med,
              child: _page == 0
                  ? _Greeting(
                      key: const ValueKey('hello'),
                      big: _hello(),
                      sub: '30 seconds, promise.',
                      go: 'Show me',
                      onGo: () => _goTo(1),
                      other: widget.firstTime ? 'Maybe later' : 'No thanks',
                      onOther: () => widget.onDone(
                        widget.firstTime
                            ? TourProgress.later
                            : TourProgress.seen,
                      ),
                    )
                  : _Greeting(
                      key: const ValueKey('bye'),
                      big: 'that’s it!',
                      sub:
                          'Log your first expense next time you buy '
                          'something. You can replay this from Settings.',
                      go: 'Start using Runway',
                      onGo: () => _goTo(_last + 1),
                    ),
            ),
          ),
      ],
    );
  }

  String _hello() {
    final name = AppScope.read(context).user?.name.trim().split(' ').first;
    final hey = name == null || name.isEmpty ? 'hey there!' : 'hey $name!';
    return '$hey\nwant a quick tour?';
  }
}

/// Darkens everything except [hole], with a lime outline that ripples out.
class _HolePainter extends CustomPainter {
  _HolePainter({required this.hole, required this.round, this.pulse});

  final Rect hole;
  final bool round;

  /// 0…1 through a ripple, or null to hold still (reduced motion).
  final double? pulse;

  RRect _shape(Rect r) => round
      ? RRect.fromRectAndRadius(r, Radius.circular(r.shortestSide / 2))
      : RRect.fromRectAndRadius(r, const Radius.circular(22));

  @override
  void paint(Canvas canvas, Size size) {
    final dim = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(_shape(hole));
    canvas.drawPath(dim, Paint()..color = const Color(0xC7060609));
    final t = pulse;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    if (t == null) {
      canvas.drawRRect(_shape(hole.inflate(3)), stroke..color = AppColors.lime);
      return;
    }
    canvas.drawRRect(
      _shape(hole.inflate(3 + 11 * t)),
      stroke..color = AppColors.lime.withValues(alpha: 1 - t),
    );
  }

  @override
  bool shouldRepaint(_HolePainter old) =>
      old.hole != hole || old.pulse != pulse || old.round != round;
}

/// Puts the tip just below the lit part, or above it when there's no room.
class _TipLayout extends SingleChildLayoutDelegate {
  _TipLayout({required this.target, required this.padding});

  final Rect target;
  final EdgeInsets padding;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(
        maxWidth: (constraints.maxWidth - 32).clamp(0, 420),
        maxHeight: constraints.maxHeight,
      );

  @override
  Offset getPositionForChild(Size size, Size child) {
    final x = (size.width - child.width) / 2;
    final below = target.bottom + 22;
    if (below + child.height <= size.height - padding.bottom - 16) {
      return Offset(x, below);
    }
    final above = target.top - 22 - child.height;
    return Offset(x, above.clamp(padding.top + 44, size.height));
  }

  @override
  bool shouldRelayout(_TipLayout old) =>
      old.target != target || old.padding != padding;
}

class _Tip extends StatelessWidget {
  const _Tip({super.key, required this.stop});
  final _Stop stop;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.bg.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            stop.title,
            style: AppText.heading.copyWith(fontSize: 19),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            stop.body,
            style: AppText.body.copyWith(
              color: AppColors.text.withValues(alpha: 0.8),
              height: 1.4,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.lime,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.touch_app_rounded,
                  size: 15,
                  color: AppColors.onLime,
                ),
                const SizedBox(width: 6),
                Text(
                  'Tap ${stop.name} to continue',
                  style: AppText.label.copyWith(
                    color: AppColors.onLime,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The handwritten hello and goodbye, over a blurred Home.
class _Greeting extends StatelessWidget {
  const _Greeting({
    super.key,
    required this.big,
    required this.sub,
    required this.go,
    required this.onGo,
    this.other,
    this.onOther,
  });

  final String big;
  final String sub;
  final String go;
  final VoidCallback onGo;
  final String? other;
  final VoidCallback? onOther;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Mochi(mood: PetMood.thriving, size: 84),
                const SizedBox(height: 10),
                Text(
                  big,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Caveat',
                    fontVariations: [FontVariation.weight(700)],
                    fontWeight: FontWeight.w700,
                    fontSize: 46,
                    height: 0.95,
                    color: AppColors.lime,
                  ),
                ),
                const SizedBox(height: 6),
                const _Scribble(),
                const SizedBox(height: 12),
                Text(
                  sub,
                  textAlign: TextAlign.center,
                  style: AppText.body.copyWith(
                    color: AppColors.text.withValues(alpha: 0.8),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                GradientButton(label: go, onTap: onGo, height: 52),
                if (other case final other?)
                  Pressable(
                    onTap: onOther,
                    semanticLabel: other,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(other, style: AppText.label),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A hand-drawn underline that draws itself in.
class _Scribble extends StatelessWidget {
  const _Scribble();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: Motion.reduced(context) ? 1 : 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Motion.out,
      builder: (context, t, _) =>
          CustomPaint(size: const Size(160, 14), painter: _ScribblePainter(t)),
    );
  }
}

class _ScribblePainter extends CustomPainter {
  _ScribblePainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(4, h * 0.65)
      ..cubicTo(w * 0.2, h * 0.2, w * 0.37, h * 0.85, w * 0.53, h * 0.5)
      ..cubicTo(w * 0.7, h * 0.15, w * 0.85, h * 0.3, w - 4, h * 0.55);
    final drawn = Path();
    for (final metric in path.computeMetrics()) {
      drawn.addPath(metric.extractPath(0, metric.length * t), Offset.zero);
    }
    canvas.drawPath(
      drawn,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..color = AppColors.lime,
    );
  }

  @override
  bool shouldRepaint(_ScribblePainter old) => old.t != t;
}
