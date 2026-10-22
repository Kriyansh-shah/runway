import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_state.dart';
import '../app/coach.dart';
import '../app/format.dart';
import '../app/models.dart';
import '../app/theme.dart';
import '../widgets/action_sheet.dart';
import '../widgets/expense_inputs.dart';
import '../widgets/form_fields.dart';
import '../widgets/gradient_button.dart';
import '../widgets/ph_icons.dart';

Future<T?> _sheet<T>(BuildContext context, Widget child) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      elevation: 0,
      builder: (_) => child,
    );

/// Starts saving up for something; [name] and [price] fill it in (from
/// the coach). Returns the new jar, or null if the sheet was closed.
Future<SavingsJar?> showNewJarSheet(
  BuildContext context, {
  String? name,
  double? price,
}) => _sheet(context, NewJarSheet(name: name, price: price));

/// Put money into a jar, buy it, or stop saving for it.
Future<void> showJarSheet(BuildContext context, String jarId) =>
    _sheet(context, JarSheet(jarId: jarId));

class NewJarSheet extends StatefulWidget {
  const NewJarSheet({super.key, this.name, this.price});
  final String? name;
  final double? price;

  @override
  State<NewJarSheet> createState() => _NewJarSheetState();
}

class _NewJarSheetState extends State<NewJarSheet> {
  late final _name = TextEditingController(text: widget.name ?? '');
  late final _price = TextEditingController(
    text: widget.price == null ? '' : amountText(widget.price!),
  );

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  double get _value => parseAmountInput(_price.text);
  bool get _ready =>
      _name.text.trim().isNotEmpty && _value > 0 && _value < 1000000;

