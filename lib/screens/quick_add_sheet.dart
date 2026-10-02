import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_state.dart';
import '../app/format.dart';
import '../app/models.dart';
import '../app/theme.dart';
import '../widgets/glass.dart';
import '../widgets/gradient_button.dart';
import '../widgets/pressable.dart';

Future<void> showQuickAddSheet(BuildContext context) {
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
    builder: (_) => const QuickAddSheet(),
  );
}

class QuickAddSheet extends StatefulWidget {
  const QuickAddSheet({super.key});

  @override
  State<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<QuickAddSheet> {
  String _input = '';
  ExpenseCategory _category = ExpenseCategory.other;
  bool _isNeed = false;

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
      _input = p.amount == p.amount.roundToDouble()
          ? p.amount.toStringAsFixed(0)
          : p.amount.toStringAsFixed(2);
      _category = p.category;
      _isNeed = p.isNeed;
    });
  }

  void _save() {
    if (_amount <= 0) return;
    AppScope.read(context)
        .addExpense(amount: _amount, category: _category, isNeed: _isNeed);
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return FrostedGlass(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      sigma: 30,
      tint: AppColors.surface.withValues(alpha: 0.78),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 10, 20, bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Quick add',
              style: AppText.label,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            _AmountDisplay(input: _input),
            const SizedBox(height: 6),
            AnimatedSwitcher(
              duration: Motion.fast,
              child: Text(
                '${_category.emoji} ${_category.label}',
                key: ValueKey(_category),
                textAlign: TextAlign.center,
                style: AppText.label,
              ),
            ),
            const SizedBox(height: 18),
            _Presets(selected: _category, onTap: _preset),
            const SizedBox(height: 16),
            _NeedWantToggle(
              isNeed: _isNeed,
              onChanged: (v) {
                HapticFeedback.selectionClick();
                setState(() => _isNeed = v);
              },
            ),
            const SizedBox(height: 14),
            _Keypad(onKey: _key),
            const SizedBox(height: 16),
            GradientButton(
              label: _amount > 0 ? 'Log ${money(_amount)}' : 'Enter an amount',
              gradient: _isNeed ? AppGradients.good : AppGradients.hot,
              glow: _isNeed ? AppColors.cyan : AppColors.pink,
              onTap: _amount > 0 ? _save : null,
            ),
          ],
        ),
      ),
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
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        for (final p in ExpensePreset.all)
          Pressable(
            onTap: () => onTap(p),
            haptic: false,
            child: AnimatedContainer(
              duration: Motion.fast,
              curve: Motion.out,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: selected == p.category
                    ? AppColors.violet.withValues(alpha: 0.25)
                    : Colors.white.withValues(alpha: 0.06),
                border: Border.all(
                  color: selected == p.category
                      ? AppColors.violet.withValues(alpha: 0.8)
                      : AppColors.hairline,
                ),
              ),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '${p.category.emoji} '),
                    TextSpan(
                      text: p.category.label,
                      style: AppText.body.copyWith(fontSize: 14),
                    ),
                    TextSpan(
                      text:
                          '  ${money(p.amount, cents: p.amount != p.amount.roundToDouble())}',
                      style: AppText.label.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Segmented need/want toggle with a sliding pill.
class _NeedWantToggle extends StatelessWidget {
  const _NeedWantToggle({required this.isNeed, required this.onChanged});
  final bool isNeed;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final color = isNeed ? AppColors.need : AppColors.want;
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            alignment: isNeed ? Alignment.centerLeft : Alignment.centerRight,
            duration: Motion.med,
            curve: Motion.spring,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: AnimatedContainer(
                duration: Motion.med,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: color.withValues(alpha: 0.22),
                  border: Border.all(color: color.withValues(alpha: 0.7)),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.35),
                      blurRadius: 16,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (final need in [true, false])
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(need),
                    child: Center(
                      child: AnimatedDefaultTextStyle(
                        duration: Motion.fast,
                        style: AppText.body.copyWith(
                          fontWeight: FontWeight.w700,
                          color: need == isNeed
                              ? (need ? AppColors.need : AppColors.want)
                              : AppColors.muted,
                        ),
                        child: Text(need ? 'Need' : 'Want'),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
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
                        Icons.backspace_outlined,
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
