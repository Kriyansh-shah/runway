import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../app/format.dart';
import '../app/models.dart';
import '../app/theme.dart';
import '../widgets/glass.dart';
import '../widgets/gradient_button.dart';
import '../widgets/motion.dart';
import '../widgets/ph_icons.dart';
import 'savings_goal_sheet.dart';
import 'shell.dart';

/// This term's savings goal, everything saved so far, and how past terms
/// and months went.
class SavingsScreen extends StatelessWidget {
  const SavingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final sections = <Widget>[
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text('Savings', style: AppText.title),
      ),
      _GoalCard(state: state),
      _TotalCard(state: state),
      if (state.savingsHistory.isNotEmpty)
        _PastSavings(history: state.savingsHistory),
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

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final term = state.term;
    final s = state.snapshot;
    final goal = term.savingsGoal;
    final noun = term.period.noun;
    if (goal == 0) {
      return GlassCard(
        strong: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('No goal for ${term.name} yet', style: AppText.heading),
            const SizedBox(height: 4),
            Text(
              'Pick an amount to save this $noun. Runway sets it aside '
              'right away, so your daily budget already leaves it alone.',
              style: AppText.label,
            ),
            const SizedBox(height: 16),
            GradientButton(
              label: 'Set a savings goal',
              icon: PhIcons.piggyBank,
              onTap: () => showSavingsGoalSheet(context),
            ),
          ],
        ),
      );
    }
    final kept = s.savingsKept;
    final dipped = s.dippedIntoSavings;
    return GlassCard(
      strong: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: SizedBox.square(
              dimension: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: kept / goal),
                    duration: Motion.slow,
                    curve: Motion.roll,
                    builder: (context, v, _) => CustomPaint(
                      size: const Size.square(200),
                      painter: _SavingsRing(kept: v, dipped: dipped > 0.005),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Set aside', style: AppText.label),
                      const SizedBox(height: 4),
                      Text(
                        money(kept, cents: kept != kept.roundToDouble()),
                        style: AppText.number.copyWith(fontSize: 34),
                      ),
                      Text(
                        'of ${money(goal, cents: false)} for ${term.name}',
                        style: AppText.caption.copyWith(letterSpacing: 0),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            dipped > 0.005
                ? 'You\'ve spent ${money(dipped)} of it. Stay under your '
                      'daily budget to keep the rest.'
                : 'Safe as long as you stay on budget. It counts as saved '
                      'when the $noun ends.',
            style: AppText.body.copyWith(
              color: dipped > 0.005 ? AppColors.butter : AppColors.text,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          Center(
            child: TextButton.icon(
              onPressed: () => showSavingsGoalSheet(context),
              icon: const Icon(
                PhIcons.notePencil,
                size: 18,
                color: AppColors.lime,
              ),
              label: Text(
                'Change goal',
                style: AppText.body.copyWith(
                  color: AppColors.lime,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final total = state.totalSaved;
    final kept = state.snapshot.savingsKept;
    final streak = state.savingsStreak;
    final period =
        state.savingsHistory.firstOrNull?.period ?? state.term.period;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Saved so far', style: AppText.heading),
              const Spacer(),
              if (streak > 0)
                Pill(
                  label: '🔥 ${plural(streak, period.noun)} in a row',
                  color: AppColors.lime,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            money(total, cents: total != total.roundToDouble()),
            style: AppText.number.copyWith(fontSize: 34),
          ),
          const SizedBox(height: 2),
          Text(
            total == 0 && kept == 0
                ? 'What you keep of each goal adds up here.'
                : kept > 0
                ? '+ ${money(kept, cents: false)} more when ${state.term.name} '
                      'ends, if you keep it'
                : 'From the ${state.term.period.noun}s you\'ve finished',
            style: AppText.label,
          ),
        ],
      ),
    );
  }
}

class _PastSavings extends StatelessWidget {
  const _PastSavings({required this.history});
  final List<SavedTerm> history;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Past goals'),
        GlassCard(
          child: Column(
            children: [
              for (final (i, t) in history.indexed) ...[
                if (i > 0) Divider(color: AppColors.hairline, height: 20),
                Row(
                  children: [
                    Expanded(child: Text(t.name, style: AppText.body)),
                    Text(
                      t.goal == 0
                          ? 'No goal'
                          : '${money(t.saved, cents: false)} of '
                                '${money(t.goal, cents: false)}',
                      style: AppText.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: t.goal == 0 ? AppColors.muted : AppColors.text,
                      ),
                    ),
                    if (t.goal > 0) ...[
                      const SizedBox(width: 8),
                      Icon(
                        t.hitGoal ? PhIcons.checkCircle : PhIcons.warningCircle,
                        size: 18,
                        color: t.hitGoal ? AppColors.lime : AppColors.butter,
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Lime ring for the part of the goal still set aside; butter once some
/// of it has been spent.
class _SavingsRing extends CustomPainter {
  _SavingsRing({required this.kept, required this.dipped});
  final double kept;
  final bool dipped;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 12.0;
    final arcRect = (Offset.zero & size).deflate(stroke / 2 + 4);
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
    final sweep = 2 * math.pi * kept.clamp(0.0, 1.0);
    if (sweep <= 0.001) return;
    canvas.drawArc(
      arcRect,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = dipped ? AppColors.butter : AppColors.lime,
    );
  }

  @override
  bool shouldRepaint(_SavingsRing old) =>
      old.kept != kept || old.dipped != dipped;
}
