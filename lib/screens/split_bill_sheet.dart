import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_state.dart';
import '../app/format.dart';
import '../app/models.dart';
import '../app/split_math.dart';
import '../app/squad.dart';
import '../app/theme.dart';
import '../widgets/expense_inputs.dart';
import '../widgets/gradient_button.dart';
import '../widgets/ph_icons.dart';
import '../widgets/pressable.dart';

Future<void> showSplitBillSheet(
  BuildContext context, {
  String? withFriend,
  String? inSquad,
}) {
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
    builder: (_) => SplitBillSheet(withFriend: withFriend, inSquad: inSquad),
  );
}

/// Someone in the split. [key] is `me`, a friend's account ID, or
/// `n:<name>` for someone not on Runway (their IOU stays on this phone).
typedef _Who = ({String key, String name, String emoji});

const _me = 'me';

/// Splits a bill with friends (synced, so they see it too) and people not
/// on Runway (kept on this phone): who paid, who's in, and how it's split.
/// Your part counts as spending whoever paid.
class SplitBillSheet extends StatefulWidget {
  const SplitBillSheet({super.key, this.withFriend, this.inSquad});

  /// Starts with this friend picked.
  final String? withFriend;

  /// Starts inside this squad, with everyone in it picked.
  final String? inSquad;

  @override
  State<SplitBillSheet> createState() => _SplitBillSheetState();
}

class _SplitBillSheetState extends State<SplitBillSheet> {
  final _description = TextEditingController();
  final _amount = TextEditingController();
  final _newName = TextEditingController();

  /// Per-person inputs for exact amounts, percentages or shares.
  final _inputs = <String, TextEditingController>{};

  late final Set<String> _selected = {?widget.withFriend};
  final _added = <_Who>[];
  String _payer = _me;
  late String? _squadId = widget.inSquad;
  SplitKind _kind = SplitKind.equal;
  CategoryRef _category = const CategoryRef(ExpenseCategory.groceries);
  bool _isNeed = true;
  bool _adding = false;
  bool _busy = false;
  String? _problem;

