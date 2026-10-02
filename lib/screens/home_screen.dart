import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../app/budget_math.dart';
import '../app/format.dart';
import '../app/models.dart';
import '../app/theme.dart';
import '../widgets/glass.dart';
import '../widgets/motion.dart';
import 'shell.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final s = state.snapshot;
    final sections = <Widget>[
      _Header(streak: state.streak, termName: state.term.name, s: s),
      _HeroRing(s: s),
      _RunwayCard(s: s, costs: state.comingUp),
      _ComingUp(costs: state.comingUp, today: s.today),
      _WeekSplit(split: state.thisWeek),
      _Recent(expenses: state.recentExpenses(), today: s.today),
    ];
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 8, 20, navClearance(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < sections.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Entrance(index: i, child: sections[i]),
              ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.streak,
    required this.termName,
    required this.s,
  });
  final int streak;
  final String termName;
  final RunwaySnapshot s;

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 5) return 'Up late';
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final week = (s.daysElapsed - 1) ~/ 7 + 1;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_greeting, style: AppText.title),
                const SizedBox(height: 2),
                Text('$termName · Week $week', style: AppText.label),
              ],
            ),
          ),
          _StreakChip(streak: streak),
        ],
      ),
    );
  }
}

class _StreakChip extends StatelessWidget {
  const _StreakChip({required this.streak});
  final int streak;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$streak day streak',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          gradient: LinearGradient(
            colors: [
              AppColors.amber.withValues(alpha: 0.22),
              AppColors.pink.withValues(alpha: 0.18),
            ],
          ),
          border: Border.all(color: AppColors.amber.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
              color: AppColors.amber.withValues(alpha: 0.25),
              blurRadius: 18,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔥', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 4),
            AnimatedSwitcher(
              duration: Motion.med,
              transitionBuilder: (child, a) => ScaleTransition(
                scale: CurvedAnimation(parent: a, curve: Motion.spring),
                child: FadeTransition(opacity: a, child: child),
              ),
              child: Text(
                '$streak',
                key: ValueKey(streak),
                style: AppText.heading.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroRing extends StatelessWidget {
  const _HeroRing({required this.s});
  final RunwaySnapshot s;

  @override
  Widget build(BuildContext context) {
    final over = s.safeToSpendToday < 0;
    return Center(
      child: SizedBox.square(
        dimension: 272,
        child: Stack(
          alignment: Alignment.center,
          children: [
            RepaintBoundary(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: s.usedToday),
                duration: Motion.slow,
                curve: Motion.roll,
                builder: (context, v, _) => CustomPaint(
                  size: const Size.square(272),
                  painter: _RingPainter(used: v, over: over),
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Safe to spend today', style: AppText.label),
                const SizedBox(height: 8),
                FittedBox(
                  child: over
                      ? RollingNumber(
                          value: s.safeToSpendToday,
                          style: AppText.display.copyWith(
                            color: AppColors.coral,
                          ),
                        )
                      : ShaderMask(
                          blendMode: BlendMode.srcIn,
                          shaderCallback: const LinearGradient(
                            colors: [Colors.white, Color(0xFFD9D2FF)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ).createShader,
                          child: RollingNumber(
                            value: s.safeToSpendToday,
                            style: AppText.display,
                          ),
                        ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${money(s.spentToday)} of ${money(s.dailyAllowance)} used',
                  style: AppText.caption.copyWith(fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.used, required this.over});
  final double used;
  final bool over;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 16.0;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2 + 10);
    canvas.drawArc(
      arcRect,
      0,
      2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = Colors.white.withValues(alpha: 0.07),
    );
    final sweep = 2 * math.pi * used.clamp(0.0, 1.0);
    if (sweep <= 0.001) return;
    final colors = over
        ? const [AppColors.pink, AppColors.coral, AppColors.pink]
        : const [AppColors.cyan, AppColors.violet, AppColors.cyan];
    final shader = SweepGradient(
      colors: colors,
      transform: const GradientRotation(-math.pi / 2),
    ).createShader(arcRect);
    // Glow pass, then the crisp arc.
    canvas.drawArc(
      arcRect,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = shader
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawArc(
      arcRect,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = shader,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.used != used || old.over != over;
}

class _RunwayCard extends StatelessWidget {
  const _RunwayCard({required this.s, required this.costs});
  final RunwaySnapshot s;
  final List<UpcomingCost> costs;

  @override
  Widget build(BuildContext context) {
    final date = s.runwayDate;
    final lasts = date == null || s.covered
        ? 'Money lasts the whole term'
        : 'Money lasts until ${shortDate(date)}';
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Runway', style: AppText.heading),
              const Spacer(),
              AnimatedSwitcher(
                duration: Motion.med,
                child: s.covered
                    ? const Pill(
                        key: ValueKey('ok'),
                        label: 'Covered ✓',
                        color: AppColors.mint,
                      )
                    : Pill(
                        key: ValueKey(s.daysShort),
                        label: '${plural(s.daysShort, 'day')} short',
                        color: AppColors.coral,
                      ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: lasts, style: AppText.body),
                TextSpan(
                  text: ' · Term ends ${shortDate(s.termEnd)}',
                  style: AppText.body.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Timeline(s: s, costs: costs),
          const SizedBox(height: 12),
          Row(
            children: [
              _Stat(
                label: 'Available',
                value: money(s.available, cents: false),
              ),
              _Stat(label: 'Reserved', value: money(s.reserved, cents: false)),
              _Stat(label: 'Burn / day', value: money(s.burnRate)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: AppText.caption),
          const SizedBox(height: 2),
          Text(value, style: AppText.number.copyWith(fontSize: 17)),
        ],
      ),
    );
  }
}

/// Horizontal term bar: start → end, with today, "money runs out", and pins
/// for upcoming costs.
class _Timeline extends StatelessWidget {
  const _Timeline({required this.s, required this.costs});
  final RunwaySnapshot s;
  final List<UpcomingCost> costs;

  static const _barY = 40.0;

  @override
  Widget build(BuildContext context) {
    final todayX = s.termProgress(s.today);
    final runout = s.runwayDate;
    final runoutX = runout == null || s.covered ? null : s.termProgress(runout);
    return SizedBox(
      height: 96,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          Widget at(double frac, double top, double width, Widget child) =>
              Positioned(
                left: (frac * w - width / 2).clamp(0.0, w - width),
                top: top,
                width: width,
                child: Center(child: child),
              );
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: Motion.slow * 1.5,
                    curve: Motion.out,
                    builder: (context, t, _) => CustomPaint(
                      painter: _TimelinePainter(
                        reveal: t,
                        barY: _barY,
                        todayX: todayX,
                        runoutX: runoutX,
                        costXs: [
                          for (final k in costs) s.termProgress(k.dueDate),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              for (final k in costs)
                at(
                  s.termProgress(k.dueDate),
                  4,
                  28,
                  Tooltip(
                    message: '${k.name} · ${money(k.amount, cents: false)}',
                    child: Text(k.emoji, style: const TextStyle(fontSize: 17)),
                  ),
                ),
              at(
                todayX,
                _barY + 14,
                60,
                Text(
                  'Today',
                  style: AppText.caption.copyWith(color: AppColors.text),
                ),
              ),
              if (runoutX != null)
                at(
                  runoutX,
                  _barY + 14,
                  84,
                  Text(
                    'Runs out',
                    style: AppText.caption.copyWith(color: AppColors.coral),
                  ),
                ),
              Positioned(
                left: 0,
                bottom: 0,
                child: Text(shortDate(s.termStart), style: AppText.caption),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Text(shortDate(s.termEnd), style: AppText.caption),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TimelinePainter extends CustomPainter {
  _TimelinePainter({
    required this.reveal,
    required this.barY,
    required this.todayX,
    required this.runoutX,
    required this.costXs,
  });

  final double reveal;
  final double barY;
  final double todayX;
  final double? runoutX;
  final List<double> costXs;

  @override
  void paint(Canvas canvas, Size size) {
    const h = 8.0;
    final w = size.width;
    final track = RRect.fromLTRBR(
      0,
      barY - h / 2,
      w,
      barY + h / 2,
      const Radius.circular(h),
    );
    canvas.drawRRect(
      track,
      Paint()..color = Colors.white.withValues(alpha: 0.08),
    );

    // Short zone: from money-runs-out to term end.
    if (runoutX != null) {
      final x = runoutX! * w;
      canvas.drawRRect(
        RRect.fromLTRBR(
          x,
          barY - h / 2,
          w,
          barY + h / 2,
          const Radius.circular(h),
        ),
        Paint()
          ..shader = LinearGradient(
            colors: [
              AppColors.coral.withValues(alpha: 0.55 * reveal),
              AppColors.coral.withValues(alpha: 0.15 * reveal),
            ],
          ).createShader(Rect.fromLTRB(x, 0, w, size.height)),
      );
    }

    // Elapsed fill.
    final fillW = todayX * w * reveal;
    if (fillW > 0) {
      final fill = RRect.fromLTRBR(
        0,
        barY - h / 2,
        math.max(h, fillW),
        barY + h / 2,
        const Radius.circular(h),
      );
      final shader = AppGradients.brand.createShader(
        Rect.fromLTWH(0, 0, todayX * w, size.height),
      );
      canvas.drawRRect(
        fill,
        Paint()
          ..shader = shader
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawRRect(fill, Paint()..shader = shader);
    }

    // Cost pin stems.
    final stem = Paint()
      ..color = Colors.white.withValues(alpha: 0.25 * reveal)
      ..strokeWidth = 1.2;
    for (final cx in costXs) {
      final x = cx * w;
      canvas.drawLine(Offset(x, 26), Offset(x, barY - h / 2 - 1), stem);
      canvas.drawCircle(
        Offset(x, barY),
        2.5,
        Paint()..color = AppColors.amber.withValues(alpha: reveal),
      );
    }

    // Runs-out marker.
    if (runoutX != null) {
      final c = Offset(runoutX! * w, barY);
      canvas.drawCircle(
        c,
        10,
        Paint()..color = AppColors.coral.withValues(alpha: 0.3 * reveal),
      );
      canvas.drawCircle(
        c,
        5.5,
        Paint()..color = AppColors.coral.withValues(alpha: reveal),
      );
    }

    // Today marker.
    final t = Offset(fillW.clamp(0, w), barY);
    canvas.drawCircle(
      t,
      12,
      Paint()..color = AppColors.cyan.withValues(alpha: 0.25),
    );
    canvas.drawCircle(t, 7, Paint()..color = Colors.white);
    canvas.drawCircle(t, 3.5, Paint()..color = AppColors.violet);
  }

  @override
  bool shouldRepaint(_TimelinePainter old) =>
      old.reveal != reveal ||
      old.todayX != todayX ||
      old.runoutX != runoutX ||
      old.costXs.length != costXs.length;
}

class _ComingUp extends StatelessWidget {
  const _ComingUp({required this.costs, required this.today});
  final List<UpcomingCost> costs;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          'Coming up',
          trailing: Text(
            '${money(costs.fold(0, (s, c) => s + c.amount), cents: false)} reserved',
            style: AppText.label,
          ),
        ),
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(
            children: [
              for (var i = 0; i < costs.length; i++) ...[
                if (i > 0) Divider(height: 1, color: AppColors.hairline),
                _Row(
                  emoji: costs[i].emoji,
                  title: costs[i].name,
                  subtitle:
                      '${shortDate(costs[i].dueDate)} · in ${plural(daysBetween(today, costs[i].dueDate), 'day')}',
                  amount: money(costs[i].amount, cents: false),
                  accent: AppColors.amber,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.amount,
    this.accent,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final String amount;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppText.body.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppText.caption.copyWith(
                    fontSize: 12,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          if (accent != null)
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: accent!, blurRadius: 6)],
              ),
            ),
          Text(amount, style: AppText.number.copyWith(fontSize: 16)),
        ],
      ),
    );
  }
}

class _WeekSplit extends StatelessWidget {
  const _WeekSplit({required this.split});
  final NeedWantSplit split;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          'This week',
          trailing: Text('${money(split.total)} spent', style: AppText.label),
        ),
        GlassCard(
          child: Column(
            children: [
              SizedBox(
                height: 14,
                child: LayoutBuilder(
                  builder: (context, c) => TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.5, end: split.needShare),
                    duration: Motion.slow,
                    curve: Motion.out,
                    builder: (context, share, _) {
                      const gap = 4.0;
                      final needW = (c.maxWidth - gap) * share;
                      return Row(
                        children: [
                          _Bar(width: needW, color: AppColors.need),
                          const SizedBox(width: gap),
                          Expanded(child: _Bar(color: AppColors.want)),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Flexible(
                    child: _Legend(
                      color: AppColors.need,
                      label: 'Need',
                      value: split.need,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _Legend(
                        color: AppColors.want,
                        label: 'Want',
                        value: split.want,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.color, this.width});
  final Color color;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.65)],
        ),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 12),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.color,
    required this.label,
    required this.value,
  });
  final Color color;
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: AppText.label),
          const SizedBox(width: 6),
          RollingNumber(
            value: value,
            style: AppText.number.copyWith(fontSize: 15),
          ),
        ],
      ),
    );
  }
}

class _Recent extends StatelessWidget {
  const _Recent({required this.expenses, required this.today});
  final List<Expense> expenses;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Recent'),
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: AnimatedSize(
            duration: Motion.med,
            curve: Motion.out,
            alignment: Alignment.topCenter,
            child: Column(
              children: [
                for (var i = 0; i < expenses.length; i++)
                  // Keyed so a newly logged expense gets its own entrance.
                  Entrance(
                    key: ValueKey(expenses[i].id),
                    index: 0,
                    child: Column(
                      children: [
                        if (i > 0)
                          Divider(height: 1, color: AppColors.hairline),
                        _Row(
                          emoji: expenses[i].category.emoji,
                          title: expenses[i].title,
                          subtitle:
                              '${relativeDay(expenses[i].date, today)} · ${expenses[i].isNeed ? 'Need' : 'Want'}',
                          amount: money(expenses[i].amount),
                          accent: expenses[i].isNeed
                              ? AppColors.need
                              : AppColors.want,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
