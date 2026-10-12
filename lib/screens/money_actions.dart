import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../app/format.dart';
import '../app/models.dart';
import '../widgets/action_sheet.dart';
import '../widgets/ph_icons.dart';
import 'quick_add_sheet.dart';

enum _CostAction { pay, delete, stop }

enum _IncomeAction { stop, delete }

enum _ExpenseAction { edit, delete }

/// Edit an expense in the Quick Add sheet, or delete it with an Undo bar.
/// [bottomInset] lifts the bar clear of anything floating at the bottom,
/// like the nav bar.
Future<void> showExpenseActions(
  BuildContext context,
  Expense expense, {
  double bottomInset = 16,
}) async {
  final state = AppScope.read(context);
  final messenger = ScaffoldMessenger.of(context);
  final choice = await showActionSheet<_ExpenseAction>(
    context,
    title: '${expense.title} · ${money(expense.amount)}',
    message: relativeDay(expense.date, state.today),
    actions: const [
      SheetAction(
        value: _ExpenseAction.edit,
        label: 'Edit',
        icon: PhIcons.notePencil,
      ),
      SheetAction(
        value: _ExpenseAction.delete,
        label: 'Delete expense',
        icon: PhIcons.trash,
        destructive: true,
      ),
    ],
  );
  if (!context.mounted) return;
  switch (choice) {
    case _ExpenseAction.edit:
      await showQuickAddSheet(context, editing: expense);
    case _ExpenseAction.delete:
      final removed = state.deleteExpense(expense.id);
      if (removed == null) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Deleted ${removed.title}'),
            margin: EdgeInsets.fromLTRB(16, 0, 16, bottomInset),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () => state.restoreExpense(removed),
            ),
          ),
        );
    case null:
  }
}

/// Mark an upcoming cost paid, or delete it. A monthly bill can also be
/// stopped, which removes this month and every later one.
Future<void> showCostActions(BuildContext context, UpcomingCost cost) async {
  final state = AppScope.read(context);
  final choice = await showActionSheet<_CostAction>(
    context,
    title: '${cost.name} · ${money(cost.amount)}',
    message:
        'Marking it paid logs it as a bill. Your daily budget stays '
        'the same: this money was already set aside.',
    actions: [
      const SheetAction(
        value: _CostAction.pay,
        label: 'Mark as paid',
        icon: PhIcons.checkCircle,
      ),
      SheetAction(
        value: _CostAction.delete,
        label: cost.repeats ? 'Skip just this month' : 'Delete cost',
        icon: PhIcons.trash,
        destructive: !cost.repeats,
      ),
      if (cost.repeats)
        const SheetAction(
          value: _CostAction.stop,
          label: 'Stop this bill',
          icon: PhIcons.stopCircle,
          destructive: true,
        ),
    ],
  );
  switch (choice) {
    case _CostAction.pay:
      state.payUpcomingCost(cost.id);
    case _CostAction.delete:
      state.deleteUpcomingCost(cost.id);
    case _CostAction.stop:
      state.deleteUpcomingCost(cost.id, andLater: true);
    case null:
  }
}

/// Stop a repeating income, or delete it.
Future<void> showIncomeActions(BuildContext context, Income income) async {
  final state = AppScope.read(context);
  final stoppable = income.repeats && income.endsOn == null;
  final choice = await showActionSheet<_IncomeAction>(
    context,
    title: '${income.name} · ${money(income.amount)}',
    message: stoppable
        ? 'Stopping keeps the paydays you already got. Deleting removes '
              'every payment, as if it was never added.'
        : 'Deleting removes this money from your budget.',
    actions: [
      if (stoppable)
        const SheetAction(
          value: _IncomeAction.stop,
          label: 'Stop future paydays',
          icon: PhIcons.stopCircle,
        ),
      const SheetAction(
        value: _IncomeAction.delete,
        label: 'Delete',
        icon: PhIcons.trash,
        destructive: true,
      ),
    ],
  );
  switch (choice) {
    case _IncomeAction.stop:
      state.stopIncome(income.id);
    case _IncomeAction.delete:
      state.deleteIncome(income.id);
    case null:
  }
}
