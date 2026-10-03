import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_state.dart';
import '../app/budget_math.dart';
import '../app/format.dart';
import '../app/models.dart';
import '../app/theme.dart';
import '../widgets/expense_inputs.dart';
import '../widgets/gradient_button.dart';
import '../widgets/ph_icons.dart';

Future<void> showSplitBillSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    elevation: 0,
    sheetAnimationStyle: const AnimationStyle(
      duration: Motion.med,
      reverseDuration: Motion.fast,
      curve: Motion.out,
    ),
    builder: (_) => const SplitBillSheet(),
  );
}

/// You paid for something shared; split it evenly with roommates.
class SplitBillSheet extends StatefulWidget {
  const SplitBillSheet({super.key});

  @override
  State<SplitBillSheet> createState() => _SplitBillSheetState();
}

class _SplitBillSheetState extends State<SplitBillSheet> {
  final _description = TextEditingController();
  final _amount = TextEditingController();
  final _selected = <String>{};
  ExpenseCategory _category = ExpenseCategory.groceries;
  bool _isNeed = true;

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    super.dispose();
  }

  double get _total => double.tryParse(_amount.text) ?? 0;

  bool get _ready =>
      _total > 0 && _selected.isNotEmpty && _description.text.trim().isNotEmpty;

  void _toggle(Friend f) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_selected.remove(f.id)) _selected.add(f.id);
    });
  }

  void _save() {
    if (!_ready) return;
    final state = AppScope.read(context);
    state.splitBill(
      description: _description.text.trim(),
      total: _total,
      roommates: state.friends.where((f) => _selected.contains(f.id)).toList(),
      category: _category,
      isNeed: _isNeed,
    );
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final friends = AppScope.of(context).friends;
    final chosen = friends.where((f) => _selected.contains(f.id)).toList();
    final shares = splitEvenly(_total, chosen.length);

    return SheetFrame(
      children: [
        Text('Split a bill', style: AppText.title, textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text(
          'You paid — your roommates pay you back',
          style: AppText.label,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        const FieldLabel('What was it?'),
        GlassTextField(
          controller: _description,
          hint: 'e.g. Costco run, Uber home, Wi-Fi',
          icon: PhIcons.notePencil,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 14),
        const FieldLabel('Total you paid'),
        GlassTextField(
          controller: _amount,
          hint: '0.00',
          prefixText: '\$ ',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d{0,5}(\.\d{0,2})?')),
          ],
          maxLength: 8,
          style: AppText.number,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        const FieldLabel('Split with'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final f in friends)
              ChoiceChipPill(
                key: ValueKey(f.id),
                selected: _selected.contains(f.id),
                color: AppColors.lime,
                onTap: () => _toggle(f),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${f.emoji} ${f.name}'),
                    AnimatedSize(
                      duration: Motion.fast,
                      child: _selected.contains(f.id)
                          ? const Padding(
                              padding: EdgeInsets.only(left: 6),
                              child: Icon(
                                PhIcons.checkBold,
                                size: 16,
                                color: AppColors.lime,
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        const FieldLabel('Category (for your share)'),
        CategoryPicker(
          selected: _category,
          onChanged: (c) => setState(() => _category = c),
        ),
        const SizedBox(height: 14),
        NeedWantToggle(
          isNeed: _isNeed,
          onChanged: (v) => setState(() => _isNeed = v),
        ),
        const SizedBox(height: 16),
        AnimatedSize(
          duration: Motion.med,
          curve: Motion.out,
          alignment: Alignment.topCenter,
          child: chosen.isEmpty || _total <= 0
              ? const SizedBox(width: double.infinity)
              : _Preview(
                  each: shares.each,
                  mine: shares.mine,
                  people: [for (final f in chosen) f.name],
                ),
        ),
        const SizedBox(height: 8),
        GradientButton(
          label: _total > 0 ? 'Split ${money(_total)}' : 'Split bill',
          onTap: _ready ? _save : null,
        ),
      ],
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({
    required this.each,
    required this.mine,
    required this.people,
  });
  final double each;
  final double mine;
  final List<String> people;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final p in people)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(child: Text('$p owes you', style: AppText.body)),
                  Text(
                    money(each),
                    style: AppText.number.copyWith(
                      fontSize: 16,
                      color: AppColors.lime,
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Your share (counts as spending)',
                  style: AppText.label,
                ),
              ),
              Text(money(mine), style: AppText.number.copyWith(fontSize: 16)),
            ],
          ),
        ],
      ),
    );
  }
}
