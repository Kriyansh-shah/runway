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

Future<void> showEditCostSheet(BuildContext context, UpcomingCost cost) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    elevation: 0,
    builder: (_) => EditCostSheet(cost: cost),
  );
}

/// Changes a big cost's name, amount or due date. A monthly bill keeps its
/// day of the month; a new name or amount applies from this month on.
class EditCostSheet extends StatefulWidget {
  const EditCostSheet({super.key, required this.cost});

  final UpcomingCost cost;

  @override
  State<EditCostSheet> createState() => _EditCostSheetState();
}

class _EditCostSheetState extends State<EditCostSheet> {
  late final _name = TextEditingController(text: widget.cost.name);
  late final _amount = TextEditingController(
    text: amountText(widget.cost.amount),
  );
  late DateTime _due = widget.cost.dueDate;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  double get _value => parseAmountInput(_amount.text);
  bool get _ready => _name.text.trim().isNotEmpty && _value > 0;

  Future<void> _pickDue() async {
    final term = AppScope.read(context).term;
    final picked = await pickDate(
      context,
      initial: _due,
      first: term.start,
      last: term.end,
    );
    if (picked != null) setState(() => _due = picked);
  }

  void _save() {
    if (!_ready) return;
    final state = AppScope.read(context);
    final cost = widget.cost;
    if (cost.billId case final billId?) {
      state.updateBill(
        billId,
        name: _name.text,
        amount: _value,
        from: cost.dueDate,
      );
    } else {
      state.updateUpcomingCost(
        cost.copyWith(name: _name.text.trim(), amount: _value, dueDate: _due),
      );
    }
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final cost = widget.cost;
    return SheetFrame(
      children: [
        Text(
          cost.repeats ? 'Edit monthly bill' : 'Edit cost',
          style: AppText.heading,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        const FieldLabel('What is it?'),
        GlassTextField(
          controller: _name,
          hint: 'e.g. Flight home',
          icon: PhIcons.notePencil,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const FieldLabel('Amount'),
                  AmountField(
                    controller: _amount,
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
            if (!cost.repeats) ...[
              const SizedBox(width: 10),
              Expanded(
                child: DateField(label: 'Due', date: _due, onTap: _pickDue),
              ),
            ],
          ],
        ),
        if (cost.repeats) ...[
          const SizedBox(height: 10),
          Text(
            'Changes ${shortDate(cost.dueDate)} and every month after it. '
            'Months already paid stay as they were.',
            style: AppText.label,
          ),
        ],
        const SizedBox(height: 18),
        GradientButton(
          label: _ready ? 'Save ${money(_value)}' : 'Save',
          icon: PhIcons.checkBold,
          onTap: _ready ? _save : null,
        ),
      ],
    );
  }
}
