import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../app/app_state.dart';
import '../app/format.dart';
import '../app/models.dart';
import '../app/purchase_link.dart';
import '../app/spoken_expense.dart';
import '../app/theme.dart';
import '../widgets/category_icon.dart';
import '../widgets/expense_inputs.dart';
import '../widgets/form_fields.dart';
import '../widgets/gradient_button.dart';
import '../widgets/pressable.dart';
import '../widgets/ph_icons.dart';
import 'category_sheet.dart';

/// Returns where the Log button was (global), so the caller can fly a coin
/// from it; null if the sheet was dismissed or an expense was edited.
/// [purchase] pre-fills the sheet from an Apple Pay automation; [editing]
/// opens an existing expense to change it; [listen] starts the mic right
/// away.
Future<Offset?> showQuickAddSheet(
  BuildContext context, {
  ApplePayPurchase? purchase,
  Expense? editing,
  bool listen = false,
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
    builder: (_) =>
        QuickAddSheet(purchase: purchase, editing: editing, listen: listen),
  );
}

class QuickAddSheet extends StatefulWidget {
  const QuickAddSheet({
    super.key,
    this.purchase,
    this.editing,
    this.listen = false,
  });

  /// Set when the sheet opens from an Apple Pay purchase.
  final ApplePayPurchase? purchase;

  /// Set when changing an expense that's already logged.
  final Expense? editing;

  /// Start listening as soon as the sheet opens ("Log by voice").
  final bool listen;

