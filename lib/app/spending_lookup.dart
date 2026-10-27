/// What the coach can look up about past spending: a day, a week, a month
/// or the whole term, optionally one category. The on-device model asks
/// for these (ios/Runner/CoachModel.swift); the numbers all come from here.
library;

import 'budget_math.dart';
import 'format.dart';
import 'models.dart';

/// The periods the model can ask about, by the names it uses.
enum LookupPeriod {
  today,
  yesterday,
  thisWeek,
  lastWeek,
  thisMonth,
  lastMonth,
  wholeTerm,
  oneDay,
}

class SpendingHistory {
  const SpendingHistory({
    required this.expenses,
    required this.ledger,
    required this.today,
    required this.termStart,
  });

  final List<Expense> expenses;

  /// See [dailyLedger].
  final List<DayLedger> ledger;
  final DateTime today;
  final DateTime termStart;

  /// The first and last day of [period], or null if [day] doesn't parse.
  /// Weeks start on Sunday, like the calendar.
  ({DateTime from, DateTime to})? range(LookupPeriod period, {String? day}) {
    final t = dateOnly(today);
    final sunday = DateTime(t.year, t.month, t.day - t.weekday % 7);
    return switch (period) {
      LookupPeriod.today => (from: t, to: t),
      LookupPeriod.yesterday => (
        from: DateTime(t.year, t.month, t.day - 1),
        to: DateTime(t.year, t.month, t.day - 1),
      ),
      LookupPeriod.thisWeek => (from: sunday, to: t),
      LookupPeriod.lastWeek => (
        from: DateTime(sunday.year, sunday.month, sunday.day - 7),
        to: DateTime(sunday.year, sunday.month, sunday.day - 1),
      ),
      LookupPeriod.thisMonth => (from: DateTime(t.year, t.month), to: t),
      LookupPeriod.lastMonth => (
        from: DateTime(t.year, t.month - 1),
        to: DateTime(t.year, t.month, 0),
      ),
      LookupPeriod.wholeTerm => (from: dateOnly(termStart), to: t),
      LookupPeriod.oneDay => switch (DateTime.tryParse(day ?? '')) {
        final d? => (from: dateOnly(d), to: dateOnly(d)),
        null => null,
      },
    };
  }

  /// Spending in [period], as facts for the model: the total, each
  /// category, the biggest expenses and (for everything) the days over
  /// budget. With [category], only expenses filed under or noted as it.
  Map<String, Object> lookUp({
    required String period,
    String? day,
    String? category,
  }) {
    final p = LookupPeriod.values.asNameMap()[period];
    final r = p == null ? null : range(p, day: day);
    if (r == null) {
      return {
        'error':
            'Ask for one of: ${[for (final p in LookupPeriod.values) p.name].join(', ')}.',
      };
    }
    final start = dateOnly(termStart);
    final from = r.from.isBefore(start) ? start : r.from;
    final to = r.to.isAfter(today) ? dateOnly(today) : r.to;
    final label = sameDay(r.from, r.to)
        ? '${weekdayName(r.from)}, ${shortDate(r.from)}'
        : '${shortDate(r.from)} – ${shortDate(r.to)}';
    if (from.isAfter(to)) {
      return {
        'period': label,
        'note': r.to.isBefore(start)
            ? 'That was before this budget started, so nothing was logged.'
            : 'That hasn\'t happened yet.',
      };
    }

    bool inRange(DateTime d) =>
        !dateOnly(d).isBefore(from) && !dateOnly(d).isAfter(to);
    var picked = [
      for (final e in expenses)
        if (inRange(e.date)) e,
    ];
    final wanted = category?.trim().toLowerCase() ?? '';
    if (wanted.isNotEmpty) {
      bool matches(Expense e) {
        final name = e.filedUnder.label.toLowerCase();
        return name.contains(wanted) ||
            wanted.contains(name) ||
            (e.note?.toLowerCase().contains(wanted) ?? false);
      }

      final matched = picked.where(matches).toList();
      if (matched.isEmpty) {
        return {
          'period': label,
          'category': category!.trim(),
          'note': 'Nothing logged under that in this period.',
          'categoriesUsed': {for (final e in picked) e.filedUnder.label}
              .toList(),
        };
      }
      picked = matched;
    }

    final everyday = [
      for (final e in picked)
        if (!e.planned) e,
    ];
    final spent = _sum(everyday);
    final bills = _sum(picked.where((e) => e.planned));
    final byCategory = <String, double>{};
    for (final e in everyday) {
      final name = e.filedUnder.label;
      byCategory[name] = (byCategory[name] ?? 0) + e.amount;
    }
    final categories = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final biggest = [...everyday]..sort((a, b) => b.amount.compareTo(a.amount));
    final days = daysBetween(from, to) + 1;
    final ledgerDays = [
      for (final d in ledger)
        if (inRange(d.day)) d,
    ];

    return {
      'period': label,
      if (wanted.isNotEmpty) 'category': category!.trim(),
      'spent': _cents(spent),
      if (bills > 0) 'billsPaidFromMoneySetAside': _cents(bills),
      'expensesLogged': everyday.length,
      if (days > 1) 'averagePerDay': _cents(spent / days),
      if (wanted.isEmpty && categories.length > 1)
        'byCategory': {
          for (final c in categories.take(6)) c.key: _cents(c.value),
        },
      'biggest': [
        for (final e in biggest.take(3))
          {
            'what': e.title,
            'amount': _cents(e.amount),
            'on': shortDate(e.date),
          },
      ],
      if (wanted.isEmpty && ledgerDays.isNotEmpty) ...{
        'daysOverBudget': ledgerDays.where((d) => d.over).length,
        'daysCounted': ledgerDays.length,
      },
    };
  }
}