  void _save() {
    final jar = AppScope.read(context)
        .startJar(name: _name.text, target: _value);
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(jar);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final plan = _value > 0
        ? SavingsPlan.forShare(_value, state.grounding, 0.2)
        : null;
    return SheetFrame(
      children: [
        Text(
          'Save for something',
          style: AppText.heading,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'Separate from your savings goal. Money you put in is set aside, '
          'and it stays there when the ${state.term.period.noun} ends.',
          style: AppText.label,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        const FieldLabel('What for?'),
        GlassTextField(
          controller: _name,
          hint: 'Dior wallet, spring break…',
          icon: PhIcons.piggyBank,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        const FieldLabel('How much is it?'),
        AmountField(
          controller: _price,
          style: AppText.number,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        if (plan != null)
          Text(
            'Put ${money(plan.perDay, cents: false)} a day aside and you\'ll '
            'have it in ${plan.howLong}.',
            style: AppText.label.copyWith(color: AppColors.text),
          ),
        const SizedBox(height: 18),
        GradientButton(
          label: 'Start saving',
          icon: PhIcons.checkBold,
          onTap: _ready ? _save : null,
        ),
      ],
    );
  }
}

class JarSheet extends StatefulWidget {
  const JarSheet({super.key, required this.jarId});
  final String jarId;

  @override
  State<JarSheet> createState() => _JarSheetState();
}

class _JarSheetState extends State<JarSheet> {
  final _amount = TextEditingController();
  bool _filled = false;

  /// Taking money back out instead of putting it in.
  bool _takingOut = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  double get _value => parseAmountInput(_amount.text);

  void _pick(double amount) {
    HapticFeedback.selectionClick();
    setState(() => _amount.text = amountText(amount));
  }

  void _putIn(SavingsJar jar) {
    AppScope.read(context).putIntoJar(jar.id, _value);
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop();
  }

  void _takeOut(SavingsJar jar) {
    AppScope.read(context).takeOutOfJar(jar.id, _value);
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop();
  }

  void _mode(bool takingOut, double fill) {
    HapticFeedback.selectionClick();
    setState(() {
      _takingOut = takingOut;
      _amount.text = fill > 0 ? amountText(fill) : '';
    });
  }

  /// "Take out" mode: any amount up to what's in the jar.
  List<Widget> _takeOutForm(SavingsJar jar) {
    final saved = jar.saved;
    final tooMuch = _value > saved + 0.005;
    return [
      const FieldLabel('Take out'),
      AmountField(
        controller: _amount,
        style: AppText.number,
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 10),
      Wrap(
        children: [
          ChoiceChipPill(
            selected: _value == saved,
            onTap: () => _pick(saved),
            child: Text('All · ${money(saved)}'),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Text(
        tooMuch
            ? 'There\'s ${money(saved)} in it.'
            : 'It goes back to your spending money. Put in by mistake today? '
                  'Today\'s safe-to-spend gets it all back.',
        style: AppText.label.copyWith(
          color: tooMuch ? AppColors.butter : AppColors.text,
        ),
      ),
      const SizedBox(height: 16),
      GradientButton(
        label: _value > 0 && !tooMuch
            ? 'Take ${money(_value, cents: _value != _value.roundToDouble())} out'
            : 'Take money out',
        icon: PhIcons.arrowUpBold,
        onTap: _value > 0 && !tooMuch ? () => _takeOut(jar) : null,
      ),
      const SizedBox(height: 6),
    ];
  }

  Future<void> _end(SavingsJar jar, {required bool bought}) async {
    final state = AppScope.read(context);
    final navigator = Navigator.of(context);
    final short = jar.target - jar.saved;
    final ok = await showActionSheet<bool>(
      context,
      title: bought ? 'Bought the ${jar.name}?' : 'Stop saving for it?',
      message: bought
          ? 'It\'s logged as ${money(jar.target)} of Shopping, paid with the '
                '${money(jar.saved)} you put aside'
                '${short > 0.005 ? ' and ${money(short)} of spending money' : ''}.'
          : 'The ${money(jar.saved)} you put aside goes back to spending '
                'money.',
      actions: [
        SheetAction(
          value: true,
          label: bought ? 'Yes, I bought it' : 'Stop saving',
          icon: bought ? PhIcons.checkBold : PhIcons.trash,
          destructive: !bought,
        ),
      ],
    );
    if (ok != true) return;
    if (bought) {
      state.buyJar(jar.id);
    } else {
      state.dropJar(jar.id);
    }
    HapticFeedback.mediumImpact();
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final jar = state.jar(widget.jarId);
    if (jar == null) return const SheetFrame(children: []);
    final max = state.maxJarDeposit(jar);
    final suggested = state.suggestedJarDeposit(jar);
    if (!_filled) {
      _filled = true;
      if (suggested > 0) _amount.text = amountText(suggested);
    }
    final tooMuch = _value > max + 0.005;
    final plan = SavingsPlan.forShare(jar.remaining, state.grounding, 0.2);
    final progress = jar.target == 0 ? 0.0 : jar.saved / jar.target;

    return SheetFrame(
      children: [
        Text(jar.name, style: AppText.heading, textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text(
          '${money(jar.saved, cents: jar.saved != jar.saved.roundToDouble())} '
          'of ${money(jar.target, cents: false)} put aside',
          style: AppText.label,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        JarProgressBar(progress: progress),
        const SizedBox(height: 18),
        if (jar.saved > 0) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ChoiceChipPill(
                selected: !_takingOut,
                color: AppColors.lime,
                onTap: () => _mode(false, suggested),
                child: const Text('Put in'),
              ),
              const SizedBox(width: 8),
              ChoiceChipPill(
                selected: _takingOut,
                onTap: () => _mode(true, jar.saved),
                child: const Text('Take out'),
              ),
            ],
          ),
          const SizedBox(height: 14),
        ],
        if (_takingOut && jar.saved > 0)
          ..._takeOutForm(jar)
        else if (jar.full) ...[
          Text(
            'You\'ve saved the whole ${money(jar.target, cents: false)} 🎉',
            style: AppText.body,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
        ] else if (max <= 0)
          Text(
            'There\'s no spending money to put in right now.',
            style: AppText.label.copyWith(color: AppColors.butter),
            textAlign: TextAlign.center,
          )
        else ...[
          const FieldLabel('Put in'),
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
              if (suggested > 0)
                ChoiceChipPill(
                  selected: _value == suggested,
                  color: AppColors.lime,
                  onTap: () => _pick(suggested),
                  child: Text('Today · ${money(suggested, cents: false)}'),
                ),
              if (max > suggested)
                ChoiceChipPill(
                  selected: _value == max,
                  onTap: () => _pick(max),
                  child: Text(
                    max >= jar.remaining
                        ? 'The rest · ${money(max)}'
                        : 'All I can · ${money(max)}',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            tooMuch
                ? 'You can put in up to ${money(max)} right now.'
                : plan == null
                ? 'Your daily budget goes down by what you put in.'
                : 'About ${money(plan.perDay, cents: false)} a day gets you '
                      'there in ${plan.howLong}.',
            style: AppText.label.copyWith(
              color: tooMuch ? AppColors.butter : AppColors.text,
            ),
          ),
          const SizedBox(height: 16),
          GradientButton(
            label: _value > 0 && !tooMuch
                ? 'Put ${money(_value, cents: _value != _value.roundToDouble())} in'
                : 'Put money in',
            icon: PhIcons.piggyBank,
            onTap: _value > 0 && !tooMuch ? () => _putIn(jar) : null,
          ),
          const SizedBox(height: 6),
        ],
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => _end(jar, bought: true),
                child: Text(
                  'I bought it',
                  style: AppText.body.copyWith(
                    color: AppColors.lime,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            Expanded(
              child: TextButton(
                onPressed: () => _end(jar, bought: false),
                child: Text(
                  'Stop saving',
                  style: AppText.body.copyWith(color: AppColors.red),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A slim lime bar for how full a jar is.
class JarProgressBar extends StatelessWidget {
  const JarProgressBar({super.key, required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: LinearProgressIndicator(
        value: progress.clamp(0.0, 1.0),
        minHeight: 10,
        backgroundColor: Colors.white.withValues(alpha: 0.07),
        valueColor: const AlwaysStoppedAnimation(AppColors.lime),
      ),
    );
  }
}
