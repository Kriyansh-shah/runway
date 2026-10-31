import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_state.dart';
import '../app/budget_sync.dart';
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
import 'savings_goal_sheet.dart';
import 'shell.dart';
import 'sync_sheets.dart';

/// Where a signed-in user lands: setup until they've entered their own term.
/// Where the app opens: Home, or setup on a fresh device. A fresh device
/// signed in to an account with a synced budget offers to unlock it first.
Widget landingFor(AppState state) =>
    switch ((state.needsSetup, state.sync.status)) {
      (true, SyncStatus.needsPassphrase) => const RestoreScreen(),
      (true, _) => const SetupScreen(),
      (false, _) => const Shell(),
    };

/// First run: semester or monthly, the dates, money for that stretch, and
/// big costs coming up. Replaces the demo data with the user's own budget.
/// A monthly budget runs to the end of this month and has no name or end
/// date to fill in.
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
  final _savings = TextEditingController();
  final _costs = <UpcomingCost>[];

  /// Ids of the [_costs] that repeat every month.
  final _monthlyCosts = <String>{};
  var _period = BudgetPeriod.semester;
  late DateTime _start;
  DateTime? _pickedEnd;
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
    // A new semester starts with what the old one leaves (its savings stay
    // saved).
    if (widget.cancellable && state.leftIfEndedNow > 0) {
      _balance.text = amountText(state.leftIfEndedNow);
    }
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
    _savings.dispose();
    super.dispose();
  }

  DateTime get _today => AppScope.read(context).today;
  double get _startingBalance => parseAmountInput(_balance.text);

  bool get _monthly => _period == BudgetPeriod.monthly;

  DateTime? get _end => _monthly ? endOfMonth(_start) : _pickedEnd;

  String get _termName => _monthly ? monthName(_start) : _name.text.trim();

  double get _savingsGoal => parseAmountInput(_savings.text);

  /// Money not going to the big costs listed, the most there is to save.
  double get _canSave {
    final costs = _costs.fold<double>(0, (s, c) => s + c.amount);
    return (_startingBalance - costs).clamp(0, double.infinity).toDouble();
  }

  bool get _savingsTooBig => _savingsGoal > _canSave + 0.005;

  bool get _ready =>
      _termName.isNotEmpty &&
      _end != null &&
      _startingBalance > 0 &&
      !_savingsTooBig;

  void _setPeriod(BudgetPeriod period) {
    setState(() {
      _period = period;
      // A month can't start before this month did.
      if (_monthly && _start.isBefore(_firstOfMonth)) _start = _today;
    });
  }

  DateTime get _firstOfMonth => DateTime(_today.year, _today.month);

  Future<void> _pickStart() async {
    final today = _today;
    final picked = await pickDate(
      context,
      initial: _start,
      first: _monthly
          ? _firstOfMonth
          : DateTime(today.year - 1, today.month, today.day),
      last: today,
    );
    if (picked != null) setState(() => _start = picked);
  }

  Future<void> _pickEnd() async {
    final today = _today;
    final first = DateTime(today.year, today.month, today.day + 1);
    final picked = await pickDate(
      context,
      initial: _pickedEnd ?? first,
      first: first,
      last: DateTime(today.year + 2, today.month, today.day),
    );
    if (picked != null) setState(() => _pickedEnd = picked);
  }

  void _addCost(UpcomingCost cost, {required bool monthly}) {
    setState(() {
      if (monthly) _monthlyCosts.add(cost.id);
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
    final end = _end!;
    // Costs due after the term ends can't be reserved from this term.
    final costs = _costs.where((c) => !c.dueDate.isAfter(end));
    state.startTerm(
      Term(
        name: _termName,
        start: _start,
        end: end,
        startingBalance: _startingBalance,
        period: _period,
        savingsGoal: _savingsGoal,
      ),
      costs.where((c) => !_monthlyCosts.contains(c.id)).toList(),
    );
    for (final c in costs.where((c) => _monthlyCosts.contains(c.id))) {
      state.addUpcomingCost(c, monthly: true);
    }
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
        'Set up your ${_period.noun}',
        style: AppText.title,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 4),
      Text(
        _monthly
            ? 'A new month starts by itself, with what\'s left carried over.'
            : 'Runway plans around your term, not the month.',
        style: AppText.label,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 20),
      GlassCard(
        strong: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const FieldLabel('How do you want to budget?'),
            Row(
              children: [
                for (final p in BudgetPeriod.values) ...[
                  if (p != BudgetPeriod.values.first) const SizedBox(width: 10),
                  Expanded(
                    child: ChoiceChipPill(
                      selected: p == _period,
                      color: AppColors.lime,
                      onTap: () => _setPeriod(p),
                      child: Text(p.label, textAlign: TextAlign.center),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
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
                      ? MonthEndField(date: _end!)
                      : DateField(label: 'Ends', date: _end, onTap: _pickEnd),
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
            if (widget.cancellable && AppScope.read(context).leftIfEndedNow > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Text(
                  'What ${AppScope.read(context).term.name} leaves you, '
                  'besides its savings.',
                  style: AppText.caption.copyWith(letterSpacing: 0),
                ),
              ),
            if (AppScope.read(context).jars case final jars
                when jars.any((j) => j.saved > 0))
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Text(
                  // Jar money stays set aside; counting it here would make
                  // it spending money a second time.
                  'Don\'t count the '
                  '${money(jars.fold(0.0, (s, j) => s + j.saved), cents: false)} '
                  'you\'ve put aside for ${jars.where((j) => j.saved > 0).map((j) => j.name).join(', ')}.',
                  style: AppText.caption.copyWith(letterSpacing: 0),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _SavingsGoalCard(
        controller: _savings,
        noun: _period.noun,
        canSave: _canSave,
        tooBig: _savingsTooBig,
        onChanged: () => setState(() {}),
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
                        '${c.emoji} ${c.name} · ${shortDate(c.dueDate)}'
                        '${_monthlyCosts.contains(c.id) ? ' · monthly' : ''}',
                        style: AppText.body,
                      ),
                    ),
                    Text(
                      money(c.amount),
                      style: AppText.number.copyWith(fontSize: 16),
                    ),
                    const SizedBox(width: 6),
                    Pressable(
                      onTap: () => setState(() {
                        _costs.remove(c);
                        _monthlyCosts.remove(c.id);
                      }),
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
            child: Text(
              'Keep my current ${AppScope.read(context).term.period.noun}',
              style: AppText.label,
            ),
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

/// "Save this semester": optional, with 10% / 20% suggestions.
class _SavingsGoalCard extends StatelessWidget {
  const _SavingsGoalCard({
    required this.controller,
    required this.noun,
    required this.canSave,
    required this.tooBig,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String noun;
  final double canSave;
  final bool tooBig;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final value = parseAmountInput(controller.text);
    final suggestions = {
      for (final share in [0.1, 0.2])
        if (suggestedGoal(canSave, share) > 0)
          suggestedGoal(canSave, share): '${(share * 100).round()}%',
    };
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Save this $noun', style: AppText.heading),
          const SizedBox(height: 2),
          Text(
            'Runway sets it aside first, so your daily budget leaves it '
            'alone. Optional, and you can change it anytime.',
            style: AppText.label,
          ),
          const SizedBox(height: 14),
          AmountField(controller: controller, onChanged: (_) => onChanged()),
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final MapEntry(key: goal, value: label)
                    in suggestions.entries)
                  ChoiceChipPill(
                    selected: value == goal,
                    color: AppColors.lime,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      controller.text = amountText(goal);
                      onChanged();
                    },
                    child: Text('$label · ${money(goal, cents: false)}'),
                  ),
              ],
            ),
          ],
          if (tooBig) ...[
            const SizedBox(height: 8),
            Text(
              'That\'s more than you\'ll have left after your big costs. '
              'Try a smaller goal.',
              style: AppText.label.copyWith(color: AppColors.butter),
            ),
          ],
        ],
      ),
    );
  }
}
