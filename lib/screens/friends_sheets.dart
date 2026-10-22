import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../app/app_state.dart';
import '../app/format.dart';
import '../app/split_math.dart';
import '../app/squad.dart';
import '../app/theme.dart';
import '../widgets/action_sheet.dart';
import '../widgets/expense_inputs.dart';
import '../widgets/gradient_button.dart';
import '../widgets/ph_icons.dart';
import '../widgets/pressable.dart';
import 'split_bill_sheet.dart';

Future<void> _sheet(BuildContext context, Widget child) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      elevation: 0,
      builder: (_) => child,
    );

Future<void> showAddFriendSheet(BuildContext context) =>
    _sheet(context, const _AddFriendSheet());

Future<void> showFriendSheet(BuildContext context, String friendId) =>
    _sheet(context, _FriendSheet(friendId: friendId));

/// "Priya owes you $18.00", "You owe Sam $5.00" or "All settled up".
String balanceLine(String name, int cents) => cents > 0
    ? '$name owes you ${money(cents / 100)}'
    : cents < 0
    ? 'You owe $name ${money(-cents / 100)}'
    : 'All settled up';

Color balanceColor(int cents) => cents > 0
    ? AppColors.lime
    : cents < 0
    ? AppColors.red
    : AppColors.muted;

/// Your friend code to share, and a field for someone else's.
class _AddFriendSheet extends StatefulWidget {
  const _AddFriendSheet();

  @override
  State<_AddFriendSheet> createState() => _AddFriendSheetState();
}

class _AddFriendSheetState extends State<_AddFriendSheet> {
  final _code = TextEditingController();
  final _shareKey = GlobalKey();
  String? _mine;
  bool _busy = false;
  String? _problem;

