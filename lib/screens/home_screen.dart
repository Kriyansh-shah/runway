import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../app/auth.dart';
import '../app/budget_math.dart';
import '../app/format.dart';
import '../app/models.dart';
import '../app/theme.dart';
import '../widgets/category_icon.dart';
import '../widgets/expense_inputs.dart';
import '../widgets/celebrations.dart';
import '../widgets/glass.dart';
import '../widgets/list_row.dart';
import '../widgets/motion.dart';
import '../widgets/ph_icons.dart';
import '../widgets/pressable.dart';
import '../widgets/transitions.dart';
import 'add_income_sheet.dart';
import 'all_expenses_screen.dart';
import 'jar_sheets.dart';
import 'money_actions.dart';
import 'savings_goal_sheet.dart';
import 'settings_screen.dart';
import 'shell.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final s = state.snapshot;
    final sections = <Widget>[
      // The big greeting fades and shrinks away as you scroll; the compact
      // bar takes over.
      _ScrollFade(
        scroll: _scroll,
        child: _Header(
          streak: state.streak,
          termName: state.term.name,
          s: s,
          user: state.user,
        ),
      ),
      _HeroRing(s: s),
      if (state.offerSavingsGoal) const _SavingsPrompt(),
      _RunwayCard(s: s, costs: state.comingUp),
      _ComingUp(costs: state.comingUp, today: s.today),
      _MoneyIn(
        incomes: state.incomes,
        received: s.received,
        next: state.nextIncome,
        today: s.today,
      ),
      _WeekSplit(split: state.thisWeek),
      _Recent(
        expenses: state.recentExpenses(),
        deposits: state.recentJarDeposits(),
        today: s.today,
      ),
    ];
    return Stack(
      children: [
        SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            controller: _scroll,
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
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _CompactBar(scroll: _scroll, user: state.user, s: s),
        ),
      ],
    );
  }
}

double _offsetOf(ScrollController c) => c.hasClients ? c.offset : 0;

class _ScrollFade extends StatelessWidget {
  const _ScrollFade({required this.scroll, required this.child});
  final ScrollController scroll;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: scroll,
      child: child,
      builder: (context, child) {
        final p = (_offsetOf(scroll) / 70).clamp(0.0, 1.0);
        return Opacity(
          opacity: 1 - p,
          child: Transform.scale(
            scale: 1 - 0.06 * p,
            alignment: Alignment.centerLeft,
            child: child,
          ),
        );
      },
    );
  }
}

/// Frosted mini header that slides in once the big greeting scrolls away.
class _CompactBar extends StatelessWidget {
  const _CompactBar({
    required this.scroll,
    required this.user,
    required this.s,
  });
  final ScrollController scroll;
  final UserProfile? user;
  final RunwaySnapshot s;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return AnimatedBuilder(
      animation: scroll,
      builder: (context, child) {
        final p = Curves.easeOutCubic.transform(
          ((_offsetOf(scroll) - 40) / 50).clamp(0.0, 1.0),
        );
        if (p == 0) return const SizedBox.shrink();
        return IgnorePointer(
          ignoring: p < 1,
          child: Opacity(
            opacity: p,
            child: Transform.translate(
              offset: Offset(0, -14 * (1 - p)),
              child: child,
            ),
          ),
        );
      },
      child: FrostedGlass(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        border: Border(bottom: BorderSide(color: AppColors.hairline)),
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, top + 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  user == null ? 'Runway' : 'Hey, ${user!.name}',
                  style: AppText.heading.copyWith(fontSize: 18),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Pill(
                label: 'Safe today ${money(s.safeToSpendToday)}',
                color: s.safeToSpendToday >= 0 ? AppColors.lime : AppColors.red,
              ),
            ],
          ),
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
    required this.user,
  });
  final int streak;
  final String termName;
  final RunwaySnapshot s;
  final UserProfile? user;

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
          if (user != null) ...[
            _Avatar(user: user!),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user == null ? _greeting : 'Hey, ${user!.name}',
                  style: AppText.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (user != null) _greeting,
                    termName,
                    'Week $week',
                  ].join(' · '),
                  style: AppText.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _StreakChip(streak: streak),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.user});
  final UserProfile user;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () => Navigator.of(context)
          .push(FadeScaleRoute<void>(builder: (_) => const SettingsScreen())),
      semanticLabel: 'Settings',
      child: Container(
        width: 46,
        height: 46,
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppGradients.brand,
        ),
        child: Container(
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surface,
          ),
          child: Text(user.initial, style: AppText.heading),
        ),
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
              AppColors.butter.withValues(alpha: 0.22),
              AppColors.pink.withValues(alpha: 0.18),
            ],
          ),
          border: Border.all(color: AppColors.butter.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
              color: AppColors.butter.withValues(alpha: 0.25),
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
      child: RingPulse(
        key: homeRingKey,
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
                              color: AppColors.red,
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
                    '${money(s.usedTodayAmount)} of ${money(s.dailyAllowance)} used',
                    style: AppText.caption.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
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
        ? const [AppColors.red, AppColors.pink, AppColors.red]
        : const [AppColors.lime, Color(0xFFDFFF8A), AppColors.lime];
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
    final period = AppScope.of(context).term.period;
    final lasts = date == null || s.covered
        ? 'Money lasts the whole ${period.noun}'
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
                        color: AppColors.lime,
                      )
                    : Pill(
                        key: ValueKey(s.daysShort),
                        label: '${plural(s.daysShort, 'day')} short',
                        color: AppColors.red,
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
                  text:
                      ' · ${period == BudgetPeriod.monthly ? 'Month' : 'Term'}'
                      ' ends ${shortDate(s.termEnd)}',
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
          if (s.savingsGoal > 0) ...[
            const SizedBox(height: 12),
            _SavingsLine(s: s),
          ],
        ],
      ),
    );
  }
}

