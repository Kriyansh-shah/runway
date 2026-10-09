import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_state.dart';
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
import 'login_screen.dart';
import 'money_actions.dart';
import 'setup_screen.dart';

/// Account, the current semester, big costs, and your data.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    final state = AppScope.read(context);
    final navigator = Navigator.of(context);
    await state.signOut();
    await navigator.pushAndRemoveUntil(
      FadeScaleRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _newSemester(BuildContext context) async {
    final navigator = Navigator.of(context);
    final ok = await showActionSheet<bool>(
      context,
      title: 'Start a new semester?',
      message:
          'You\'ll set up the new term next. This one is archived only once '
          'you finish, and its history stays on your phone.',
      actions: const [
        SheetAction(
          value: true,
          label: 'Set up a new semester',
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
      FadeScaleRoute<void>(builder: (_) => const LoginScreen()),
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
                    GlassCard(
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.surface,
                            ),
                            child: Text(user.initial, style: AppText.heading),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.name,
                                  style: AppText.heading,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  user.email,
                                  style: AppText.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'On-device account · nothing leaves your phone',
                                  style: AppText.caption.copyWith(
                                    letterSpacing: 0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SectionHeader('Semester'),
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
                                      '${c.emoji} ${c.name} · ${shortDate(c.dueDate)}',
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
                          icon: PhIcons.calendarBlank,
                          label: 'Start a new semester',
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
                  const SizedBox(height: 24),
                  GradientButton(
                    label: 'Sign out',
                    icon: PhIcons.signOut,
                    gradient: AppGradients.hot,
                    glow: AppColors.pink,
                    onTap: () => _signOut(context),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Runway keeps your money data on this phone only. '
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
    text: _amountText(widget.term.startingBalance),
  );
  late DateTime _start = widget.term.start;
  late DateTime _end = widget.term.end;

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    super.dispose();
  }

  static String _amountText(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  DateTime get _today => AppScope.read(context).today;

  Term get _edited => Term(
    name: _name.text.trim(),
    start: _start,
    end: _end,
    startingBalance: parseAmountInput(_balance.text),
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
      first: DateTime(today.year - 1, today.month, today.day),
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
          const FieldLabel('Term name'),
          GlassTextField(
            controller: _name,
            hint: 'e.g. Fall term',
            icon: PhIcons.notePencil,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
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
                child: DateField(label: 'Ends', date: _end, onTap: _pickEnd),
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
    this.color = AppColors.text,
  });

  final IconData icon;
  final String label;
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
              child: Text(
                label,
                style: AppText.body.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(PhIcons.caretRight, size: 16, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}