  @override
  void initState() {
    super.initState();
    if (_squadId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pickSquad(_squadId);
      });
    }
  }

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    _newName.dispose();
    for (final c in _inputs.values) {
      c.dispose();
    }
    super.dispose();
  }

  int get _totalCents => ((double.tryParse(_amount.text) ?? 0) * 100).round();

  /// Friends to pick from: everyone, or a squad's members.
  List<_Who> _friends(AppState state) {
    if (!state.realSquad) {
      return [
        for (final f in state.friends)
          (key: 'n:${f.name}', name: f.name, emoji: f.emoji),
      ];
    }
    final squad = state.squads.where((s) => s.id == _squadId).firstOrNull;
    if (squad != null) {
      return [
        for (final m in squad.members)
          if (!m.isMe) (key: m.userId, name: m.name, emoji: m.emoji),
      ];
    }
    return [
      for (final p in state.friendPeople)
        (key: p.id, name: p.name, emoji: p.emoji),
    ];
  }

  List<_Who> _choices(AppState state) => [
    ..._friends(state),
    if (_payer == _me && _squadId == null) ..._added,
  ];

  /// Everyone in the split, you first.
  List<_Who> _people(AppState state) => [
    (key: _me, name: 'You', emoji: '😎'),
    for (final w in _choices(state))
      if (_selected.contains(w.key)) w,
  ];

  bool _isFriend(String key) => key != _me && !key.startsWith('n:');

  TextEditingController _input(String key) =>
      _inputs.putIfAbsent(key, TextEditingController.new);

  void _toggle(String key) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_selected.remove(key)) _selected.add(key);
      if (_payer == key && !_selected.contains(key)) _payer = _me;
      _problem = null;
    });
  }

  void _pickSquad(String? id) {
    HapticFeedback.selectionClick();
    final state = AppScope.read(context);
    setState(() {
      _squadId = id;
      _selected.clear();
      if (_payer != _me) _payer = _me;
      if (id != null) {
        for (final w in _friends(state)) {
          _selected.add(w.key);
        }
      }
      _problem = null;
    });
  }

  void _addName() {
    final name = _newName.text.trim();
    if (name.isEmpty) {
      setState(() => _adding = false);
      return;
    }
    final key = 'n:$name';
    HapticFeedback.selectionClick();
    setState(() {
      if (!_added.any((w) => w.key == key)) {
        _added.add((key: key, name: name, emoji: '🙂'));
      }
      _selected.add(key);
      _newName.clear();
      _adding = false;
    });
  }

  /// Each person's part in cents, or a reason it doesn't work yet.
  (Map<String, int>?, String?) _shares(AppState state) {
    final people = [for (final p in _people(state)) p.key];
    if (people.length < 2 || _totalCents <= 0) return (null, null);
    try {
      return (
        computeShares(
          totalCents: _totalCents,
          people: people,
          kind: _kind,
          roundingTo: _payer,
          inputs: {
            for (final p in people)
              p: switch (_kind) {
                SplitKind.equal => 1,
                SplitKind.exact =>
                  ((double.tryParse(_input(p).text) ?? 0) * 100).round(),
                _ => double.tryParse(_input(p).text) ?? 0,
              },
          },
        ),
        null,
      );
    } on SplitInputException catch (e) {
      return (null, e.message);
    }
  }

  Future<void> _save() async {
    final state = AppScope.read(context);
    final (shares, problem) = _shares(state);
    final description = _description.text.trim();
    if (description.isEmpty) {
      setState(() => _problem = 'Say what it was.');
      return;
    }
    if (shares == null) {
      setState(() => _problem = problem ?? 'Pick who to split with.');
      return;
    }
    final names = {for (final p in _people(state)) p.key: p.name};
    final friends = [
      for (final k in shares.keys)
        if (_isFriend(k)) k,
    ];
    final locals = {
      for (final e in shares.entries)
        if (e.key.startsWith('n:')) names[e.key]!: e.value / 100,
    };
    final navigator = Navigator.of(context);
    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      if (friends.isNotEmpty) {
        final me = state.me!;
        final synced = {
          me: shares[_me]!,
          for (final f in friends) f: shares[f]!,
        };
        await state.splitWithFriends(
          description: description,
          totalCents: synced.values.fold(0, (a, b) => a + b),
          paidBy: _payer == _me ? me : _payer,
          kind: _kind,
          shares: synced,
          squadId: _squadId,
          category: _category.category,
          custom: _category.custom,
          isNeed: _isNeed,
        );
        state.addLocalIous(description: description, owed: locals);
      } else {
        state.addLocalIous(
          description: description,
          owed: locals,
          myShare: shares[_me]! / 100,
          category: _category.category,
          custom: _category.custom,
          isNeed: _isNeed,
        );
      }
      HapticFeedback.mediumImpact();
      navigator.pop();
    } on SquadException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _problem = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final real = state.realSquad;
    final choices = _choices(state);
    final people = _people(state);
    final (shares, problem) = _shares(state);
    final payerName = _payer == _me
        ? 'You'
        : people.firstWhere((p) => p.key == _payer).name;

    return SheetFrame(
      children: [
        Text('Split a bill', style: AppText.title, textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text(
          real
              ? 'Friends see it in their app; your part counts as spending.'
              : 'You paid — your roommates pay you back',
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
        const FieldLabel('Total'),
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
        if (real && state.squads.isNotEmpty) ...[
          const SizedBox(height: 16),
          const FieldLabel('In a squad?'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChipPill(
                selected: _squadId == null,
                color: AppColors.lilac,
                onTap: () => _pickSquad(null),
                child: const Text('No squad'),
              ),
              for (final s in state.squads)
                ChoiceChipPill(
                  key: ValueKey('squad-${s.id}'),
                  selected: _squadId == s.id,
                  color: AppColors.lilac,
                  onTap: () => _pickSquad(s.id),
                  child: Text(s.name),
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        const FieldLabel('Split with'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final w in choices)
              ChoiceChipPill(
                key: ValueKey(w.key),
                selected: _selected.contains(w.key),
                color: AppColors.lime,
                onTap: () => _toggle(w.key),
                child: Text('${w.emoji} ${w.name}'),
              ),
            if (!_adding && _payer == _me && _squadId == null)
              ChoiceChipPill(
                key: const ValueKey('add'),
                selected: false,
                color: AppColors.lilac,
                onTap: () => setState(() => _adding = true),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(PhIcons.plusBold, size: 14),
                    SizedBox(width: 6),
                    Text('Someone else'),
                  ],
                ),
              ),
          ],
        ),
        if (_adding) ...[
          const SizedBox(height: 10),
          GlassTextField(
            controller: _newName,
            hint: 'Their first name (not on Runway)',
            icon: PhIcons.user,
            maxLength: 30,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _addName(),
            suffix: Pressable(
              onTap: _addName,
              semanticLabel: 'Add',
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(PhIcons.checkBold, size: 20, color: AppColors.lime),
              ),
            ),
          ),
        ],
        if (choices.isEmpty && !_adding)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              real
                  ? 'Add friends or start a squad to split with them. Someone '
                        'not on Runway? Add them by name.'
                  : 'Add someone by name; they don\'t need the app.',
              style: AppText.label,
            ),
          ),
        if (real && people.any((p) => _isFriend(p.key))) ...[
          const SizedBox(height: 16),
          const FieldLabel('Who paid?'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in people)
                if (p.key == _me || _isFriend(p.key))
                  ChoiceChipPill(
                    key: ValueKey('payer-${p.key}'),
                    selected: _payer == p.key,
                    color: AppColors.butter,
                    onTap: () => setState(() {
                      _payer = p.key;
                      if (p.key != _me) {
                        _selected.removeWhere((k) => k.startsWith('n:'));
                      }
                    }),
                    child: Text(p.key == _me ? 'You' : p.name),
                  ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        const FieldLabel('How to split'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final k in SplitKind.values)
              ChoiceChipPill(
                key: ValueKey('kind-${k.name}'),
                selected: _kind == k,
                color: AppColors.lilac,
                onTap: () => setState(() => _kind = k),
                child: Text(k.label),
              ),
          ],
        ),
        if (_kind != SplitKind.equal && people.length > 1) ...[
          const SizedBox(height: 10),
          for (final p in people)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${p.emoji} ${p.name}',
                      style: AppText.body,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(
                    width: 130,
                    child: GlassTextField(
                      key: ValueKey('input-${p.key}'),
                      controller: _input(p.key),
                      hint: switch (_kind) {
                        SplitKind.exact => '0.00',
                        SplitKind.percent => '%',
                        _ => 'shares',
                      },
                      prefixText: _kind == SplitKind.exact ? '\$ ' : null,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      maxLength: 8,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
            ),
        ],
        const SizedBox(height: 16),
        const FieldLabel('Category (for your part)'),
        CategoryPicker(
          selected: _category,
          customs: state.customCategories,
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
          child: shares == null
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: (_problem ?? problem) == null
                        ? null
                        : Text(
                            (_problem ?? problem)!,
                            style: AppText.label.copyWith(color: AppColors.red),
                          ),
                  ),
                )
              : _Preview(
                  lines: [
                    for (final p in people)
                      if (p.key != _payer && shares[p.key]! > 0)
                        (
                          p.key == _me
                              ? 'You owe $payerName'
                              : _payer == _me
                              ? '${p.name} owes you'
                              : '${p.name} owes $payerName',
                          shares[p.key]! / 100,
                        ),
                  ],
                  mine: shares[_me]! / 100,
                  problem: _problem,
                ),
        ),
        const SizedBox(height: 8),
        GradientButton(
          label: _busy
              ? 'Splitting…'
              : _totalCents > 0
              ? 'Split ${money(_totalCents / 100)}'
              : 'Split bill',
          onTap: _busy || shares == null ? null : _save,
        ),
      ],
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.lines, required this.mine, this.problem});
  final List<(String, double)> lines;
  final double mine;
  final String? problem;

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
          for (final (label, amount) in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(child: Text(label, style: AppText.body)),
                  Text(
                    money(amount),
                    style: AppText.number.copyWith(
                      fontSize: 16,
                      color: label.startsWith('You owe')
                          ? AppColors.red
                          : AppColors.lime,
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Your part (counts as spending)',
                  style: AppText.label,
                ),
              ),
              Text(money(mine), style: AppText.number.copyWith(fontSize: 16)),
            ],
          ),
          if (problem != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                problem!,
                style: AppText.label.copyWith(color: AppColors.red),
              ),
            ),
        ],
      ),
    );
  }
}
