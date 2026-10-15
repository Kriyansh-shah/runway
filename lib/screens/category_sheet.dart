import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_state.dart';
import '../app/models.dart';
import '../app/theme.dart';
import '../widgets/action_sheet.dart';
import '../widgets/expense_inputs.dart';
import '../widgets/gradient_button.dart';
import '../widgets/ph_icons.dart';

/// Makes a category of the person's own, or changes [editing]. [name]
/// pre-fills a new one. Returns the saved category, or null if dismissed.
Future<CustomCategory?> showCategorySheet(
  BuildContext context, {
  CustomCategory? editing,
  String? name,
}) {
  return showModalBottomSheet<CustomCategory>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    elevation: 0,
    builder: (_) => CategorySheet(editing: editing, name: name),
  );
}

enum _CategoryAction { edit, delete }

/// Rename or delete one of the person's own categories. Returns true if it
/// was deleted.
Future<bool> showCustomCategoryActions(
  BuildContext context,
  CustomCategory category,
) async {
  final state = AppScope.read(context);
  final choice = await showActionSheet<_CategoryAction>(
    context,
    title: '${category.emoji} ${category.name}',
    message:
        'Deleting it keeps its expenses. They move to Other, '
        'with "${category.name}" as their note.',
    actions: const [
      SheetAction(
        value: _CategoryAction.edit,
        label: 'Rename',
        icon: PhIcons.notePencil,
      ),
      SheetAction(
        value: _CategoryAction.delete,
        label: 'Delete category',
        icon: PhIcons.trash,
        destructive: true,
      ),
    ],
  );
  if (!context.mounted) return false;
  switch (choice) {
    case _CategoryAction.edit:
      await showCategorySheet(context, editing: category);
      return false;
    case _CategoryAction.delete:
      state.deleteCustomCategory(category.id);
      return true;
    case null:
      return false;
  }
}

class CategorySheet extends StatefulWidget {
  const CategorySheet({super.key, this.editing, this.name});

  final CustomCategory? editing;
  final String? name;

  @override
  State<CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<CategorySheet> {
  /// Quick choices; any other emoji can be typed in the last field.
  static const _emojis = [
    '🏷️', '🚬', '🍺', '🧋', '🎮', '💅', '🐶', '🏋️', //
    '🎬', '💊', '🎵', '📱', '👕', '🎁', '⛽', '🍿',
  ];

  late final _name = TextEditingController(
    text: widget.editing?.name ?? widget.name ?? '',
  );
  final _ownEmoji = TextEditingController();
  late String _emoji = widget.editing?.emoji ?? _emojis.first;

  @override
  void initState() {
    super.initState();
    if (!_emojis.contains(_emoji)) _ownEmoji.text = _emoji;
  }

  @override
  void dispose() {
    _name.dispose();
    _ownEmoji.dispose();
    super.dispose();
  }

  String? get _problem =>
      AppScope.read(context)
          .checkCategoryName(_name.text, editingId: widget.editing?.id);

  void _typedEmoji(String text) {
    final typed = text.characters;
    if (typed.isEmpty) return;
    // Keep only the newest one, so typing another replaces it.
    final last = typed.last;
    if (_ownEmoji.text != last) {
      _ownEmoji.value = TextEditingValue(
        text: last,
        selection: TextSelection.collapsed(offset: last.length),
      );
    }
    setState(() => _emoji = last);
  }

  void _save() {
    if (_problem != null) return;
    final state = AppScope.read(context);
    final CustomCategory saved;
    if (widget.editing case final editing?) {
      saved = editing.copyWith(name: _name.text.trim(), emoji: _emoji);
      state.updateCustomCategory(saved);
    } else {
      saved = state.addCustomCategory(name: _name.text, emoji: _emoji);
    }
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(saved);
  }

  @override
  Widget build(BuildContext context) {
    final problem = _problem;
    final typedSomething = _name.text.trim().isNotEmpty;
    return SheetFrame(
      children: [
        Text(
          widget.editing == null ? 'New category' : 'Edit category',
          style: AppText.heading,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'It stays in your list, one tap away next time.',
          style: AppText.label,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        const FieldLabel('Name'),
        GlassTextField(
          controller: _name,
          hint: 'e.g. Cigarettes',
          icon: PhIcons.notePencil,
          maxLength: AppState.maxCategoryName,
          onChanged: (_) => setState(() {}),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _save(),
        ),
        if (typedSomething && problem != null) ...[
          const SizedBox(height: 6),
          Text(problem, style: AppText.label.copyWith(color: AppColors.butter)),
        ],
        const SizedBox(height: 14),
        const FieldLabel('Emoji'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in _emojis)
              ChoiceChipPill(
                selected: e == _emoji,
                onTap: () {
                  HapticFeedback.selectionClick();
                  _ownEmoji.clear();
                  setState(() => _emoji = e);
                },
                child: Text(e, style: const TextStyle(fontSize: 24, height: 1)),
              ),
            SizedBox(
              width: 96,
              child: GlassTextField(
                controller: _ownEmoji,
                hint: 'Your own',
                maxLength: 4,
                textCapitalization: TextCapitalization.none,
                onChanged: _typedEmoji,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        GradientButton(
          label: problem == null
              ? '${widget.editing == null ? 'Add' : 'Save'} '
                    '$_emoji ${_name.text.trim()}'
              : (widget.editing == null ? 'Add category' : 'Save'),
          icon: PhIcons.checkBold,
          onTap: problem == null ? _save : null,
        ),
      ],
    );
  }
}
