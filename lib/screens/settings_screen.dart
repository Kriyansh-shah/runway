import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_state.dart';
import '../app/auth.dart';
import '../app/device_auth.dart';
import '../app/format.dart';
import '../app/models.dart';
import '../app/theme.dart';
import '../widgets/action_sheet.dart';
import '../widgets/aurora_background.dart';
import '../widgets/expense_inputs.dart';
import '../widgets/form_fields.dart';
import '../widgets/glass.dart';
import '../widgets/gradient_button.dart';
import '../widgets/ph_icons.dart';
import '../widgets/pressable.dart';
import '../widgets/transitions.dart';
import 'welcome_screen.dart';
import 'history_screen.dart';
import 'money_actions.dart';
import 'setup_screen.dart';
import 'sync_sheets.dart';

/// Account, the current semester, big costs, and your data.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  /// "Semester" for semesters; a monthly budget moves on by itself, so
  /// starting over there means a new budget of either kind.
  static String _newWhat(Term term) =>
      term.period == BudgetPeriod.monthly ? 'budget' : 'semester';

  Future<void> _newSemester(BuildContext context) async {
    final navigator = Navigator.of(context);
    final what = _newWhat(AppScope.read(context).term);
    final ok = await showActionSheet<bool>(
      context,
      title: 'Start a new $what?',
      message:
          'You\'ll set up the new $what next. This one is archived only once '
          'you finish, and its history stays on your phone. Repeating bills '
          'stop; add them again during setup.',
      actions: [
        SheetAction(
          value: true,
          label: 'Set up a new $what',
          icon: PhIcons.arrowRightBold,
        ),
      ],
    );
    if (ok != true) return;
    await navigator.pushAndRemoveUntil(
      FadeScaleRoute<void>(
        builder: (_) => const SetupScreen(cancellable: true),
      ),
      (_) => false,
    );
  }

  Future<void> _erase(BuildContext context) async {
    final state = AppScope.read(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showActionSheet<bool>(
      context,
      title: 'Erase everything?',
      message:
          'Every semester, expense, payment and split on this phone is '
          'deleted for good, and you\'re signed out. This can\'t be undone.',
      actions: const [
        SheetAction(
          value: true,
          label: 'Erase everything',
          icon: PhIcons.trash,
          destructive: true,
        ),
      ],
    );
    if (ok != true) return;
    HapticFeedback.heavyImpact();
    try {
      await state.eraseEverything();
    } on Object catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'runway storage',
          context: ErrorDescription('while erasing all data'),
        ),
      );
      messenger.showSnackBar(
        const SnackBar(content: Text('Couldn\'t erase your data. Try again.')),
      );
      return;
    }
    await navigator.pushAndRemoveUntil(
      FadeScaleRoute<void>(builder: (_) => const WelcomeScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final user = state.user;
    final today = state.today;
    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  Row(
                    children: [
                      Pressable(
                        onTap: () => Navigator.of(context).maybePop(),
                        semanticLabel: 'Back',
                        child: const Padding(
                          padding: EdgeInsets.all(10),
                          child: Icon(PhIcons.caretLeftBold, size: 22),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text('Settings', style: AppText.title),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (user != null)
                    _ProfileEditor(
                      key: ObjectKey(user),
                      name: user.name,
                      signedIn: state.account != null,
                    ),
                  if (state.account != null || state.accounts.canUseGoogle) ...[
                    const SectionHeader('Account'),
                    const _AccountCard(),
                  ],
                  const SectionHeader('Security'),
                  const _AppLockCard(),
                  SectionHeader(
                    state.term.period == BudgetPeriod.monthly
                        ? 'This month'
                        : 'Semester',
                  ),
                  // Re-created when the term changes elsewhere, so the
                  // fields always start from what's saved.
                  _TermEditor(key: ObjectKey(state.term), term: state.term),
                  const SectionHeader('Big costs'),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final c in state.comingUp)
                          Pressable(
                            onTap: () => showCostActions(context, c),
                            scale: 0.98,
                            semanticLabel:
                                '${c.name}, ${money(c.amount)}, due ${shortDate(c.dueDate)}',
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${c.emoji} ${c.name} · ${shortDate(c.dueDate)}'
                                      '${c.repeats ? ' · monthly' : ''}',
                                      style: AppText.body,
                                    ),
                                  ),
                                  Text(
                                    money(c.amount),
                                    style: AppText.number.copyWith(
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(
                                    PhIcons.caretRight,
                                    size: 16,
                                    color: AppColors.muted,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        AddCostForm(
                          firstDate: today,
                          lastDate: state.term.end.isAfter(today)
                              ? state.term.end
                              : today,
                          onAdd: state.addUpcomingCost,
                        ),
                      ],
                    ),
                  ),
                  const SectionHeader('Your data'),
                  GlassCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: Column(
                      children: [
                        _LinkRow(
                          icon: PhIcons.clockCounterClockwise,
                          label: 'History',
                          onTap: () => Navigator.of(context).push(
                            FadeScaleRoute<void>(
                              builder: (_) => const HistoryScreen(),
                            ),
                          ),
                        ),
                        Divider(height: 1, color: AppColors.hairline),
                        _LinkRow(
                          icon: PhIcons.calendarBlank,
                          label: 'Start a new ${_newWhat(state.term)}',
                          onTap: () => _newSemester(context),
                        ),
                        Divider(height: 1, color: AppColors.hairline),
                        _LinkRow(
                          icon: PhIcons.trash,
                          label: 'Erase everything on this phone',
                          color: AppColors.red,
                          onTap: () => _erase(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Your money data stays on this phone unless you turn on '
                    'sync, and then it\'s encrypted so only you can read it. '
                    'No bank linking, no ads, no tracking.',
                    style: AppText.caption.copyWith(letterSpacing: 0),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Edits the current term's name, dates and starting money.
class _TermEditor extends StatefulWidget {
  const _TermEditor({super.key, required this.term});
  final Term term;

  @override
  State<_TermEditor> createState() => _TermEditorState();
}

class _TermEditorState extends State<_TermEditor> {
  late final _name = TextEditingController(text: widget.term.name);
  late final _balance = TextEditingController(
    text: amountText(widget.term.startingBalance),
  );
  late DateTime _start = widget.term.start;
  late DateTime _end = widget.term.end;

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    super.dispose();
  }

  DateTime get _today => AppScope.read(context).today;

  /// A month's name and end date follow the calendar, so only its start
  /// and money can be edited.
  bool get _monthly => widget.term.period == BudgetPeriod.monthly;

  Term get _edited => Term(
    name: _name.text.trim(),
    start: _start,
    end: _end,
    startingBalance: parseAmountInput(_balance.text),
    period: widget.term.period,
    savingsGoal: widget.term.savingsGoal,
  );

  bool get _dirty {
    final t = _edited;
    final saved = widget.term;
    return t.name != saved.name ||
        t.start != saved.start ||
        t.end != saved.end ||
        t.startingBalance != saved.startingBalance;
  }

  /// Why the edit can't be saved, or null when it can.
  String? get _problem {
    final t = _edited;
    if (t.name.isEmpty) return 'Give the term a name.';
    if (!t.end.isAfter(t.start)) return 'The term has to end after it starts.';
    if (!t.end.isAfter(_today)) return 'Pick an end date after today.';
    return null;
  }

  Future<void> _pickStart() async {
    final today = _today;
    final picked = await pickDate(
      context,
      initial: _start,
      first: _monthly
          ? DateTime(_end.year, _end.month)
          : DateTime(today.year - 1, today.month, today.day),
      last: today,
    );
    if (picked != null) setState(() => _start = picked);
  }

  Future<void> _pickEnd() async {
    final today = _today;
    final picked = await pickDate(
      context,
      initial: _end,
      first: DateTime(today.year, today.month, today.day + 1),
      last: DateTime(today.year + 2, today.month, today.day),
    );
    if (picked != null) setState(() => _end = picked);
  }

  void _save() {
    if (!_dirty || _problem != null) return;
    HapticFeedback.mediumImpact();
    FocusScope.of(context).unfocus();
    AppScope.read(context).updateTerm(_edited);
  }

  @override
  Widget build(BuildContext context) {
    final problem = _dirty ? _problem : null;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_monthly) ...[
            const FieldLabel('Term name'),
            GlassTextField(
              controller: _name,
              hint: 'e.g. Fall term',
              icon: PhIcons.notePencil,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),
          ],
          Row(
            children: [
              Expanded(
                child: DateField(
                  label: 'Starts',
                  date: _start,
                  onTap: _pickStart,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _monthly
                    ? MonthEndField(date: _end)
                    : DateField(label: 'Ends', date: _end, onTap: _pickEnd),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const FieldLabel('Starting money'),
          AmountField(
            controller: _balance,
            style: AppText.number,
            onChanged: (_) => setState(() {}),
          ),
          if (problem != null) ...[
            const SizedBox(height: 10),
            Text(problem, style: AppText.label.copyWith(color: AppColors.red)),
          ],
          const SizedBox(height: 16),
          GradientButton(
            label: _dirty ? 'Save changes' : 'Saved',
            icon: _dirty ? null : PhIcons.checkBold,
            height: 50,
            onTap: _dirty && problem == null ? _save : null,
          ),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.color = AppColors.text,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      semanticLabel: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppText.body.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: AppText.caption.copyWith(letterSpacing: 0),
                    ),
                ],
              ),
            ),
            const Icon(PhIcons.caretRight, size: 16, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

/// Your name, for the greeting. It stays on the phone.
class _ProfileEditor extends StatefulWidget {
  const _ProfileEditor({super.key, required this.name, required this.signedIn});
  final String name;
  final bool signedIn;

  @override
  State<_ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<_ProfileEditor> {
  late final _name = TextEditingController(text: widget.name);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _dirty => _name.text.trim() != widget.name;
  String? get _problem => _dirty ? validateName(_name.text) : null;

  void _save() {
    if (!_dirty || _problem != null) return;
    HapticFeedback.mediumImpact();
    FocusScope.of(context).unfocus();
    AppScope.read(context).rename(_name.text);
  }

  @override
  Widget build(BuildContext context) {
    final problem = _problem;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FieldLabel('Your name'),
          GlassTextField(
            controller: _name,
            hint: 'Your first name',
            icon: PhIcons.user,
            textCapitalization: TextCapitalization.words,
            maxLength: 30,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _save(),
            suffix: _dirty && problem == null
                ? Pressable(
                    onTap: _save,
                    semanticLabel: 'Save name',
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(
                        PhIcons.checkBold,
                        size: 20,
                        color: AppColors.lime,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 8),
          Text(
            problem ??
                (widget.signedIn
                    ? 'Your name stays on this phone.'
                    : 'No account needed. Your name and money data stay on '
                          'this phone.'),
            style: (problem == null ? AppText.caption : AppText.label).copyWith(
              letterSpacing: 0,
              color: problem == null ? null : AppColors.red,
            ),
          ),
        ],
      ),
    );
  }
}

/// Optional Google account: budget sync, sign out, or delete it. Money
/// data only leaves the phone with sync on, encrypted.
class _AccountCard extends StatefulWidget {
  const _AccountCard();

  @override
  State<_AccountCard> createState() => _AccountCardState();
}

class _AccountCardState extends State<_AccountCard> {
  bool _busy = false;

  Future<void> _run(Future<void> Function(AppState state) action) async {
    if (_busy) return;
    final state = AppScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await action(state);
    } on AccountException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signIn() => _run((state) async {
    if (await state.signInWithGoogle()) HapticFeedback.mediumImpact();
  });

  Future<void> _signOut() async {
    final ok = await showActionSheet<bool>(
      context,
      title: 'Sign out?',
      message: 'Your budget stays on this phone. Sign in again any time.',
      actions: const [
        SheetAction(value: true, label: 'Sign out', icon: PhIcons.signOut),
      ],
    );
    if (ok == true) await _run((state) => state.signOutAccount());
  }

  Future<void> _delete() async {
    final ok = await showActionSheet<bool>(
      context,
      title: 'Delete your account?',
      message:
          'Your Runway account and everything stored with it online are '
          'deleted for good. Your budget on this phone stays; use "Erase '
          'everything" to remove that too.',
      actions: const [
        SheetAction(
          value: true,
          label: 'Delete account',
          icon: PhIcons.trash,
          destructive: true,
        ),
      ],
    );
    if (ok != true) return;
    HapticFeedback.heavyImpact();
    await _run((state) async {
      await state.deleteAccount();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your account was deleted.')),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final account = AppScope.of(context).account;
    if (account == null) {
      return GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _LinkRow(
              icon: PhIcons.user,
              label: _busy ? 'Signing in…' : 'Continue with Google',
              onTap: _signIn,
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'Optional. For Squad and syncing your budget (encrypted) to '
                'other devices. Without sync, your money data stays '
                'on this phone.',
                style: AppText.caption.copyWith(letterSpacing: 0),
              ),
            ),
          ],
        ),
      );
    }
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                const Icon(PhIcons.user, size: 20, color: AppColors.lime),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Signed in with Google', style: AppText.label),
                      Text(
                        account.email,
                        style: AppText.body.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.hairline),
          _LinkRow(
            icon: PhIcons.lock,
            label: 'Budget sync',
            subtitle: syncSummary(AppScope.of(context)),
            onTap: () => showSyncSheet(context),
          ),
          Divider(height: 1, color: AppColors.hairline),
          _LinkRow(icon: PhIcons.signOut, label: 'Sign out', onTap: _signOut),
          Divider(height: 1, color: AppColors.hairline),
          _LinkRow(
            icon: PhIcons.trash,
            label: 'Delete account',
            color: AppColors.red,
            onTap: _delete,
          ),
        ],
      ),
    );
  }
}

/// Face ID / passcode lock switch. Turning it on or off asks for Face ID
/// first, so nobody else can change it and you know it works.
class _AppLockCard extends StatefulWidget {
  const _AppLockCard();

  @override
  State<_AppLockCard> createState() => _AppLockCardState();
}

class _AppLockCardState extends State<_AppLockCard> {
  late final Future<bool> _available = AppScope.read(context).deviceAuth
      .isAvailable();
  bool _busy = false;

  Future<void> _toggle(bool on) async {
    final state = AppScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    final result = await state.deviceAuth.authenticate(
      on ? 'Turn on the Runway lock' : 'Turn off the Runway lock',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    switch (result) {
      case DeviceAuthResult.success:
        state.setAppLock(on);
      case DeviceAuthResult.unavailable:
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Set up a passcode on your phone first.'),
          ),
        );
      case DeviceAuthResult.failed:
    }
  }

  @override
  Widget build(BuildContext context) {
    final on = AppScope.of(context).appLockEnabled;
    return FutureBuilder<bool>(
      future: _available,
      builder: (context, snapshot) {
        final available = snapshot.data ?? false;
        return GlassCard(
          child: Row(
            children: [
              const Icon(PhIcons.lock, size: 22, color: AppColors.lime),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'App lock',
                      style: AppText.body.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      available || on
                          ? 'Ask for $deviceLockName when you open Runway '
                                'or come back after a minute.'
                          : 'Needs a passcode or Face ID set up on this phone.',
                      style: AppText.caption.copyWith(letterSpacing: 0),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: on,
                activeTrackColor: AppColors.lime,
                onChanged: _busy || !(available || on) ? null : _toggle,
              ),
            ],
          ),
        );
      },
    );
  }
}
