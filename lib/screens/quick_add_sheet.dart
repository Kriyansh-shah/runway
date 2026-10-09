import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_state.dart';
import '../app/format.dart';
import '../app/models.dart';
import '../app/purchase_link.dart';
import '../app/theme.dart';
import '../widgets/category_icon.dart';
import '../widgets/expense_inputs.dart';
import '../widgets/gradient_button.dart';
import '../widgets/pressable.dart';
import '../widgets/ph_icons.dart';

/// Returns where the Log button was (global), so the caller can fly a coin
/// from it; null if the sheet was dismissed or an expense was edited.
/// [purchase] pre-fills the sheet from an Apple Pay automation; [editing]
/// opens an existing expense to change it.
Future<Offset?> showQuickAddSheet(
  BuildContext context, {
  ApplePayPurchase? purchase,
  Expense? editing,
}) {
  return showModalBottomSheet<Offset>(
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
    builder: (_) => QuickAddSheet(purchase: purchase, editing: editing),
  );
}

class QuickAddSheet extends StatefulWidget {
  const QuickAddSheet({super.key, this.purchase, this.editing});

  /// Set when the sheet opens from an Apple Pay purchase.
  final ApplePayPurchase? purchase;

  /// Set when changing an expense that's already logged.
  final Expense? editing;

  @override
  State<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<QuickAddSheet> {
  String _input = '';
  ExpenseCategory _category = ExpenseCategory.other;
  bool _isNeed = false;
  final _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.editing case final e?) {
      _input = _amountText(e.amount);
      _note.text = e.note ?? '';
      _category = e.category;
      _isNeed = e.isNeed;
      return;
    }
    final purchase = widget.purchase;
    if (purchase == null) return;
    if (purchase.amount case final amount?) _input = _amountText(amount);
    _note.text = purchase.merchant ?? '';
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  double get _amount => double.tryParse(_input) ?? 0;

  void _key(String k) {
    final next = switch (k) {
      '⌫' => _input.isEmpty ? '' : _input.substring(0, _input.length - 1),
      '.' =>
        _input.contains('.') ? _input : (_input.isEmpty ? '0.' : '$_input.'),
      _ => _appendDigit(k),
    };
    if (next == _input) {
      HapticFeedback.heavyImpact();
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _input = next);
  }

  String _appendDigit(String d) {
    if (_input == '0') return d;
    final dot = _input.indexOf('.');
    if (dot >= 0 && _input.length - dot > 2) return _input; // 2 decimals max
    if (dot < 0 && _input.length >= 5) return _input; // $99,999 max
    return '$_input$d';
  }

  void _preset(ExpensePreset p) {
    HapticFeedback.lightImpact();
    setState(() {
      _input = _amountText(p.amount);
      _category = p.category;
      _isNeed = p.isNeed;
    });
  }

  static String _amountText(double amount) => amount == amount.roundToDouble()
      ? amount.toStringAsFixed(0)
      : amount.toStringAsFixed(2);

  final _logKey = GlobalKey();

  void _save() {
    if (_amount <= 0) return;
    final note = _note.text.trim();
    if (widget.editing case final e?) {
      AppScope.read(context).updateExpense(
        e.copyWith(
          amount: _amount,
          category: _category,
          isNeed: _isNeed,
          note: () => note.isEmpty ? null : note,
        ),
      );
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop();
      return;
    }
    final box = _logKey.currentContext?.findRenderObject() as RenderBox?;
    final from = box?.localToGlobal(box.size.center(Offset.zero));
    AppScope.read(context).addExpense(
      amount: _amount,
      category: _category,
      isNeed: _isNeed,
      note: note.isEmpty ? null : note,
    );
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(from);
  }

  @override
  Widget build(BuildContext context) {
    return SheetFrame(
      children: [
        Text(
          widget.editing != null
              ? 'Edit expense'
              : (widget.purchase == null ? 'Quick add' : 'From Apple Pay'),
          style: AppText.label,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        _AmountDisplay(input: _input),
        const SizedBox(height: 10),
        GlassTextField(
          controller: _note,
          hint: 'What was it? e.g. Uber to airport',
          icon: PhIcons.notePencil,
        ),
        const SizedBox(height: 16),
        const FieldLabel('Quick picks'),
        _Presets(selected: _category, onTap: _preset),
        const SizedBox(height: 14),
        const FieldLabel('Category'),
        CategoryPicker(
          selected: _category,
          onChanged: (c) => setState(() => _category = c),
        ),
        const SizedBox(height: 16),
        NeedWantToggle(
          isNeed: _isNeed,
          onChanged: (v) => setState(() => _isNeed = v),
        ),
        const SizedBox(height: 14),
        _Keypad(onKey: _key),
        const SizedBox(height: 16),
        GradientButton(
          key: _logKey,
          label: _amount <= 0
              ? 'Enter an amount'
              : '${widget.editing == null ? 'Log' : 'Save'} ${money(_amount)}',
          gradient: _isNeed ? AppGradients.good : AppGradients.hot,
          glow: _isNeed ? AppColors.lime : AppColors.pink,
          onTap: _amount > 0 ? _save : null,
        ),
      ],
    );
  }
}

class _AmountDisplay extends StatelessWidget {
  const _AmountDisplay({required this.input});
  final String input;

  @override
  Widget build(BuildContext context) {
    final empty = input.isEmpty;
    return SizedBox(
      height: 76,
      child: FittedBox(
        child: TweenAnimationBuilder<double>(
          // Re-keyed per value so each keystroke gives a tiny springy pop.
          key: ValueKey(input),
          tween: Tween(begin: 0.92, end: 1),
          duration: Motion.med,
          curve: Motion.spring,
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '\$',
                  style: AppText.title.copyWith(color: AppColors.muted),
                ),
              ),
              const SizedBox(width: 2),
              Text(
                empty ? '0' : input,
                style: AppText.display.copyWith(
                  fontSize: 64,
                  color: empty
                      ? AppColors.muted.withValues(alpha: 0.6)
                      : AppColors.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Presets extends StatelessWidget {
  const _Presets({required this.selected, required this.onTap});
  final ExpenseCategory selected;
  final ValueChanged<ExpensePreset> onTap;

  @override
  Widget build(BuildContext context) {
    return ChipRow(
      children: [
        for (final p in ExpensePreset.all)
          ChoiceChipPill(
            selected: selected == p.category,
            onTap: () => onTap(p),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CategoryIcon(p.category, size: 17),
                const SizedBox(width: 6),
                Text(p.category.label),
                const SizedBox(width: 6),
                Text(
                  money(p.amount, cents: p.amount != p.amount.roundToDouble()),
                  style: AppText.label.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({required this.onKey});
  final ValueChanged<String> onKey;

  static const _keys = [
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '.',
    '0',
    '⌫',
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.3,
      padding: EdgeInsets.zero,
      children: [
        for (final k in _keys)
          Pressable(
            onTap: () => onKey(k),
            scale: 0.92,
            haptic: false,
            semanticLabel: k == '⌫' ? 'Delete' : k,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Center(
                child: k == '⌫'
                    ? const Icon(
                        PhIcons.backspace,
                        color: AppColors.text,
                        size: 22,
                      )
                    : Text(k, style: AppText.number.copyWith(fontSize: 26)),
              ),
            ),
          ),
      ],
    );
  }
}
