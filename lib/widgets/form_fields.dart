import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/format.dart';
import '../app/models.dart';
import '../app/theme.dart';
import 'expense_inputs.dart';
import 'ph_icons.dart';
import 'pressable.dart';

/// Dollars with at most 6 whole digits and 2 decimals ($999,999.99).
final amountInputFormatter = FilteringTextInputFormatter.allow(
  RegExp(r'^\d{0,6}(\.\d{0,2})?'),
);

/// The typed amount, or 0 when empty or unreadable.
double parseAmountInput(String text) => double.tryParse(text) ?? 0;

/// `$`-prefixed numeric field that only accepts [amountInputFormatter] input.
class AmountField extends StatelessWidget {
  const AmountField({
    super.key,
    required this.controller,
    this.onChanged,
    this.style,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return GlassTextField(
      controller: controller,
      hint: '0.00',
      prefixText: '\$ ',
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [amountInputFormatter],
      maxLength: 9,
      style: style,
      onChanged: onChanged,
    );
  }
}

/// Opens the platform date picker limited to [first]..[last].
Future<DateTime?> pickDate(
  BuildContext context, {
  required DateTime initial,
  required DateTime first,
  required DateTime last,
}) => showDatePicker(
  context: context,
  initialDate: initial.isBefore(first)
      ? first
      : (initial.isAfter(last) ? last : initial),
  firstDate: first,
  lastDate: last,
);

/// Tappable date box styled like [GlassTextField].
class DateField extends StatelessWidget {
  const DateField({
    super.key,
    this.label,
    required this.date,
    required this.onTap,
  });
  final String? label;
  final DateTime? date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final d = date;
    final text = d == null ? 'Pick date' : '${shortDate(d)}, ${d.year}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) FieldLabel(label!),
        Pressable(
          onTap: onTap,
          scale: 0.98,
          semanticLabel: '${label ?? 'Due date'}: $text',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Text(
              text,
              style: AppText.body.copyWith(
                color: d == null ? AppColors.muted : AppColors.text,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Name, amount and due date for a big upcoming cost, an "Every month"
/// toggle for repeating bills, and an "Add cost" chip that lights up once
/// the first three are filled in.
class AddCostForm extends StatefulWidget {
  const AddCostForm({
    super.key,
    required this.firstDate,
    required this.lastDate,
    required this.onAdd,
  });

  /// Due dates can be picked from [firstDate] to [lastDate].
  final DateTime firstDate;
  final DateTime lastDate;

  /// [monthly]: the cost is the first month of a repeating bill.
  final void Function(UpcomingCost cost, {required bool monthly}) onAdd;

  @override
  State<AddCostForm> createState() => _AddCostFormState();
}

class _AddCostFormState extends State<AddCostForm> {
  final _name = TextEditingController();
  final _amount = TextEditingController();
  DateTime? _due;
  bool _monthly = false;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  double get _value => parseAmountInput(_amount.text);

  bool get _ready => _name.text.trim().isNotEmpty && _value > 0 && _due != null;

  Future<void> _pickDue() async {
    final picked = await pickDate(
      context,
      initial: _due ?? widget.firstDate,
      first: widget.firstDate,
      last: widget.lastDate,
    );
    if (picked != null) setState(() => _due = picked);
  }

  void _add() {
    if (!_ready) return;
    HapticFeedback.selectionClick();
    widget.onAdd(
      UpcomingCost(
        id: 'u${DateTime.now().microsecondsSinceEpoch}',
        emoji: '📌',
        name: _name.text.trim(),
        amount: _value,
        dueDate: _due!,
      ),
      monthly: _monthly,
    );
    setState(() {
      _name.clear();
      _amount.clear();
      _due = null;
      _monthly = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassTextField(
          controller: _name,
          hint: 'e.g. Flight home',
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: AmountField(
                controller: _amount,
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DateField(date: _due, onTap: _pickDue),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            ChoiceChipPill(
              selected: _ready,
              color: AppColors.lime,
              onTap: _add,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(PhIcons.plusBold, size: 16),
                  SizedBox(width: 6),
                  Text('Add cost'),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ChoiceChipPill(
              selected: _monthly,
              onTap: () => setState(() => _monthly = !_monthly),
              child: const Text('Every month'),
            ),
          ],
        ),
      ],
    );
  }
}

/// A monthly budget always ends with the calendar month, so its end date is
/// shown, not picked.
class MonthEndField extends StatelessWidget {
  const MonthEndField({super.key, required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const FieldLabel('Ends'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
          child: Text(
            '${shortDate(date)}, then monthly',
            style: AppText.body.copyWith(color: AppColors.muted),
          ),
        ),
      ],
    );
  }
}
