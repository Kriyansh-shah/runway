import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../app/budget_math.dart';
import '../app/format.dart';
import '../app/models.dart';
import '../app/theme.dart';
import '../widgets/aurora_background.dart';
import '../widgets/category_icon.dart';
import '../widgets/glass.dart';
import '../widgets/list_row.dart';
import '../widgets/ph_icons.dart';
import '../widgets/pressable.dart';
import 'money_actions.dart';

/// This term a month at a time: what was spent each day, red when it went
/// over that day's budget. Tap a day to see its expenses and edit or
/// delete them; every later day's budget follows.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _selected;
  late DateTime _month;

  static const _weekdays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  @override
  void initState() {
    super.initState();
    final state = AppScope.read(context);
    final start = dateOnly(state.term.start);
    final end = dateOnly(state.term.end);
    final today = state.today;
    _selected = today.isBefore(start)
        ? start
        : (today.isAfter(end) ? end : today);
    _month = DateTime(_selected.year, _selected.month);
  }

  static String _time(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m${d.hour < 12 ? 'am' : 'pm'}';
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final term = state.term;
    final today = state.today;
    final ledger = {for (final d in state.ledger) d.day: d};
    final first = DateTime(term.start.year, term.start.month);
    final last = DateTime(term.end.year, term.end.month);
    final selected = ledger[_selected];
    final items = state.expensesOn(_selected);

    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Calendar', style: AppText.title),
                            Text(
                              term.name,
                              style: AppText.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  GlassCard(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _MonthArrow(
                              icon: PhIcons.caretLeftBold,
                              label: 'Previous month',
                              onTap: _month.isAfter(first)
                                  ? () => setState(
                                      () => _month = DateTime(
                                        _month.year,
                                        _month.month - 1,
                                      ),
                                    )
                                  : null,
                            ),
                            Expanded(
                              child: Text(
                                '${monthName(_month)} ${_month.year}',
                                style: AppText.heading,
                                textAlign: TextAlign.center,
                              ),
                            ),
                            _MonthArrow(
                              icon: PhIcons.caretRight,
                              label: 'Next month',
                              onTap: _month.isBefore(last)
                                  ? () => setState(
                                      () => _month = DateTime(
                                        _month.year,
                                        _month.month + 1,
                                      ),
                                    )
                                  : null,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            for (final w in _weekdays)
                              Expanded(
                                child: Text(
                                  w,
                                  style: AppText.caption,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        _MonthGrid(
                          month: _month,
                          ledger: ledger,
                          today: today,
                          selected: _selected,
                          onSelect: (d) => setState(() => _selected = d),
                        ),
                      ],
                    ),
                  ),
                  SectionHeader(
                    sameDay(_selected, today)
                        ? 'Today'
                        : '${monthName(_selected)} ${_selected.day}',
                    trailing: selected == null
                        ? null
                        : Text(
                            selected.over
                                ? '${money(-selected.left)} over'
                                : '${money(selected.left)} left',
                            style: AppText.label.copyWith(
                              color: selected.over
                                  ? AppColors.red
                                  : AppColors.lime,
                            ),
                          ),
                  ),
                  if (selected != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        'Budget ${money(selected.allowance)} · '
                        'spent ${money(selected.spent)}'
                        '${selected.used > selected.spent + 0.005 ? ' · '
                                  'saved ${money(selected.used - selected.spent)}' : ''}',
                        style: AppText.label,
                      ),
                    ),
                  GlassCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: items.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              selected == null
                                  ? 'This day hasn’t happened yet.'
                                  : 'Nothing logged this day.',
                              style: AppText.label,
                              textAlign: TextAlign.center,
                            ),
                          )
                        : Column(
                            children: [
                              for (var i = 0; i < items.length; i++) ...[
                                if (i > 0)
                                  Divider(height: 1, color: AppColors.hairline),
                                _row(context, items[i]),
                              ],
                            ],
                          ),
                  ),
                  if (items.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        'Tap an expense to edit or delete it. Each day’s '
                        'budget after it updates to match.',
                        style: AppText.caption,
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, Expense e) => ListRow(
    key: ValueKey(e.id),
    leading: CategoryIcon.of(e),
    title: e.title,
    subtitle:
        '${_time(e.date)} · '
        '${e.planned ? 'Set aside' : (e.isNeed ? 'Need' : 'Want')}',
    amount: money(e.amount),
    accent: e.isNeed ? AppColors.need : AppColors.want,
    onTap: () => showExpenseActions(context, e),
  );
}

class _MonthArrow extends StatelessWidget {
  const _MonthArrow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    semanticLabel: label,
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Icon(
        icon,
        size: 18,
        color: onTap == null ? AppColors.hairline : AppColors.text,
      ),
    ),
  );
}

/// Sunday-first weeks. Days with no [ledger] entry (before the term,
/// after it, or still to come) are dimmed and can't be picked.
class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.ledger,
    required this.today,
    required this.selected,
    required this.onSelect,
  });

  final DateTime month;
  final Map<DateTime, DayLedger> ledger;
  final DateTime today;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final lead = DateTime(month.year, month.month).weekday % 7;
    final length = endOfMonth(month).day;
    final weeks = ((lead + length) / 7).ceil();
    return Column(
      children: [
        for (var w = 0; w < weeks; w++)
          Row(
            children: [
              for (var c = 0; c < 7; c++)
                Expanded(child: _cell(w * 7 + c - lead + 1, length)),
            ],
          ),
      ],
    );
  }

  Widget _cell(int dayNumber, int length) {
    if (dayNumber < 1 || dayNumber > length) {
      return const AspectRatio(aspectRatio: 0.82);
    }
    final day = DateTime(month.year, month.month, dayNumber);
    final entry = ledger[day];
    final isSelected = sameDay(day, selected);
    final isToday = sameDay(day, today);
    final spent = entry?.spent ?? 0;
    final color = entry == null
        ? AppColors.hairline
        : (entry.over ? AppColors.red : AppColors.lime);
    final cell = AnimatedContainer(
      duration: Motion.fast,
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.glassStrong : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isToday ? AppColors.lime : Colors.transparent,
          width: 1.2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$dayNumber',
            style: AppText.body.copyWith(
              fontWeight: FontWeight.w700,
              color: entry == null ? AppColors.muted : AppColors.text,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              entry == null || spent == 0
                  ? ' '
                  : money(spent, cents: spent < 10),
              style: AppText.caption.copyWith(color: color, letterSpacing: 0),
            ),
          ),
        ],
      ),
    );
    return AspectRatio(
      aspectRatio: 0.82,
      child: entry == null
          ? Opacity(opacity: 0.45, child: cell)
          : Pressable(
              onTap: () => onSelect(day),
              scale: 0.92,
              semanticLabel:
                  '${monthName(day)} $dayNumber, spent ${money(spent)}'
                  '${entry.over ? ', over budget' : ''}',
              child: cell,
            ),
    );
  }
}
