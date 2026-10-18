import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_state.dart';
import '../app/format.dart';
import '../app/theme.dart';
import '../widgets/expense_inputs.dart';
import '../widgets/form_fields.dart';
import '../widgets/gradient_button.dart';
import '../widgets/ph_icons.dart';

Future<void> showSavingsGoalSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    elevation: 0,
    builder: (_) => const SavingsGoalSheet(),
  );
}

/// A suggested goal: [share] of [money], rounded down to $5 (or $1 when
/// that's under $5).
double suggestedGoal(double money, double share) {
  final raw = money * share;
  if (raw < 5) return raw.floorToDouble();
  return (raw / 5).floorToDouble() * 5;
}

/// Sets or changes this term's savings goal, showing what it does to the
/// daily budget before saving.
class SavingsGoalSheet extends StatefulWidget {
  const SavingsGoalSheet({super.key});

  @override
  State<SavingsGoalSheet> createState() => _SavingsGoalSheetState();
}

class _SavingsGoalSheetState extends State<SavingsGoalSheet> {
  late final _amount = TextEditingController(
    text: switch (AppScope.read(context).term.savingsGoal) {
      0 => '',
      final goal => amountText(goal),
    },
  );

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  double get _value => parseAmountInput(_amount.text);

  void _pick(double goal) {
    HapticFeedback.selectionClick();
    setState(() => _amount.text = goal == 0 ? '' : amountText(goal));
  }

  void _save() {
    AppScope.read(context).setSavingsGoal(_value);
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final noun = state.term.period.noun;
    final now = state.snapshot;
    final max = now.maxSavingsGoal;
    final tooMuch = _value > max + 0.005;
    final after = state.snapshotWithGoal(tooMuch ? max : _value);
    final changed = _value != state.term.savingsGoal;
    final suggestions = {
      for (final share in [0.1, 0.2])
        if (suggestedGoal(max, share) > 0)
          suggestedGoal(max, share): '${(share * 100).round()}%',
    };

    return SheetFrame(
      children: [
        Text(
          'Save this $noun',
          style: AppText.heading,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'Runway sets it aside now and spreads the rest over your days. '
          'Anything else left at the end carries on as spending money.',
          style: AppText.label,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        AmountField(
          controller: _amount,
          style: AppText.number,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final MapEntry(key: goal, value: label) in suggestions.entries)
              ChoiceChipPill(
                selected: _value == goal,
                color: AppColors.lime,
                onTap: () => _pick(goal),
                child: Text('$label · ${money(goal, cents: false)}'),
              ),
            ChoiceChipPill(
              selected: _value == 0,
              onTap: () => _pick(0),
              child: const Text('No goal'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          tooMuch
              ? 'You have ${money(max, cents: false)} that isn\'t already set '
                    'aside for big costs, so that\'s the most you can save.'
              : 'Safe to spend each day: ${money(now.dailyAllowance)}'
                    '${changed ? ' → ${money(after.dailyAllowance)}' : ''}',
          style: AppText.label.copyWith(
            color: tooMuch ? AppColors.butter : AppColors.text,
          ),
        ),
        const SizedBox(height: 18),
        GradientButton(
          label: _value == 0
              ? 'No goal for now'
              : 'Save ${money(_value, cents: _value != _value.roundToDouble())}'
                    ' goal',
          icon: PhIcons.checkBold,
          onTap: tooMuch ? null : _save,
        ),
      ],
    );
  }
}
