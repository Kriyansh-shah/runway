import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_state.dart';
import '../app/budget_math.dart';
import '../app/format.dart';
import '../app/models.dart';
import '../app/theme.dart';
import '../widgets/expense_inputs.dart';
import '../widgets/gradient_button.dart';
import '../widgets/mochi.dart';
import '../widgets/transitions.dart';
import 'history_screen.dart';
import 'savings_goal_sheet.dart';

Future<void> showRecapSheet(BuildContext context, Recap recap) {
  HapticFeedback.mediumImpact();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    elevation: 0,
    builder: (_) => RecapSheet(recap: recap),
  );
}

/// "That's a wrap on October": how a finished term or month went, shown
/// once when it ends.
class RecapSheet extends StatelessWidget {
  const RecapSheet({super.key, required this.recap});

  final Recap recap;

  @override
  Widget build(BuildContext context) {
    final ended = recap.ended;
    final term = ended.term;
    final s = summarize(ended);
    final over = s.left < 0;
    final monthly = term.period == BudgetPeriod.monthly;
    final before = recap.before;
    final change = before == null ? null : biggestChange(ended, before);
    final top = s.topCategories.firstOrNull;
    final needs = (s.needShare * 100).round();

    return SheetFrame(
      children: [
        Center(
          child: Mochi(
            mood: over ? PetMood.worried : PetMood.thriving,
            size: 96,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'That\'s a wrap on ${term.name}',
          style: AppText.heading,
          textAlign: TextAlign.center,
        ),
        Text(
          '${term.period.label} · ${dateRange(term.start, term.end)}',
          style: AppText.label,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 18),
        Text(
          money(over ? s.left.abs() : s.leftOver),
          style: AppText.number.copyWith(
            fontSize: 40,
            color: over ? AppColors.red : AppColors.lime,
          ),
          textAlign: TextAlign.center,
        ),
        Text(
          switch ((over, monthly)) {
            (false, true) => 'left over, carried into this month',
            (false, false) => 'left over',
            (true, true) => 'over, set aside to cover this month',
            (true, false) => 'more than you had',
          },
          style: AppText.label,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 18),
        if (s.savingsGoal > 0)
          _Line(
            'Saved',
            '${money(s.saved, cents: false)} of '
                '${money(s.savingsGoal, cents: false)}'
                '${s.saved >= s.savingsGoal - 0.005 ? ' 🎉' : ''}',
          ),
        _Line('Spent', money(s.spent)),
        if (s.moneyIn > 0) _Line('Money in', money(s.moneyIn)),
        if (s.spent > 0) _Line('Needs vs wants', '$needs% · ${100 - needs}%'),
        if (top != null)
          _Line(
            'Biggest spend',
            '${top.category.emoji} ${top.category.label} '
                '${money(top.amount, cents: false)}',
          ),
        if (change != null && before != null) ...[
          const SizedBox(height: 10),
          Text(
            _changeText(change, before.term.name),
            style: AppText.body.copyWith(
              color: change.change < 0 ? AppColors.lime : AppColors.butter,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        if (monthly) ...[const SizedBox(height: 16), const _NextGoal()],
        const SizedBox(height: 20),
        GradientButton(label: 'Nice', onTap: () => Navigator.of(context).pop()),
        const SizedBox(height: 4),
        Center(
          child: TextButton(
            onPressed: () {
              final navigator = Navigator.of(context)..pop();
              navigator.push(
                FadeScaleRoute<void>(builder: (_) => const HistoryScreen()),
              );
            },
            child: Text('See all history', style: AppText.label),
          ),
        ),
      ],
    );
  }

  /// "30% less on Delivery than in September 🎉", or the rise if nothing
  /// fell.
  static String _changeText(CategoryChange c, String beforeName) {
    final percent = (c.change.abs() * 100).round();
    final what = '${c.category.emoji} ${c.category.label}';
    return c.change < 0
        ? '$percent% less on $what than in $beforeName 🎉'
        : '$what was up $percent% on $beforeName';
  }
}

/// The goal carries into the new month: keep it, change it, or skip it.
class _NextGoal extends StatelessWidget {
  const _NextGoal();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final term = state.term;
    final goal = term.savingsGoal;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            goal > 0
                ? 'Save ${money(goal, cents: false)} again in ${term.name}?'
                : 'Save something in ${term.name}?',
            style: AppText.body.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (goal > 0) ...[
                ChoiceChipPill(
                  selected: true,
                  color: AppColors.lime,
                  onTap: () => Navigator.of(context).pop(),
                  child: Text('Keep ${money(goal, cents: false)}'),
                ),
                ChoiceChipPill(
                  selected: false,
                  onTap: () => showSavingsGoalSheet(context),
                  child: const Text('Change'),
                ),
                ChoiceChipPill(
                  selected: false,
                  onTap: () => state.setSavingsGoal(0),
                  child: const Text('Skip this month'),
                ),
              ] else
                ChoiceChipPill(
                  selected: false,
                  color: AppColors.lime,
                  onTap: () => showSavingsGoalSheet(context),
                  child: const Text('Set a goal'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Expanded(child: Text(label, style: AppText.body)),
        Text(value, style: AppText.body.copyWith(fontWeight: FontWeight.w600)),
      ],
    ),
  );
}
