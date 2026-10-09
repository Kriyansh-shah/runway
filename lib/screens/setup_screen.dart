import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_state.dart';
import '../app/device_auth.dart';
import '../app/format.dart';
import '../app/models.dart';
import '../app/theme.dart';
import '../widgets/aurora_background.dart';
import '../widgets/expense_inputs.dart';
import '../widgets/form_fields.dart';
import '../widgets/glass.dart';
import '../widgets/gradient_button.dart';
import '../widgets/motion.dart';
import '../widgets/ph_icons.dart';
import '../widgets/pressable.dart';
import '../widgets/transitions.dart';
import 'shell.dart';

/// Where a signed-in user lands: setup until they've entered their own term.
Widget landingFor(AppState state) =>
    state.needsSetup ? const SetupScreen() : const Shell();

/// First run: term name and dates, money for the term, and big costs coming
/// up. Replaces the demo data with the user's own semester.
///
/// Also used from Settings to start a new semester; then [cancellable] shows
/// a way back, and the current term is only archived once you finish.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key, this.cancellable = false});

  final bool cancellable;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _name = TextEditingController();
  final _balance = TextEditingController();
  final _costs = <UpcomingCost>[];
  late DateTime _start;
  DateTime? _end;
  bool _done = false;

  /// Offer the app lock (on by default) if the phone supports it and it
  /// isn't on already.
  bool _offerLock = false;
  bool _lock = true;

  @override
  void initState() {
    super.initState();
    final state = AppScope.read(context);
    _start = state.today;
    if (!state.appLockEnabled) {
      state.deviceAuth.isAvailable().then((ok) {
        if (mounted && ok) setState(() => _offerLock = true);
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    super.dispose();
  }

  DateTime get _today => AppScope.read(context).today;
  double get _startingBalance => parseAmountInput(_balance.text);

  bool get _ready =>
      _name.text.trim().isNotEmpty && _end != null && _startingBalance > 0;

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
    final first = DateTime(today.year, today.month, today.day + 1);
    final picked = await pickDate(
      context,
      initial: _end ?? first,
      first: first,
      last: DateTime(today.year + 2, today.month, today.day),
    );
    if (picked != null) setState(() => _end = picked);
  }

  void _addCost(UpcomingCost cost) {
    setState(() {
      _costs.add(cost);
      _costs.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    });
  }

  void _cancel() {
    Navigator.of(context).pushAndRemoveUntil(
      FadeScaleRoute<void>(builder: (_) => const Shell()),
      (_) => false,
    );
  }

  Future<void> _finish() async {
    if (!_ready || _done) return;
    _done = true;
    final state = AppScope.read(context);
    final navigator = Navigator.of(context);
    // Asking now also shows iOS's one-time Face ID permission, right when
    // the user chose it. If they cancel, the lock stays off for now.
    if (_offerLock && _lock) {
      final result = await state.deviceAuth.authenticate(
        'Lock Runway so only you can open it',
      );
      if (result == DeviceAuthResult.success) state.setAppLock(true);
    }
    state.startTerm(
      Term(
        name: _name.text.trim(),
        start: _start,
        end: _end!,
        startingBalance: _startingBalance,
      ),
      // Costs due after the term ends can't be reserved from this term.
      _costs.where((c) => !c.dueDate.isAfter(_end!)).toList(),
    );
    HapticFeedback.mediumImpact();
    await navigator.pushAndRemoveUntil(
      FadeScaleRoute<void>(builder: (_) => const Shell()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sections = <Widget>[
      Text(
        'Set up your semester',
        style: AppText.title,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 4),
      Text(
        'Runway plans around your term, not the month.',
        style: AppText.label,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 20),
      GlassCard(
        strong: true,
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
            const FieldLabel('Money you have right now'),
            AmountField(
              controller: _balance,
              style: AppText.number,
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Big costs coming up', style: AppText.heading),
            const SizedBox(height: 2),
            Text(
              'Flights, tickets, bills. Runway sets this money aside.',
              style: AppText.label,
            ),
            const SizedBox(height: 14),
            for (final c in _costs)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
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
                      style: AppText.number.copyWith(fontSize: 16),
                    ),
                    const SizedBox(width: 6),
                    Pressable(
                      onTap: () => setState(() => _costs.remove(c)),
                      semanticLabel: 'Remove ${c.name}',
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(
                          PhIcons.xBold,
                          size: 16,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            AddCostForm(
              firstDate: _today,
              lastDate:
                  _end ?? DateTime(_today.year + 2, _today.month, _today.day),
              onAdd: _addCost,
            ),
          ],
        ),
      ),
      if (_offerLock) ...[
        const SizedBox(height: 16),
        GlassCard(
          child: Row(
            children: [
              const Icon(PhIcons.lock, size: 22, color: AppColors.lime),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lock Runway',
                      style: AppText.body.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Only you can open it, with $deviceLockName.',
                      style: AppText.caption.copyWith(letterSpacing: 0),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: _lock,
                activeTrackColor: AppColors.lime,
                onChanged: (v) => setState(() => _lock = v),
              ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 20),
      GradientButton(
        label: 'Start my runway',
        icon: PhIcons.arrowRightBold,
        onTap: _ready ? _finish : null,
      ),
      if (widget.cancellable) ...[
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: _cancel,
            child: Text('Keep my current semester', style: AppText.label),
          ),
        ),
      ],
    ];

    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < sections.length; i++)
                      if (sections[i] is SizedBox)
                        sections[i]
                      else
                        Entrance(index: i, child: sections[i]),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