const _weekdays = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', //
  'Sunday',
];

/// `Tuesday`
String weekdayName(DateTime d) => _weekdays[d.weekday - 1];

double _sum(Iterable<Expense> es) => es.fold(0.0, (s, e) => s + e.amount);

double _cents(double v) => (v * 100).round() / 100;

final _spendWords = RegExp(r'\b(spend|spent|spending)\b', caseSensitive: false);

const _periodWords = [
  ('yesterday', LookupPeriod.yesterday),
  ('today', LookupPeriod.today),
  ('last week', LookupPeriod.lastWeek),
  ('this week', LookupPeriod.thisWeek),
  ('last month', LookupPeriod.lastMonth),
  ('this month', LookupPeriod.thisMonth),
];

/// "How much did I spend on coffee last week?" answered by the rules, or
/// null when the question isn't about past spending. Without a period it
/// means the whole budget so far.
String? answerSpendingQuestion(String question, SpendingHistory history) {
  if (!_spendWords.hasMatch(question)) return null;
  final q = question.toLowerCase();
  final (phrase, period) =
      _periodWords
          .where((p) => q.contains(p.$1))
          .map((p) => (p.$1, p.$2))
          .firstOrNull ??
      ('so far', LookupPeriod.wholeTerm);
  final names = {
    for (final e in history.expenses) e.filedUnder.label.toLowerCase(),
  }.where(q.contains).toList()..sort((a, b) => b.length.compareTo(a.length));
  final category = names.firstOrNull;
  final found = history.lookUp(period: period.name, category: category);
  final on = category == null ? '' : ' on $category';
  if (found['note'] case final String note) {
    return category == null ? note : 'Nothing logged$on $phrase.';
  }
  final spent = found['spent']! as double;
  final count = found['expensesLogged']! as int;
  if (count == 0) return 'You haven\'t spent anything$on $phrase.';
  final buf = StringBuffer(
    'You spent ${money(spent)}$on $phrase, across ${plural(count, 'expense')}.',
  );
  final biggest = found['biggest']! as List<Map<String, Object>>;
  if (count > 1 && biggest.isNotEmpty) {
    final b = biggest.first;
    buf.write(
      ' The biggest was ${b['what']} at ${money(b['amount']! as double)} '
      'on ${b['on']}.',
    );
  }
  if (found['byCategory'] case final Map<String, double> byCategory) {
    final top = byCategory.entries.first;
    buf.write(' Most of it went to ${top.key} (${money(top.value)}).');
  }
  return buf.toString();
}
