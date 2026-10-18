import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../app/budget_math.dart';
import '../app/format.dart';
import '../app/models.dart';
import '../app/theme.dart';
import '../widgets/aurora_background.dart';
import '../widgets/glass.dart';
import '../widgets/ph_icons.dart';
import '../widgets/pressable.dart';
import '../widgets/transitions.dart';
import 'all_expenses_screen.dart';

/// Finished semesters and months, newest first: what you started with,
/// what came in, what you spent and what was left. Tap one to see its
/// expenses.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late final Future<List<PastTerm>> _history = AppScope.read(context).history();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: FutureBuilder(
                future: _history,
                builder: (context, snapshot) {
                  final past = snapshot.data;
                  return ListView(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      8,
                      20,
                      MediaQuery.paddingOf(context).bottom + 32,
                    ),
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
                          Text('History', style: AppText.title),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (snapshot.hasError)
                        _Message(
                          'Couldn\'t load your history. Close and reopen '
                          'Runway.',
                        )
                      else if (past == null)
                        const Padding(
                          padding: EdgeInsets.only(top: 48),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (past.isEmpty)
                        _Message(
                          'Nothing here yet. When a month or semester ends, '
                          'it shows up here.',
                        )
                      else
                        for (final p in past)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _PastCard(past: p),
                          ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 48),
    child: Text(text, style: AppText.label, textAlign: TextAlign.center),
  );
}

class _PastCard extends StatelessWidget {
  const _PastCard({required this.past});
  final PastTerm past;

  @override
  Widget build(BuildContext context) {
    final term = past.term;
    final s = summarize(past);
    final short = s.left < 0;
    return Pressable(
      onTap: () => Navigator.of(context).push(
        FadeScaleRoute<void>(builder: (_) => AllExpensesScreen(past: past)),
      ),
      scale: 0.98,
      semanticLabel:
          '${term.name}, spent ${money(s.spent)}, '
          '${short ? 'overspent ${money(-s.left)}' : 'left ${money(s.left)}'}',
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(term.name, style: AppText.heading)),
                Pill(
                  label: short
                      ? '${money(-s.left, cents: false)} over'
                      : '${money(s.left, cents: false)} left',
                  color: short ? AppColors.red : AppColors.lime,
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${term.period.label} · ${dateRange(term.start, term.end)}',
              style: AppText.label,
            ),
            const SizedBox(height: 12),
            _Line('Started with', money(s.startedWith)),
            if (s.moneyIn > 0) _Line('Money in', '+${money(s.moneyIn)}'),
            _Line('Spent', '−${money(s.spent)}'),
            if (s.savingsGoal > 0)
              _Line(
                'Saved',
                '${money(s.saved, cents: false)} of '
                    '${money(s.savingsGoal, cents: false)}',
              ),
            if (s.topCategories.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                [
                  for (final c in s.topCategories)
                    '${c.category.emoji} ${c.category.label} '
                        '${money(c.amount, cents: false)}',
                ].join('  ·  '),
                style: AppText.caption.copyWith(letterSpacing: 0),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        Expanded(child: Text(label, style: AppText.body)),
        Text(value, style: AppText.number.copyWith(fontSize: 16)),
      ],
    ),
  );
}
