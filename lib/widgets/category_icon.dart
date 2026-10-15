import 'package:flutter/widgets.dart';

import '../app/models.dart';
import '../app/theme.dart';
import 'ph_icons.dart';

/// Two-tone (Phosphor duotone) icon for an expense category. Unlike emoji,
/// these look identical on iPhone, Android and Mac.
DuotoneIconData categoryIconData(ExpenseCategory c) => switch (c) {
  ExpenseCategory.coffee => PhDuotone.coffee,
  ExpenseCategory.groceries => PhDuotone.shoppingCart,
  ExpenseCategory.transit => PhDuotone.train,
  ExpenseCategory.lateNight => PhDuotone.pizza,
  ExpenseCategory.delivery => PhDuotone.package,
  ExpenseCategory.supplies => PhDuotone.books,
  ExpenseCategory.rideshare => PhDuotone.taxi,
  ExpenseCategory.travel => PhDuotone.airplaneTilt,
  ExpenseCategory.eatingOut => PhDuotone.hamburger,
  ExpenseCategory.shopping => PhDuotone.shoppingBag,
  ExpenseCategory.fun => PhDuotone.confetti,
  ExpenseCategory.bills => PhDuotone.receipt,
  ExpenseCategory.other => PhDuotone.wallet,
};

/// A built-in category's duotone icon, or a custom category's emoji.
class CategoryIcon extends StatelessWidget {
  const CategoryIcon(
    this.category, {
    super.key,
    this.custom,
    this.size = 20,
    this.color = AppColors.lilac,
  });

  /// The icon an expense is shown with.
  CategoryIcon.of(Expense expense, {Key? key, double size = 20})
    : this(expense.category, key: key, custom: expense.custom, size: size);

  final ExpenseCategory category;
  final CustomCategory? custom;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (custom case final custom?) {
      return Semantics(
        label: custom.name,
        child: ExcludeSemantics(
          child: SizedBox.square(
            dimension: size,
            child: OverflowBox(
              maxWidth: size * 1.4,
              maxHeight: size * 1.4,
              child: Text(
                custom.emoji,
                style: TextStyle(fontSize: size, height: 1),
              ),
            ),
          ),
        ),
      );
    }
    final icon = categoryIconData(category);
    return Semantics(
      label: category.label,
      child: ExcludeSemantics(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              icon.secondary,
              size: size,
              color: color.withValues(alpha: 0.32),
            ),
            Icon(icon.primary, size: size, color: color),
          ],
        ),
      ),
    );
  }
}
