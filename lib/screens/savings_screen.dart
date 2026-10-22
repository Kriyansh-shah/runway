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
import '../widgets/pressable.dart';
import 'jar_sheets.dart';
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
      _Jars(state: state),
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
    // What the goal ends at if spending keeps its pace: the ring and the
    // big number are about the end of the term, not money in hand.
    final early = s.tooEarlyToForecast;
    final heading = early ? s.savingsKept : s.projectedSavings;
    final onTrack = early ? s.dippedIntoSavings <= 0.005 : s.onTrackToSave;
    final cents = heading != heading.roundToDouble();
    final daysLeft = s.daysLeft;
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
                    tween: Tween(begin: 0, end: heading / goal),
                    duration: Motion.slow,
                    curve: Motion.roll,
                    builder: (context, v, _) => CustomPaint(
                      size: const Size.square(200),
                      painter: _SavingsRing(kept: v, dipped: !onTrack),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        early
                            ? 'Your goal'
                            : onTrack
                            ? 'On track for'
                            : 'Heading for',
                        style: AppText.label,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        money(early ? goal : heading, cents: cents && !early),
                        style: AppText.number.copyWith(
                          fontSize: 34,
                          color: onTrack ? AppColors.text : AppColors.butter,
                        ),
                      ),
                      Text(
                        early
                            ? 'by ${shortDate(s.termEnd)}'
                            : 'of ${money(goal, cents: false)} by '
                                  '${shortDate(s.termEnd)}',
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
            early
                ? 'Too early to tell how it\'s going. Check back in a few '
                      'days.'
                : onTrack
                ? 'On track to save ${money(goal, cents: false)} by '
                      '${shortDate(s.termEnd)} 🎉'
                : 'At your pace you\'d keep ${money(heading, cents: false)} '
                      'of ${money(goal, cents: false)}. Spend '
                      '${money(s.savingsCutPerDay)}/day less to keep it all.',
            style: AppText.body.copyWith(
              color: onTrack ? AppColors.text : AppColors.butter,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            s.dailyAllowance > 0
                ? '${plural(daysLeft, 'day')} to go · under '
                      '${money(s.dailyAllowance)}/day keeps it all'
                : '${plural(daysLeft, 'day')} to go · more spending comes '
                      'out of it',
            style: AppText.label,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
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

/// Things being saved up for, each apart from the savings goal.
class _Jars extends StatelessWidget {
  const _Jars({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final jars = state.jars;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: SectionHeader('Saving for')),
            TextButton.icon(
              onPressed: () => showNewJarSheet(context),
              icon: const Icon(
                PhIcons.plusBold,
                size: 18,
                color: AppColors.lime,
              ),
              label: Text(
                'Add',
                style: AppText.body.copyWith(
                  color: AppColors.lime,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        if (jars.isEmpty)
          GlassCard(
            child: Text(
              'Want something big, like new headphones or a trip? Save for '
              'it here, a little at a time, apart from your savings goal.',
              style: AppText.label,
            ),
          )
        else
          for (final jar in jars)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _JarCard(state: state, jar: jar),
            ),
      ],
    );
  }
}

class _JarCard extends StatelessWidget {
  const _JarCard({required this.state, required this.jar});
  final AppState state;
  final SavingsJar jar;

  @override
  Widget build(BuildContext context) {
    final suggested = state.suggestedJarDeposit(jar);
    return Pressable(
      onTap: () => showJarSheet(context, jar.id),
      semanticLabel: 'Saving for ${jar.name}',
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    jar.name,
                    style: AppText.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  '${money(jar.saved, cents: false)} of '
                  '${money(jar.target, cents: false)}',
                  style: AppText.label,
                ),
              ],
            ),
            const SizedBox(height: 10),
            JarProgressBar(
              progress: jar.target == 0 ? 0 : jar.saved / jar.target,
            ),
            const SizedBox(height: 10),
            Text(
              jar.full
                  ? 'Ready to buy 🎉 Tap when you\'ve bought it.'
                  : suggested > 0
                  ? 'Tap to put ${money(suggested, cents: false)} in today'
                  : 'Tap to put money in',
              style: AppText.label.copyWith(
                color: jar.full ? AppColors.lime : AppColors.muted,
              ),
            ),
          ],
        ),
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
                      'ends, if you stay on budget'
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

/// Lime ring for the part of the goal you're on track to keep; butter
/// when the pace would eat into it.
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
