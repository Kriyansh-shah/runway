import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_state.dart';
import '../app/format.dart';
import '../app/models.dart';
import '../app/theme.dart';
import '../widgets/aurora_background.dart';
import '../widgets/expense_inputs.dart';
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
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _name = TextEditingController();
  final _balance = TextEditingController();
  final _costName = TextEditingController();
  final _costAmount = TextEditingController();
  final _costs = <UpcomingCost>[];
  late DateTime _start;
  DateTime? _end;
  DateTime? _costDue;
  bool _done = false;

  static final _amountFormat = FilteringTextInputFormatter.allow(
    RegExp(r'^\d{0,6}(\.\d{0,2})?'),
  );

  @override
  void initState() {
    super.initState();
    _start = AppScope.read(context).today;
  }

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    _costName.dispose();
    _costAmount.dispose();
    super.dispose();
  }

  DateTime get _today => AppScope.read(context).today;
  double get _startingBalance => double.tryParse(_balance.text) ?? 0;
  double get _costValue => double.tryParse(_costAmount.text) ?? 0;

  bool get _ready =>
      _name.text.trim().isNotEmpty && _end != null && _startingBalance > 0;

  bool get _costReady =>
      _costName.text.trim().isNotEmpty && _costValue > 0 && _costDue != null;

  Future<DateTime?> _pick(DateTime initial, DateTime first, DateTime last) =>
      showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: first,
        lastDate: last,
      );

  Future<void> _pickStart() async {
    final today = _today;
    final picked = await _pick(
      _start,
      DateTime(today.year - 1, today.month, today.day),
      today,
    );
    if (picked != null) setState(() => _start = picked);
  }

  Future<void> _pickEnd() async {
    final today = _today;
    final first = today.add(const Duration(days: 1));
    final picked = await _pick(
      _end ?? first,
      first,
      DateTime(today.year + 2, today.month, today.day),
    );
    if (picked != null) setState(() => _end = picked);
  }

  Future<void> _pickDue() async {
    final today = _today;
    final picked = await _pick(
      _costDue ?? today,
      today,
      _end ?? DateTime(today.year + 2, today.month, today.day),
    );
    if (picked != null) setState(() => _costDue = picked);
  }

  void _addCost() {
    if (!_costReady) return;
    HapticFeedback.selectionClick();
    setState(() {
      _costs.add(
        UpcomingCost(
          id: 'u${DateTime.now().microsecondsSinceEpoch}',
          emoji: '📌',
          name: _costName.text.trim(),
          amount: _costValue,
          dueDate: _costDue!,
        ),
      );
      _costs.sort((a, b) => a.dueDate.compareTo(b.dueDate));
      _costName.clear();
      _costAmount.clear();
      _costDue = null;
    });
  }

  void _finish() {
    if (!_ready || _done) return;
    _done = true;
    final state = AppScope.read(context);
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
    Navigator.of(context)
        .pushReplacement(FadeScaleRoute<void>(builder: (_) => const Shell()));
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
                  child: _DateField(
                    label: 'Starts',
                    date: _start,
                    onTap: _pickStart,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DateField(label: 'Ends', date: _end, onTap: _pickEnd),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const FieldLabel('Money you have right now'),
            GlassTextField(
              controller: _balance,
              hint: '0.00',
              prefixText: '\$ ',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [_amountFormat],
              maxLength: 9,
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
            GlassTextField(
              controller: _costName,
              hint: 'e.g. Flight home',
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: GlassTextField(
                    controller: _costAmount,
                    hint: '0.00',
                    prefixText: '\$ ',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [_amountFormat],
                    maxLength: 9,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DateField(date: _costDue, onTap: _pickDue),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: ChoiceChipPill(
                selected: _costReady,
                color: AppColors.lime,
                onTap: _addCost,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(PhIcons.plusBold, size: 16),
                    SizedBox(width: 6),
                    Text('Add cost'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      GradientButton(
        label: 'Start my runway',
        icon: PhIcons.arrowRightBold,
        onTap: _ready ? _finish : null,
      ),
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

/// Tappable date box styled like [GlassTextField].
class _DateField extends StatelessWidget {
  const _DateField({this.label, required this.date, required this.onTap});
  final String? label;
  final DateTime? date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final d = date;
    final text = d == null ? 'Pick date' : '${shortDate(d)}, ${d.year}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) FieldLabel(label!),
        Pressable(
          onTap: onTap,
          scale: 0.98,
          semanticLabel: '${label ?? 'Due date'}: $text',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Text(
              text,
              style: AppText.body.copyWith(
                color: d == null ? AppColors.muted : AppColors.text,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
