/// Splits between friends: who owes what for a shared expense, and the
/// balance with each friend once every split and settle-up is counted.
/// Pure Dart, all in whole cents.
///
/// Every split and settle-up belongs to a *scope*: a squad, or no squad
/// (null). In a squad with "simplify debts" on, the squad's debts are
/// redrawn as the fewest payments that settle everyone (Ann owes Ben $10
/// and Ben owes Cat $10 becomes Ann pays Cat $10). Elsewhere, debts stay
/// between the people who split.
library;

import 'dart:math' as math;

enum SplitKind {
  equal,
  exact,
  percent,
  shares;

  String get label => switch (this) {
    equal => 'Equally',
    exact => 'Exact amounts',
    percent => 'Percentages',
    shares => 'Shares',
  };
}

/// A split as the server stores it (and only its people can see).
class SharedExpense {
  const SharedExpense({
    required this.id,
    required this.paidBy,
    required this.description,
    required this.totalCents,
    required this.shares,
    required this.createdAt,
    this.squadId,
    this.createdBy,
    this.category = 'other',
    this.kind = SplitKind.equal,
    this.deleted = false,
  });

  final String id;
  final String? squadId;
  final String? createdBy;
  final String paidBy;
  final String description;
  final String category;
  final SplitKind kind;
  final int totalCents;

  /// What each person's part was, payer included (0 if they paid for
  /// others only). Adds up to [totalCents].
  final Map<String, int> shares;
  final DateTime createdAt;
  final bool deleted;
}

/// [from] paid [to] back.
class Settlement {
  const Settlement({
    required this.id,
    required this.from,
    required this.to,
    required this.amountCents,
    required this.createdAt,
    this.squadId,
    this.createdBy,
  });

  final String id;
  final String? squadId;
  final String from;
  final String to;
  final int amountCents;
  final String? createdBy;
  final DateTime createdAt;
}

/// A settle-up to record: [from] pays [to] within [squadId]'s books.
class SettlementItem {
  const SettlementItem({
    required this.from,
    required this.to,
    required this.amountCents,
    this.squadId,
  });

  final String? squadId;
  final String from;
  final String to;
  final int amountCents;

  @override
  bool operator ==(Object other) =>
      other is SettlementItem &&
      other.squadId == squadId &&
      other.from == from &&
      other.to == to &&
      other.amountCents == amountCents;

  @override
  int get hashCode => Object.hash(squadId, from, to, amountCents);

  @override
  String toString() => '$from→$to $amountCents¢ (${squadId ?? '-'})';
}

