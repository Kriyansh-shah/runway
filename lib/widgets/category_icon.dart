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

class CategoryIcon extends StatelessWidget {
  const CategoryIcon(
    this.category, {
    super.key,
    this.size = 20,
    this.color = AppColors.lilac,
  });

  final ExpenseCategory category;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
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
