import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/models.dart';
import '../app/theme.dart';
import 'category_icon.dart';
import 'glass.dart';
import 'ph_icons.dart';
import 'pressable.dart';

/// Frosted bottom-sheet frame with a grab handle. Lifts its content above
/// the software keyboard.
class SheetFrame extends StatelessWidget {
  const SheetFrame({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.paddingOf(context).bottom;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: Motion.fast,
      curve: Motion.out,
      padding: EdgeInsets.only(bottom: keyboard),
      child: FrostedGlass(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        sigma: 30,
        tint: AppColors.surface.withValues(alpha: 0.78),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            10,
            20,
            (keyboard > 0 ? 0 : safe) + 16,
          ),
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
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

/// Small uppercase label above a group of inputs.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(text.toUpperCase(), style: AppText.caption),
    );
  }
}

/// Glassy single-line text input.
class GlassTextField extends StatelessWidget {
  const GlassTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.icon,
    this.prefixText,
    this.keyboardType,
    this.inputFormatters,
    this.maxLength = 40,
    this.style,
    this.onChanged,
    this.textAlign = TextAlign.start,
    this.obscureText = false,
    this.suffix,
    this.textInputAction,
    this.onSubmitted,
    this.autofillHints,
    this.textCapitalization = TextCapitalization.sentences,
  });

  final TextEditingController controller;
  final String hint;
  final IconData? icon;
  final String? prefixText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLength;
  final TextStyle? style;
  final ValueChanged<String>? onChanged;
  final TextAlign textAlign;
  final bool obscureText;
  final Widget? suffix;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    final textStyle = style ?? AppText.body;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: AppColors.muted),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: textStyle,
              textAlign: textAlign,
              keyboardType: keyboardType,
              inputFormatters: [
                LengthLimitingTextInputFormatter(maxLength),
                ...?inputFormatters,
              ],
              textCapitalization: textCapitalization,
              obscureText: obscureText,
              textInputAction: textInputAction,
              onSubmitted: onSubmitted,
              autofillHints: autofillHints,
              autocorrect: !obscureText,
              enableSuggestions: !obscureText,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: textStyle.copyWith(color: AppColors.muted),
                prefixText: prefixText,
                prefixStyle: textStyle.copyWith(color: AppColors.muted),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          ?suffix,
        ],
      ),
    );
  }
}

/// A selectable rounded chip used for presets, categories and people.
class ChoiceChipPill extends StatelessWidget {
  const ChoiceChipPill({
    super.key,
    required this.selected,
    required this.onTap,
    required this.child,
    this.color = AppColors.lilac,
    this.onLongPress,
  });

  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      onLongPress: onLongPress,
      haptic: false,
      child: AnimatedContainer(
        duration: Motion.fast,
        curve: Motion.out,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: selected
              ? color.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.06),
          border: Border.all(
            color: selected ? color.withValues(alpha: 0.8) : AppColors.hairline,
          ),
          boxShadow: selected
              ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 12)]
              : null,
        ),
        child: DefaultTextStyle.merge(
          style: AppText.body.copyWith(fontSize: 14),
          child: child,
        ),
      ),
    );
  }
}

/// Horizontally scrolling row of chips that bleeds to the sheet edges.
class ChipRow extends StatelessWidget {
  const ChipRow({super.key, required this.children, this.height = 42});
  final List<Widget> children;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: EdgeInsets.zero,
        itemCount: children.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => Center(child: children[i]),
      ),
    );
  }
}

/// Every category, one tap each: a "New" chip, the person's own
/// categories (most recently used first), then the built-in ones.
class CategoryPicker extends StatelessWidget {
  const CategoryPicker({
    super.key,
    required this.selected,
    required this.onChanged,
    this.customs = const [],
    this.onNew,
    this.onHoldCustom,
  });

  final CategoryRef selected;
  final ValueChanged<CategoryRef> onChanged;
  final List<CustomCategory> customs;

  /// Makes a new category; no "New" chip when null.
  final VoidCallback? onNew;

  /// Long-press on one of the person's own categories (rename, delete).
  final ValueChanged<CustomCategory>? onHoldCustom;

  @override
  Widget build(BuildContext context) {
    Widget chip(CategoryRef ref, {VoidCallback? onLongPress}) => ChoiceChipPill(
      key: ValueKey(ref.custom?.id ?? ref.category),
      selected: ref == selected,
      onTap: () {
        HapticFeedback.selectionClick();
        onChanged(ref);
      },
      onLongPress: onLongPress,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CategoryIcon(ref.category, custom: ref.custom, size: 17),
          const SizedBox(width: 6),
          Text(ref.label),
        ],
      ),
    );
    return ChipRow(
      children: [
        if (onNew case final onNew?)
          ChoiceChipPill(
            key: const ValueKey('new'),
            selected: false,
            color: AppColors.lime,
            onTap: onNew,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(PhIcons.plusBold, size: 15),
                SizedBox(width: 6),
                Text('New'),
              ],
            ),
          ),
        for (final c in customs)
          chip(
            CategoryRef(ExpenseCategory.other, c),
            onLongPress: onHoldCustom == null
                ? null
                : () {
                    HapticFeedback.mediumImpact();
                    onHoldCustom!(c);
                  },
          ),
        for (final c in ExpenseCategory.values) chip(CategoryRef(c)),
      ],
    );
  }
}

/// Segmented need/want toggle with a sliding pill.
class NeedWantToggle extends StatelessWidget {
  const NeedWantToggle({
    super.key,
    required this.isNeed,
    required this.onChanged,
  });

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
                    onTap: () {
                      if (need == isNeed) return;
                      HapticFeedback.selectionClick();
                      onChanged(need);
                    },
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