/// Why a split's numbers don't work, in words for the person.
class SplitInputException implements Exception {
  const SplitInputException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Each person's part of [totalCents].
///
/// [inputs] depends on [kind]: nothing for equal, cents for exact,
/// percentages for percent, weights for shares. Leftover cents from
/// rounding go to [roundingTo] first (normally the payer), then in order,
/// so the parts always add up exactly.
Map<String, int> computeShares({
  required int totalCents,
  required List<String> people,
  required SplitKind kind,
  Map<String, num> inputs = const {},
  String? roundingTo,
}) {
  if (people.length < 2) {
    throw const SplitInputException('Pick at least one person to split with.');
  }
  if (totalCents <= 0) {
    throw const SplitInputException('Enter what it cost.');
  }
  switch (kind) {
    case SplitKind.equal:
      return _byWeights(totalCents, {for (final p in people) p: 1}, roundingTo);
    case SplitKind.exact:
      final parts = {for (final p in people) p: (inputs[p] ?? 0).round()};
      if (parts.values.any((c) => c < 0)) {
        throw const SplitInputException('Amounts can\'t be negative.');
      }
      final sum = parts.values.fold(0, (a, b) => a + b);
      if (sum != totalCents) {
        final gap = totalCents - sum;
        throw SplitInputException(
          gap > 0
              ? '${_dollars(gap)} still to assign.'
              : '${_dollars(-gap)} more than the total.',
        );
      }
      return parts;
    case SplitKind.percent:
      final pct = {for (final p in people) p: inputs[p] ?? 0};
      if (pct.values.any((v) => v < 0)) {
        throw const SplitInputException('Percentages can\'t be negative.');
      }
      final sum = pct.values.fold<num>(0, (a, b) => a + b);
      if ((sum - 100).abs() > 0.001) {
        throw SplitInputException(
          'Percentages add up to ${_trim(sum)}%, not 100%.',
        );
      }
      return _byWeights(totalCents, pct, roundingTo);
    case SplitKind.shares:
      final weights = {for (final p in people) p: inputs[p] ?? 0};
      if (weights.values.any((v) => v < 0)) {
        throw const SplitInputException('Shares can\'t be negative.');
      }
      if (weights.values.fold<num>(0, (a, b) => a + b) <= 0) {
        throw const SplitInputException('Give someone at least 1 share.');
      }
      return _byWeights(totalCents, weights, roundingTo);
  }
}

/// Largest-remainder rounding: everyone gets their exact part rounded
/// down, then the leftover cents go to the biggest fractions, with
/// [first] winning ties.
Map<String, int> _byWeights(
  int total,
  Map<String, num> weights,
  String? first,
) {
  final sum = weights.values.fold<num>(0, (a, b) => a + b);
  final exact = {for (final e in weights.entries) e.key: total * e.value / sum};
  final parts = {for (final e in exact.entries) e.key: e.value.floor()};
  var left = total - parts.values.fold(0, (a, b) => a + b);
  final order = weights.keys.toList()
    ..sort((a, b) {
      final fa = exact[a]! - parts[a]!;
      final fb = exact[b]! - parts[b]!;
      if ((fb - fa).abs() > 1e-9) return fb.compareTo(fa);
      if (a == first) return -1;
      if (b == first) return 1;
      return weights.keys.toList().indexOf(a) -
          weights.keys.toList().indexOf(b);
    });
  for (final p in order) {
    if (left == 0) break;
    if (weights[p]! <= 0) continue;
    parts[p] = parts[p]! + 1;
    left--;
  }
  return parts;
}

String _dollars(int cents) => '\$${(cents / 100).toStringAsFixed(2)}';
String _trim(num v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

/// Who owes whom, one scope at a time: `debts[scope][(debtor, creditor)]`.
/// Settle-ups count as the receiver owing the payer back.
Map<String?, Map<(String, String), int>> _rawDebts(
  Iterable<SharedExpense> expenses,
  Iterable<Settlement> settlements,
) {
  final out = <String?, Map<(String, String), int>>{};
  void add(String? scope, String debtor, String creditor, int cents) {
    if (debtor == creditor || cents == 0) return;
    final m = out.putIfAbsent(scope, () => {});
    m[(debtor, creditor)] = (m[(debtor, creditor)] ?? 0) + cents;
  }

  for (final e in expenses) {
    if (e.deleted) continue;
    for (final s in e.shares.entries) {
      add(e.squadId, s.key, e.paidBy, s.value);
    }
  }
  for (final s in settlements) {
    add(s.squadId, s.to, s.from, s.amountCents);
  }
  return out;
}

/// The fewest payments that settle [net] (positive: owed money).
/// Deterministic: biggest amounts first, ties by id.
List<SettlementItem> simplifyDebts(Map<String, int> net, {String? squadId}) {
  final creditors = [
    for (final e in net.entries)
      if (e.value > 0) [e.key, e.value],
  ];
  final debtors = [
    for (final e in net.entries)
      if (e.value < 0) [e.key, -e.value],
  ];
  int byAmount(List<Object> a, List<Object> b) {
    final c = (b[1] as int).compareTo(a[1] as int);
    return c != 0 ? c : (a[0] as String).compareTo(b[0] as String);
  }

  final out = <SettlementItem>[];
  while (creditors.isNotEmpty && debtors.isNotEmpty) {
    creditors.sort(byAmount);
    debtors.sort(byAmount);
    final c = creditors.first;
    final d = debtors.first;
    final amount = math.min(c[1] as int, d[1] as int);
    out.add(
      SettlementItem(
        squadId: squadId,
        from: d[0] as String,
        to: c[0] as String,
        amountCents: amount,
      ),
    );
    c[1] = (c[1] as int) - amount;
    d[1] = (d[1] as int) - amount;
    if (c[1] == 0) creditors.remove(c);
    if (d[1] == 0) debtors.remove(d);
  }
  return out;
}

/// Each person's net in [scope]'s raw debts: positive means owed money.
Map<String, int> _net(Map<(String, String), int> debts) {
  final net = <String, int>{};
  for (final e in debts.entries) {
    final (debtor, creditor) = e.key;
    net[creditor] = (net[creditor] ?? 0) + e.value;
    net[debtor] = (net[debtor] ?? 0) - e.value;
  }
  return net;
}

/// What's owed between [me] and each friend, per scope: positive means the
/// friend owes [me]. Squads in [simplified] use their simplified payments.
Map<String, Map<String?, int>> balancesByScope({
  required String me,
  required Iterable<SharedExpense> expenses,
  required Iterable<Settlement> settlements,
  Set<String> simplified = const {},
}) {
  final out = <String, Map<String?, int>>{};
  void add(String friend, String? scope, int cents) {
    if (cents == 0) return;
    final m = out.putIfAbsent(friend, () => {});
    m[scope] = (m[scope] ?? 0) + cents;
  }

  for (final MapEntry(key: scope, value: debts) in _rawDebts(
    expenses,
    settlements,
  ).entries) {
    final edges = scope != null && simplified.contains(scope)
        ? {
            for (final p in simplifyDebts(_net(debts), squadId: scope))
              (p.from, p.to): p.amountCents,
          }
        : debts;
    for (final MapEntry(key: (debtor, creditor), value: cents)
        in edges.entries) {
      if (creditor == me) add(debtor, scope, cents);
      if (debtor == me) add(creditor, scope, -cents);
    }
  }
  out.removeWhere((_, scopes) {
    scopes.removeWhere((_, v) => v == 0);
    return scopes.isEmpty;
  });
  return out;
}

/// The overall balance with each friend: positive means they owe [me].
Map<String, int> balances({
  required String me,
  required Iterable<SharedExpense> expenses,
  required Iterable<Settlement> settlements,
  Set<String> simplified = const {},
}) => {
  for (final e in balancesByScope(
    me: me,
    expenses: expenses,
    settlements: settlements,
    simplified: simplified,
  ).entries)
    e.key: e.value.values.fold(0, (a, b) => a + b),
}..removeWhere((_, v) => v == 0);

/// The settle-ups that record [amountCents] paid between [me] and
/// [friend] (in whichever direction is owed), spread over the scopes the
/// debt is in, biggest first. Null [amountCents] settles everything,
/// including scopes where the debt runs the other way.
List<SettlementItem> settleUp({
  required String me,
  required String friend,
  required Map<String?, int> byScope,
  int? amountCents,
}) {
  final net = byScope.values.fold(0, (a, b) => a + b);
  SettlementItem item(String? scope, int signed) => signed > 0
      ? SettlementItem(
          squadId: scope,
          from: friend,
          to: me,
          amountCents: signed,
        )
      : SettlementItem(
          squadId: scope,
          from: me,
          to: friend,
          amountCents: -signed,
        );
  if (amountCents == null) {
    return [
      for (final e in byScope.entries)
        if (e.value != 0) item(e.key, e.value),
    ];
  }
  if (net == 0 || amountCents <= 0) return const [];
  final sign = net.sign;
  final scopes = byScope.entries.where((e) => e.value.sign == sign).toList()
    ..sort((a, b) => b.value.abs().compareTo(a.value.abs()));
  var left = math.min(amountCents, net.abs());
  final out = <SettlementItem>[];
  for (final e in scopes) {
    if (left == 0) break;
    final take = math.min(left, e.value.abs());
    out.add(item(e.key, take * sign));
    left -= take;
  }
  return out;
}