/// "🐷 $100 set aside for savings", or how much of it has been spent.
class _SavingsLine extends StatelessWidget {
  const _SavingsLine({required this.s});
  final RunwaySnapshot s;

  @override
  Widget build(BuildContext context) {
    final dipped = s.dippedIntoSavings > 0.005;
    final goal = money(s.savingsGoal, cents: false);
    return Row(
      children: [
        Icon(
          PhIcons.piggyBank,
          size: 18,
          color: dipped ? AppColors.butter : AppColors.lime,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            dipped
                ? 'You\'re dipping into your savings: '
                      '${money(s.dippedIntoSavings)} of your $goal is gone'
                : '$goal set aside for savings, not in your daily budget',
            style: AppText.label.copyWith(
              color: dipped ? AppColors.butter : AppColors.muted,
            ),
          ),
        ),
      ],
    );
  }
}

/// Asked once of people who set up before savings existed.
class _SavingsPrompt extends StatelessWidget {
  const _SavingsPrompt();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return GlassCard(
      borderColor: AppColors.lime.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(PhIcons.piggyBank, size: 22, color: AppColors.lime),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Save something this ${state.term.period.noun}?',
                  style: AppText.heading,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Pick an amount and Runway sets it aside, so your daily budget '
            'already leaves it alone.',
            style: AppText.label,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ChoiceChipPill(
                selected: true,
                color: AppColors.lime,
                onTap: () => showSavingsGoalSheet(context),
                child: const Text('Set a goal'),
              ),
              const SizedBox(width: 8),
              ChoiceChipPill(
                selected: false,
                onTap: state.skipSavingsGoal,
                child: const Text('Not now'),
              ),
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
                    style: AppText.caption.copyWith(color: AppColors.red),
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
              AppColors.red.withValues(alpha: 0.55 * reveal),
              AppColors.red.withValues(alpha: 0.15 * reveal),
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
        Paint()..color = AppColors.butter.withValues(alpha: reveal),
      );
    }

    // Runs-out marker.
    if (runoutX != null) {
      final c = Offset(runoutX! * w, barY);
      canvas.drawCircle(
        c,
        10,
        Paint()..color = AppColors.red.withValues(alpha: 0.3 * reveal),
      );
      canvas.drawCircle(
        c,
        5.5,
        Paint()..color = AppColors.red.withValues(alpha: reveal),
      );
    }

    // Today marker.
    final t = Offset(fillW.clamp(0, w), barY);
    canvas.drawCircle(
      t,
      12,
      Paint()..color = AppColors.lime.withValues(alpha: 0.25),
    );
    canvas.drawCircle(t, 7, Paint()..color = Colors.white);
    canvas.drawCircle(t, 3.5, Paint()..color = AppColors.lilac);
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

  String _when(UpcomingCost c) {
    final days = daysBetween(today, c.dueDate);
    final due = '${shortDate(c.dueDate)}${c.repeats ? ' · monthly' : ''}';
    if (days < 0) return '$due · overdue';
    if (days == 0) return '$due · today';
    return '$due · in ${plural(days, 'day')}';
  }

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
              if (costs.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    'No big costs ahead. Add one in Settings.',
                    style: AppText.label,
                    textAlign: TextAlign.center,
                  ),
                ),
              for (var i = 0; i < costs.length; i++) ...[
                if (i > 0) Divider(height: 1, color: AppColors.hairline),
                ListRow(
                  leading: Text(
                    costs[i].emoji,
                    style: const TextStyle(fontSize: 20),
                  ),
                  title: costs[i].name,
                  subtitle: _when(costs[i]),
                  amount: money(costs[i].amount, cents: false),
                  accent: costs[i].dueDate.isBefore(today)
                      ? AppColors.red
                      : AppColors.butter,
                  onTap: () => showCostActions(context, costs[i]),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Paychecks and one-off payments. Each counts on the day it arrives.
class _MoneyIn extends StatelessWidget {
  const _MoneyIn({
    required this.incomes,
    required this.received,
    required this.next,
    required this.today,
  });

  final List<Income> incomes;
  final double received;
  final ({Income income, DateTime date})? next;
  final DateTime today;

  String _subtitle(Income i) {
    final endsOn = i.endsOn;
    if (!i.repeats) {
      final arrived = !i.firstDate.isAfter(today);
      return '${arrived ? 'Arrived' : 'Arrives'} ${shortDate(i.firstDate)}';
    }
    if (endsOn != null) {
      return '${i.frequency.label} · stopped ${shortDate(endsOn)}';
    }
    return '${i.frequency.label} · from ${shortDate(i.firstDate)}';
  }

  @override
  Widget build(BuildContext context) {
    final upcoming = next;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          'Money in',
          trailing: Text('${money(received)} received', style: AppText.label),
        ),
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(
            children: [
              if (incomes.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 14, bottom: 4),
                  child: Text(
                    'Paycheck, allowance or scholarship? It counts the day '
                    'it arrives, never before.',
                    style: AppText.label,
                    textAlign: TextAlign.center,
                  ),
                ),
              if (upcoming != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 4),
                  child: Text(
                    'Next: ${upcoming.income.name} +${money(upcoming.income.amount)} '
                    'on ${shortDate(upcoming.date)}',
                    style: AppText.label.copyWith(color: AppColors.lime),
                  ),
                ),
              for (var i = 0; i < incomes.length; i++) ...[
                if (i > 0) Divider(height: 1, color: AppColors.hairline),
                ListRow(
                  leading: Icon(
                    incomes[i].repeats ? PhIcons.repeat : PhIcons.handCoins,
                    size: 20,
                    color: AppColors.lime,
                  ),
                  title: incomes[i].name,
                  subtitle: _subtitle(incomes[i]),
                  amount: '+${money(incomes[i].amount)}',
                  onTap: () => showIncomeActions(context, incomes[i]),
                ),
              ],
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Pressable(
                    onTap: () => showAddIncomeSheet(context),
                    semanticLabel: 'Add money coming in',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          PhIcons.plusBold,
                          size: 16,
                          color: AppColors.lime,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Add money',
                          style: AppText.body.copyWith(
                            color: AppColors.lime,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
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
  const _Recent({
    required this.expenses,
    required this.deposits,
    required this.today,
  });
  final List<Expense> expenses;

  /// Money put into savings jars, shown among the expenses by date.
  final List<({JarDeposit deposit, SavingsJar jar})> deposits;
  final DateTime today;

  Widget _depositRow(
    BuildContext context,
    ({JarDeposit deposit, SavingsJar jar}) d,
  ) => ListRow(
    leading: const Icon(PhIcons.piggyBank, size: 20, color: AppColors.lime),
    title: d.deposit.amount > 0
        ? 'Put aside · ${d.jar.name}'
        : 'Took out · ${d.jar.name}',
    subtitle: '${relativeDay(d.deposit.date, today)} · Saving for',
    amount: d.deposit.amount > 0
        ? money(d.deposit.amount)
        : '+${money(-d.deposit.amount)}',
    accent: AppColors.lime,
    onTap: () => showJarSheet(context, d.jar.id),
  );

  @override
  Widget build(BuildContext context) {
    // Expenses and jar deposits together, newest first, six at most.
    final items = <({DateTime date, Object item})>[
      for (final e in expenses) (date: e.date, item: e),
      for (final d in deposits) (date: d.deposit.date, item: d),
    ]..sort((a, b) => b.date.compareTo(a.date));
    final shown = items.take(6).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          'Recent',
          trailing: Pressable(
            onTap: () => Navigator.of(context).push(
              FadeScaleRoute<void>(builder: (_) => const AllExpensesScreen()),
            ),
            semanticLabel: 'See all expenses',
            child: Text(
              'See all',
              style: AppText.label.copyWith(
                color: AppColors.lime,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: AnimatedSize(
            duration: Motion.med,
            curve: Motion.out,
            alignment: Alignment.topCenter,
            child: Column(
              children: [
                if (shown.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(
                      'Nothing logged yet. Tap + to add your first expense.',
                      style: AppText.label,
                      textAlign: TextAlign.center,
                    ),
                  ),
                for (final (i, entry) in shown.indexed)
                  // Keyed so a newly logged expense gets its own entrance.
                  Entrance(
                    key: ValueKey(switch (entry.item) {
                      final Expense e => e.id,
                      final ({JarDeposit deposit, SavingsJar jar}) d =>
                        d.deposit.id,
                      _ => i,
                    }),
                    index: 0,
                    child: Column(
                      children: [
                        if (i > 0)
                          Divider(height: 1, color: AppColors.hairline),
                        switch (entry.item) {
                          final Expense e => ListRow(
                            leading: CategoryIcon.of(e),
                            title: e.title,
                            subtitle:
                                '${relativeDay(e.date, today)} · ${e.isNeed ? 'Need' : 'Want'}',
                            amount: money(e.amount),
                            accent: e.isNeed ? AppColors.need : AppColors.want,
                            onTap: () => showExpenseActions(
                              context,
                              e,
                              bottomInset: navClearance(context),
                            ),
                          ),
                          final ({JarDeposit deposit, SavingsJar jar}) d =>
                            _depositRow(context, d),
                          _ => const SizedBox.shrink(),
                        },
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
