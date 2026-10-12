import 'package:flutter/material.dart';

import '../app/app_state.dart';
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

/// Every expense this term, newest first, grouped by day. Tap one to edit
/// or delete it.
///
/// With [past], shows a finished term from History instead, read-only.
class AllExpensesScreen extends StatelessWidget {
  const AllExpensesScreen({super.key, this.past});

  final PastTerm? past;

  static String _dayLabel(DateTime day, DateTime today) =>
      switch (daysBetween(day, today)) {
        0 => 'Today',
        1 => 'Yesterday',
        _ => shortDate(day),
      };

  static String _time(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m${d.hour < 12 ? 'am' : 'pm'}';
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final past = this.past;
    final today = state.today;
    final term = past?.term ?? state.term;
    final expenses = past == null
        ? state.allExpenses
        : ([...past.expenses]..sort((a, b) => b.date.compareTo(a.date)));
    final days = <DateTime, List<Expense>>{};
    for (final e in expenses) {
      days.putIfAbsent(dateOnly(e.date), () => []).add(e);
    }
    final total = expenses.fold<double>(0, (s, e) => s + e.amount);

    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                    sliver: SliverToBoxAdapter(
                      child: Row(
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
                                Text(
                                  past == null ? 'All expenses' : term.name,
                                  style: AppText.title,
                                ),
                                Text(
                                  '${past == null ? term.name : dateRange(term.start, term.end)}'
                                  ' · ${money(total)} · '
                                  '${plural(expenses.length, 'expense')}',
                                  style: AppText.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (expenses.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text(
                          past == null
                              ? 'Nothing logged this ${term.period.noun} yet.'
                              : 'Nothing was logged.',
                          style: AppText.label,
                        ),
                      ),
                    ),
                  for (final MapEntry(key: day, value: items) in days.entries)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SectionHeader(
                              past == null
                                  ? _dayLabel(day, today)
                                  : shortDate(day),
                              trailing: Text(
                                money(
                                  items.fold<double>(0, (s, e) => s + e.amount),
                                ),
                                style: AppText.label,
                              ),
                            ),
                            GlassCard(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              child: Column(
                                children: [
                                  for (var i = 0; i < items.length; i++) ...[
                                    if (i > 0)
                                      Divider(
                                        height: 1,
                                        color: AppColors.hairline,
                                      ),
                                    ListRow(
                                      key: ValueKey(items[i].id),
                                      leading: CategoryIcon(items[i].category),
                                      title: items[i].title,
                                      subtitle:
                                          '${_time(items[i].date)} · '
                                          '${items[i].isNeed ? 'Need' : 'Want'}',
                                      amount: money(items[i].amount),
                                      accent: items[i].isNeed
                                          ? AppColors.need
                                          : AppColors.want,
                                      onTap: past != null
                                          ? null
                                          : () => showExpenseActions(
                                              context,
                                              items[i],
                                            ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: MediaQuery.paddingOf(context).bottom + 32,
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
}