  @override
  State<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<QuickAddSheet> {
  String _input = '';
  CategoryRef _category = const CategoryRef(ExpenseCategory.other);
  bool _isNeed = false;
  final _note = TextEditingController();
  final _speech = SpeechToText();
  bool _listening = false;

  /// What the mic has heard so far, or why it can't listen.
  String? _heard;

  @override
  void initState() {
    super.initState();
    if (widget.listen) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _toggleMic());
    }
    if (widget.editing case final e?) {
      _input = amountText(e.amount);
      _note.text = e.note ?? '';
      _category = e.filedUnder;
      _isNeed = e.isNeed;
      return;
    }
    final purchase = widget.purchase;
    if (purchase == null) return;
    if (purchase.amount case final amount?) _input = amountText(amount);
    _note.text = purchase.merchant ?? '';
  }

  @override
  void dispose() {
    unawaited(_speech.cancel());
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
      _input = amountText(p.amount);
      _category = CategoryRef(p.category);
      _isNeed = p.isNeed;
    });
  }

  bool get _inPlainOther =>
      _category.category == ExpenseCategory.other && _category.custom == null;

  void _noteChanged(String note) {
    // Typing the name of a category you made picks it for you.
    if (_inPlainOther) {
      final key = note.trim().toLowerCase();
      for (final c in AppScope.read(context).customCategories) {
        if (c.name.toLowerCase() == key) {
          HapticFeedback.selectionClick();
          _category = CategoryRef(ExpenseCategory.other, c);
          break;
        }
      }
    }
    setState(() {});
  }

  Future<void> _newCategory({String? name}) async {
    final made = await showCategorySheet(context, name: name);
    if (made == null || !mounted) return;
    setState(() => _category = CategoryRef(ExpenseCategory.other, made));
  }

  Future<void> _holdCategory(CustomCategory c) async {
    final deleted = await showCustomCategoryActions(context, c);
    if (!mounted) return;
    setState(() {
      if (deleted && _category.custom?.id == c.id) {
        _category = const CategoryRef(ExpenseCategory.other);
      } else if (_category.custom?.id == c.id) {
        // Pick up a new name or emoji.
        final now = AppScope.read(context).customCategories
            .where((x) => x.id == c.id)
            .firstOrNull;
        _category = CategoryRef(ExpenseCategory.other, now);
      }
    });
  }

  Future<void> _toggleMic() async {
    if (_listening) {
      await _speech.stop();
      return;
    }
    final ready = await _speech.initialize(
      onStatus: (status) {
        if (!mounted) return;
        if (status == SpeechToText.doneStatus ||
            status == SpeechToText.notListeningStatus) {
          setState(() => _listening = false);
        }
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _listening = false;
          _heard =
              error.errorMsg.contains('no_match') ||
                  error.errorMsg.contains('speech_timeout')
              ? 'Didn\'t catch that. Tap the mic and try again.'
              : 'The mic stopped. Tap it to try again.';
        });
      },
    );
    if (!mounted) return;
    if (!ready) {
      setState(
        () => _heard =
            'Voice isn\'t available. Allow the microphone and speech '
            'recognition for Runway in Settings.',
      );
      return;
    }
    HapticFeedback.lightImpact();
    setState(() {
      _listening = true;
      _heard = null;
    });
    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        setState(() => _heard = result.recognizedWords);
        if (result.finalResult) _useSpoken(result.recognizedWords);
      },
      listenOptions: SpeechListenOptions(
        listenFor: const Duration(seconds: 20),
        pauseFor: const Duration(seconds: 3),
      ),
    );
  }

  /// Fills the sheet from "12 dollars at Chipotle". A category you already
  /// picked stays; otherwise one is guessed from what it was.
  void _useSpoken(String said) {
    final spoken = SpokenExpense.parse(said);
    if (spoken.amount == null && spoken.note == null) return;
    HapticFeedback.mediumImpact();
    setState(() {
      if (spoken.amount case final amount?) _input = amountText(amount);
      if (spoken.note case final note?) _note.text = note;
      if (_inPlainOther) {
        final guess = SpokenExpense.guessCategory(
          spoken.note,
          AppScope.read(context).customCategories,
        );
        if (guess != null) {
          _category = guess;
          _isNeed = SpokenExpense.isNeed(guess.category);
        }
      }
    });
  }

  final _logKey = GlobalKey();

  void _save() {
    if (_amount <= 0) return;
    final note = _note.text.trim();
    if (widget.editing case final e?) {
      AppScope.read(context).updateExpense(
        e.copyWith(
          amount: _amount,
          category: _category.category,
          isNeed: _isNeed,
          note: () => note.isEmpty ? null : note,
          custom: () => _category.custom,
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
      category: _category.category,
      isNeed: _isNeed,
      note: note.isEmpty ? null : note,
      custom: _category.custom,
    );
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(from);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final suggestion = _inPlainOther
        ? state.categorySuggestion(_note.text)
        : null;
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
          onChanged: _noteChanged,
          suffix: _MicButton(listening: _listening, onTap: _toggleMic),
        ),
        if (_listening || _heard != null) ...[
          const SizedBox(height: 8),
          Text(
            _listening && (_heard ?? '').isEmpty
                ? 'Listening… try "12 dollars at Chipotle"'
                : '"${_heard ?? ''}"',
            style: AppText.label.copyWith(
              color: _listening ? AppColors.lime : AppColors.muted,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        if (suggestion != null) ...[
          const SizedBox(height: 8),
          _SuggestCategory(
            name: suggestion,
            onTap: () => _newCategory(name: suggestion),
          ),
        ],
        const SizedBox(height: 16),
        const FieldLabel('Quick picks'),
        _Presets(selected: _category, onTap: _preset),
        const SizedBox(height: 14),
        const FieldLabel('Category'),
        CategoryPicker(
          selected: _category,
          customs: state.customCategories,
          onChanged: (c) => setState(() => _category = c),
          onNew: _newCategory,
          onHoldCustom: _holdCategory,
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

/// Tap to say the expense instead of typing it; glows while listening.
class _MicButton extends StatelessWidget {
  const _MicButton({required this.listening, required this.onTap});
  final bool listening;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.9,
      semanticLabel: listening ? 'Stop listening' : 'Say the expense',
      child: AnimatedContainer(
        duration: Motion.fast,
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: listening
              ? AppColors.lime.withValues(alpha: 0.18)
              : Colors.transparent,
        ),
        child: Icon(
          PhIcons.microphone,
          size: 20,
          color: listening ? AppColors.lime : AppColors.muted,
        ),
      ),
    );
  }
}

/// "Logged Cigarettes before? Make it a category" under the note.
class _SuggestCategory extends StatelessWidget {
  const _SuggestCategory({required this.name, required this.onTap});
  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      semanticLabel: 'Make $name a category',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.lime.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.lime.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'You\'ve logged "$name" before. Make it a category?',
                style: AppText.label.copyWith(color: AppColors.text),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Make it',
              style: AppText.label.copyWith(
                color: AppColors.lime,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Presets extends StatelessWidget {
  const _Presets({required this.selected, required this.onTap});
  final CategoryRef selected;
  final ValueChanged<ExpensePreset> onTap;

  @override
  Widget build(BuildContext context) {
    return ChipRow(
      children: [
        for (final p in ExpensePreset.all)
          ChoiceChipPill(
            selected: selected == CategoryRef(p.category),
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