  @override
  void initState() {
    super.initState();
    AppScope.read(context).friendCode().then(
      (code) {
        if (mounted) setState(() => _mine = code);
      },
      onError: (Object e) {
        if (mounted) setState(() => _problem = '$e');
      },
    );
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    final code = _mine;
    if (code == null) return;
    final box = _shareKey.currentContext?.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        text:
            'Add me on Runway to split bills: open Squad → Add friend and '
            'enter $code',
        subject: 'Add me on Runway',
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  Future<void> _add() async {
    if (_busy) return;
    if (cleanInviteCode(_code.text).length != 6) {
      setState(() => _problem = 'Friend codes are 6 letters and numbers.');
      return;
    }
    final state = AppScope.read(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      if (await state.addFriend(_code.text)) {
        HapticFeedback.mediumImpact();
        navigator.pop();
        messenger.showSnackBar(
          const SnackBar(content: Text('Friend added. You can split now.')),
        );
        return;
      }
      _problem = 'That code didn\'t work. Ask them for their current one.';
    } on SquadException catch (e) {
      _problem = e.message;
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return SheetFrame(
      children: [
        Text('Add a friend', style: AppText.title, textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text(
          'Friends can split bills with you. They see your first name, '
          'never your budget.',
          style: AppText.label,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 18),
        const FieldLabel('Your friend code'),
        Row(
          children: [
            Expanded(
              child: Text(
                _mine ?? '······',
                style: AppText.number.copyWith(fontSize: 28, letterSpacing: 3),
              ),
            ),
            SizedBox(
              width: 120,
              child: GradientButton(
                key: _shareKey,
                label: 'Share',
                height: 46,
                onTap: _mine == null ? null : _share,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const FieldLabel('Got a friend\'s code?'),
        GlassTextField(
          controller: _code,
          hint: 'K7M2QX',
          icon: PhIcons.at,
          maxLength: 10,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.go,
          onSubmitted: (_) => _add(),
        ),
        if (_problem != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              _problem!,
              style: AppText.label.copyWith(color: AppColors.red),
            ),
          ),
        const SizedBox(height: 14),
        GradientButton(
          label: _busy ? 'Adding…' : 'Add friend',
          gradient: AppGradients.hot,
          glow: AppColors.lilac,
          onTap: _busy ? null : _add,
        ),
      ],
    );
  }
}

/// One friend: the balance, settle up, split with them, and what you've
/// split.
class _FriendSheet extends StatefulWidget {
  const _FriendSheet({required this.friendId});
  final String friendId;

  @override
  State<_FriendSheet> createState() => _FriendSheetState();
}

class _FriendSheetState extends State<_FriendSheet> {
  bool _busy = false;

  Future<void> _settle(int balance, String name) async {
    final state = AppScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final amount = await _askAmount(balance, name);
    if (amount == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await state.settleUpWith(
        widget.friendId,
        amountCents: amount == balance.abs() ? null : amount,
      );
      HapticFeedback.mediumImpact();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            balance > 0
                ? 'Recorded: $name paid you ${money(amount / 100)}.'
                : 'Recorded: you paid $name ${money(amount / 100)}.',
          ),
        ),
      );
    } on SquadException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
    if (mounted) setState(() => _busy = false);
  }

  /// How much was paid, in cents (the whole balance by default).
  Future<int?> _askAmount(int balance, String name) async {
    final controller = TextEditingController(
      text: (balance.abs() / 100).toStringAsFixed(2),
    );
    final cents = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          balance > 0 ? '$name paid you' : 'You paid $name',
          style: AppText.heading,
        ),
        content: GlassTextField(
          controller: controller,
          hint: '0.00',
          prefixText: '\$ ',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          maxLength: 8,
          style: AppText.number,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel', style: AppText.label),
          ),
          TextButton(
            onPressed: () {
              final v = ((double.tryParse(controller.text) ?? 0) * 100).round();
              Navigator.of(context).pop(v > 0 ? v : null);
            },
            child: Text(
              'Record',
              style: AppText.label.copyWith(color: AppColors.lime),
            ),
          ),
        ],
      ),
    );
    controller.dispose();
    return cents?.clamp(1, balance.abs());
  }

  Future<void> _remove(Person person) async {
    final state = AppScope.read(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showActionSheet<bool>(
      context,
      title: 'Remove ${person.name}?',
      message:
          'You won\'t be able to split new bills with them. Old splits and '
          'what you owe each other stay.',
      actions: const [
        SheetAction(
          value: true,
          label: 'Remove friend',
          icon: PhIcons.trash,
          destructive: true,
        ),
      ],
    );
    if (ok != true) return;
    try {
      await state.removeFriend(person.id);
      navigator.pop();
    } on SquadException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _deleteSplit(SharedExpense e) async {
    final state = AppScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showActionSheet<bool>(
      context,
      title: 'Delete "${e.description}"?',
      message: 'It\'s removed for everyone in it, and from your budget.',
      actions: const [
        SheetAction(
          value: true,
          label: 'Delete split',
          icon: PhIcons.trash,
          destructive: true,
        ),
      ],
    );
    if (ok != true) return;
    try {
      await state.deleteSharedExpense(e.id);
    } on SquadException catch (err) {
      messenger.showSnackBar(SnackBar(content: Text(err.message)));
    }
  }

  Future<void> _deleteSettlement(Settlement s, String name) async {
    final state = AppScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showActionSheet<bool>(
      context,
      title: 'Remove this settle-up?',
      message:
          'It\'s removed for you and $name, and what you owe each other goes '
          'back to how it was. Your budget doesn\'t change.',
      actions: const [
        SheetAction(
          value: true,
          label: 'Remove settle-up',
          icon: PhIcons.trash,
          destructive: true,
        ),
      ],
    );
    if (ok != true) return;
    try {
      await state.deleteSettlement(s.id);
    } on SquadException catch (err) {
      messenger.showSnackBar(SnackBar(content: Text(err.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final person = state.person(widget.friendId);
    if (person == null) return const SheetFrame(children: []);
    final me = state.me;
    final balance = state.friendBalances[person.id] ?? 0;
    final activity = state.activityWith(person.id);
    final squads = [
      for (final s in state.squads)
        if (person.squadIds.contains(s.id)) s.name,
    ];

    String who(String id) => id == me ? 'You' : state.person(id)?.name ?? '?';

    return SheetFrame(
      children: [
        Text(person.emoji, style: const TextStyle(fontSize: 40)),
        Text(person.name, style: AppText.title, textAlign: TextAlign.center),
        if (squads.isNotEmpty)
          Text(
            'In ${squads.join(', ')}',
            style: AppText.label,
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: 12),
        Text(
          balanceLine(person.name, balance),
          style: AppText.heading.copyWith(color: balanceColor(balance)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: GradientButton(
                label: _busy ? 'Saving…' : 'Settle up',
                height: 50,
                onTap: balance == 0 || _busy
                    ? null
                    : () => _settle(balance, person.name),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GradientButton(
                label: 'Split',
                height: 50,
                gradient: AppGradients.hot,
                glow: AppColors.lilac,
                onTap: () {
                  Navigator.of(context).pop();
                  showSplitBillSheet(context, withFriend: person.id);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (activity.isEmpty)
          Text(
            'Nothing split yet.',
            style: AppText.label,
            textAlign: TextAlign.center,
          )
        else ...[
          const FieldLabel('History'),
          for (final item in activity)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: switch (item) {
                // Anyone in a split or settle-up can remove it, so nobody is
                // stuck with one they didn't agree to.
                SharedExpense e => Pressable(
                  onLongPress: me != null ? () => _deleteSplit(e) : null,
                  onTap: () {},
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e.description,
                              style: AppText.body.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${who(e.paidBy)} paid '
                              '${money(e.totalCents / 100)} · '
                              '${shortDate(e.createdAt.toLocal())}',
                              style: AppText.label,
                            ),
                          ],
                        ),
                      ),
                      Text(_yourSide(e, me, person.id), style: AppText.label),
                    ],
                  ),
                ),
                Settlement s => Pressable(
                  onLongPress: me != null
                      ? () => _deleteSettlement(s, person.name)
                      : null,
                  onTap: () {},
                  child: Row(
                    children: [
                      const Icon(
                        PhIcons.handCoins,
                        size: 18,
                        color: AppColors.lime,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${who(s.from)} paid ${s.to == me ? 'you' : who(s.to)} '
                          '${money(s.amountCents / 100)}',
                          style: AppText.body,
                        ),
                      ),
                      Text(
                        shortDate(s.createdAt.toLocal()),
                        style: AppText.label,
                      ),
                    ],
                  ),
                ),
                _ => const SizedBox.shrink(),
              },
            ),
          Text(
            'Hold a split or settle-up to remove it.',
            style: AppText.caption.copyWith(letterSpacing: 0),
            textAlign: TextAlign.center,
          ),
        ],
        if (person.direct) ...[
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => _remove(person),
            child: Text(
              'Remove friend',
              style: AppText.label.copyWith(color: AppColors.red),
            ),
          ),
        ],
      ],
    );
  }

  /// What this split means between you two: "+$15.00" they owe you,
  /// "−$15.00" you owe them.
  static String _yourSide(SharedExpense e, String? me, String friend) {
    if (me == null) return '';
    final cents = e.paidBy == me
        ? e.shares[friend] ?? 0
        : e.paidBy == friend
        ? -(e.shares[me] ?? 0)
        : 0;
    if (cents == 0) return '';
    return cents > 0 ? '+${money(cents / 100)}' : '−${money(-cents / 100)}';
  }
}
