/// Keeping Squad safe: remove someone from your squad, report someone (or a
/// squad's name) for review, block someone, and unblock them from Settings.
library;

import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../app/squad.dart';
import '../app/theme.dart';
import '../widgets/action_sheet.dart';
import '../widgets/expense_inputs.dart';
import '../widgets/ph_icons.dart';

enum _PersonAction { remove, report, block }

/// What you can do about someone in the squad on screen or a friend:
/// remove them (if you own the squad), report them, or block them.
Future<void> showPersonActions(
  BuildContext context, {
  required String personId,
  required String name,
  bool inSquad = false,
  VoidCallback? onGone,
}) async {
  final state = AppScope.read(context);
  final squad = state.squad;
  final canRemove = inSquad && squad != null && state.ownsSquad;
  final action = await showActionSheet<_PersonAction>(
    context,
    title: name,
    actions: [
      if (canRemove)
        SheetAction(
          value: _PersonAction.remove,
          label: 'Remove from ${squad.name}',
          icon: PhIcons.userMinus,
          destructive: true,
        ),
      const SheetAction(
        value: _PersonAction.report,
        label: 'Report',
        icon: PhIcons.flag,
      ),
      SheetAction(
        value: _PersonAction.block,
        label: 'Block $name',
        icon: PhIcons.prohibit,
        destructive: true,
      ),
    ],
  );
  if (action == null || !context.mounted) return;
  switch (action) {
    case _PersonAction.remove:
      await _removeFromSquad(context, personId, name);
    case _PersonAction.report:
      await reportPerson(context, personId: personId, name: name);
    case _PersonAction.block:
      if (await blockPerson(context, personId: personId, name: name)) {
        onGone?.call();
      }
  }
}

Future<void> _removeFromSquad(
  BuildContext context,
  String personId,
  String name,
) async {
  final state = AppScope.read(context);
  final messenger = ScaffoldMessenger.of(context);
  final squadName = state.squad?.name ?? 'the squad';
  final ok = await showActionSheet<bool>(
    context,
    title: 'Remove $name from $squadName?',
    message:
        'They can\'t rejoin with an invite code. Splits you already share '
        'stay.',
    actions: const [
      SheetAction(
        value: true,
        label: 'Remove',
        icon: PhIcons.userMinus,
        destructive: true,
      ),
    ],
  );
  if (ok != true) return;
  try {
    await state.removeFromSquad(personId);
    messenger.showSnackBar(
      SnackBar(content: Text('$name was removed from $squadName.')),
    );
  } on SquadException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  }
}

/// Asks before blocking [name]. True when they were blocked.
Future<bool> blockPerson(
  BuildContext context, {
  required String personId,
  required String name,
}) async {
  final state = AppScope.read(context);
  final messenger = ScaffoldMessenger.of(context);
  final ok = await showActionSheet<bool>(
    context,
    title: 'Block $name?',
    message:
        'You won\'t see each other in squads or friends, and you can\'t '
        'split bills or add each other. They aren\'t told. You can unblock '
        'them in Settings.',
    actions: [
      SheetAction(
        value: true,
        label: 'Block $name',
        icon: PhIcons.prohibit,
        destructive: true,
      ),
    ],
  );
  if (ok != true) return false;
  try {
    await state.block(personId);
    messenger.showSnackBar(SnackBar(content: Text('$name is blocked.')));
    return true;
  } on SquadException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
    return false;
  }
}

/// Picks a reason and reports [name], then offers to block them too.
Future<void> reportPerson(
  BuildContext context, {
  required String personId,
  required String name,
}) async {
  final state = AppScope.read(context);
  final messenger = ScaffoldMessenger.of(context);
  final reason = await showActionSheet<ReportReason>(
    context,
    title: 'Report $name',
    message: 'What\'s wrong? They aren\'t told who reported them.',
    actions: [
      for (final r in ReportReason.values)
        if (r != ReportReason.squadName)
          SheetAction(value: r, label: r.label, icon: PhIcons.flag),
    ],
  );
  if (reason == null) return;
  try {
    await state.report(personId: personId, reason: reason);
  } on SquadException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
    return;
  }
  if (!context.mounted) return;
  final block = await showActionSheet<bool>(
    context,
    title: 'Thanks for telling us',
    message:
        'We\'ll look into it. Want to block $name too, so you don\'t see '
        'each other?',
    actions: [
      SheetAction(
        value: true,
        label: 'Block $name',
        icon: PhIcons.prohibit,
        destructive: true,
      ),
      const SheetAction(value: false, label: 'Not now', icon: PhIcons.xBold),
    ],
  );
  if (block != true) return;
  try {
    await state.block(personId);
    messenger.showSnackBar(SnackBar(content: Text('$name is blocked.')));
  } on SquadException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  }
}

/// Reports the name of the squad on screen.
Future<void> reportSquadName(BuildContext context) async {
  final state = AppScope.read(context);
  final messenger = ScaffoldMessenger.of(context);
  final squad = state.squad;
  if (squad == null) return;
  final ok = await showActionSheet<bool>(
    context,
    title: 'Report the name "${squad.name}"?',
    message:
        'We\'ll review it. Nobody in the squad is told who reported it. '
        'To report a person, tap them in the leaderboard.',
    actions: const [
      SheetAction(value: true, label: 'Report squad name', icon: PhIcons.flag),
    ],
  );
  if (ok != true) return;
  try {
    await state.report(squadId: squad.id, reason: ReportReason.squadName);
    messenger.showSnackBar(
      const SnackBar(content: Text('Thanks. We\'ll look into it.')),
    );
  } on SquadException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  }
}

/// The people you've blocked, each with an Unblock button.
Future<void> showBlockedPeople(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    elevation: 0,
    builder: (_) => const _BlockedPeopleSheet(),
  );
}

class _BlockedPeopleSheet extends StatefulWidget {
  const _BlockedPeopleSheet();

  @override
  State<_BlockedPeopleSheet> createState() => _BlockedPeopleSheetState();
}

class _BlockedPeopleSheetState extends State<_BlockedPeopleSheet> {
  List<Person>? _people;
  String? _error;
  final _busy = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final people = await AppScope.read(context).blockedPeople();
      if (mounted) setState(() => _people = people);
    } on SquadException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _unblock(Person p) async {
    final state = AppScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy.add(p.id));
    try {
      await state.unblock(p.id);
      if (mounted) setState(() => _people?.removeWhere((x) => x.id == p.id));
    } on SquadException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy.remove(p.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final people = _people;
    return SheetFrame(
      children: [
        Text(
          'Blocked people',
          style: AppText.heading,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          'Unblocking lets you find each other again. You\'d still need a '
          'new invite or friend code.',
          style: AppText.label,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        if (_error != null)
          Text(_error!, style: AppText.label, textAlign: TextAlign.center)
        else if (people == null)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(color: AppColors.lime),
            ),
          )
        else if (people.isEmpty)
          Text(
            'You haven\'t blocked anyone.',
            style: AppText.body.copyWith(color: AppColors.muted),
            textAlign: TextAlign.center,
          )
        else
          for (final p in people)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Text(p.emoji, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(p.name, style: AppText.body)),
                  TextButton(
                    onPressed: _busy.contains(p.id) ? null : () => _unblock(p),
                    child: Text(
                      'Unblock',
                      style: AppText.label.copyWith(color: AppColors.lime),
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}
