import 'package:flutter_test/flutter_test.dart';
import 'package:runway/app/models.dart';
import 'package:runway/app/spoken_expense.dart';

void main() {
  group('Spoken expense', () {
    void heard(String said, double? amount, String? note) {
      final s = SpokenExpense.parse(said);
      expect(s.amount, amount, reason: said);
      expect(s.note, note, reason: said);
    }

    test('reads digits, dollars and filler words', () {
      heard('\$12 at Chipotle', 12, 'Chipotle');
      heard('I spent 8 bucks on coffee', 8, 'Coffee');
      heard('4.50 coffee', 4.5, 'Coffee');
      heard('Uber to the airport \$23.40', 23.4, 'Uber to the airport');
      heard('textbook for 1,200 dollars', 1200, 'Textbook');
      heard('20 dollars and 50 cents for groceries', 20.5, 'Groceries');
    });

    test('reads amounts said as words', () {
      heard('twelve dollars lunch', 12, 'Lunch');
      heard('forty five bucks on shoes', 45, 'Shoes');
      heard('a hundred and twenty dollars for rent', 120, 'Rent');
    });

    test('leaves the amount empty when none was said', () {
      heard('two coffees', null, 'Two coffees');
      heard('spent nothing', null, 'Nothing');
      heard('', null, null);
    });

    test('guesses a category, own categories first', () {
      const vape = CustomCategory(id: 'c1', emoji: '💨', name: 'Vape');
      CategoryRef? guess(String note) =>
          SpokenExpense.guessCategory(note, const [vape]);
      expect(guess('Chipotle')?.category, ExpenseCategory.eatingOut);
      expect(guess('Uber Eats')?.category, ExpenseCategory.delivery);
      expect(guess('Uber to the airport')?.category, ExpenseCategory.rideshare);
      expect(guess('Trader Joe’s')?.category, ExpenseCategory.groceries);
      expect(guess('vape pods')?.custom, vape);
      expect(guess('Something odd'), isNull);
    });
  });
}
