import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_state.dart';
import '../app/format.dart';
import '../app/models.dart';
import '../app/theme.dart';
import '../widgets/expense_inputs.dart';
import '../widgets/form_fields.dart';
import '../widgets/gradient_button.dart';
import '../widgets/ph_icons.dart';

Future<void> showAddIncomeSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    elevation: 0,
    builder: (_) => const AddIncomeSheet(),
  );
}

/// Adds a paycheck, allowance or one-off payment. It counts toward the
/// budget only on the days it arrives.
class AddIncomeSheet extends StatefulWidget {
  const AddIncomeSheet({super.key});

  @override
  State<AddIncomeSheet> createState() => _AddIncomeSheetState();
}

class _AddIncomeSheetState extends State<AddIncomeSheet> {
  final _name = TextEditingController();
  final _amount = TextEditingController();
  var _frequency = IncomeFrequency.once;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    _date = _clampToTerm(AppScope.read(context).today);
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  Term get _term => AppScope.read(context).term;
  double get _value => parseAmountInput(_amount.text);
  bool get _ready => _name.text.trim().isNotEmpty && _value > 0;

  DateTime _clampToTerm(DateTime d) {
    final term = _term;
    if (d.isBefore(term.start)) return term.start;
    if (d.isAfter(term.end)) return term.end;
    return d;
  }

  /// Repeating pay starts from the next payday: earlier ones are already in
  /// the money you had when you set up the term, so they'd count twice.
  DateTime get _firstAllowed => _frequency == IncomeFrequency.once
      ? _term.start
      : _clampToTerm(AppScope.read(context).today);

  void _setFrequency(IncomeFrequency f) {
    HapticFeedback.selectionClick();
    setState(() {
      _frequency = f;
      if (_date.isBefore(_firstAllowed)) _date = _firstAllowed;
    });
  }

  Future<void> _pickDate() async {
    final picked = await pickDate(
      context,
      initial: _date,
      first: _firstAllowed,
      last: _term.end,
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _save() {
    if (!_ready) return;
    AppScope.read(context).addIncome(
      name: _name.text,
      amount: _value,
      frequency: _frequency,
      firstDate: _date,
    );
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final today = AppScope.of(context).today;
    final arrived = !_date.isAfter(today);
    final hint = switch ((_frequency == IncomeFrequency.once, arrived)) {
      (true, true) =>
        'Counts right away. Skip it if it\'s already in your starting money.',
      (true, false) => 'Counts on ${shortDate(_date)}, the day it arrives.',
      (false, _) => 'Each payday counts on the day it lands, never before.',
    };
    return SheetFrame(
      children: [
        Text(
          'Money coming in',
          style: AppText.heading,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        const FieldLabel('What is it?'),
        GlassTextField(
          controller: _name,
          hint: 'e.g. Campus job, Scholarship',
          icon: PhIcons.notePencil,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 14),
        const FieldLabel('How often'),
        ChipRow(
          children: [
            for (final f in IncomeFrequency.values)
              ChoiceChipPill(
                key: ValueKey(f),
                selected: f == _frequency,
                color: AppColors.lime,
                onTap: () => _setFrequency(f),
                child: Text(f.label),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FieldLabel(
                    _frequency == IncomeFrequency.once ? 'Amount' : 'Each time',
                  ),
                  AmountField(
                    controller: _amount,
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DateField(
                label: _frequency == IncomeFrequency.once
                    ? 'Arrives'
                    : 'Next payday',
                date: _date,
                onTap: _pickDate,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(hint, style: AppText.label),
        const SizedBox(height: 18),
        GradientButton(
          label: _ready ? 'Add ${money(_value)}' : 'Add money',
          icon: PhIcons.plusBold,
          onTap: _ready ? _save : null,
        ),
      ],
    );
  }
}
