import 'package:flutter_test/flutter_test.dart';
import 'package:runway/app/purchase_link.dart';

void main() {
  group('Apple Pay link', () {
    test('reads amount and merchant', () {
      final p = ApplePayPurchase.fromUri(
        Uri.parse(
          'runway://log?amount=%246.45&merchant=Blue%20Bottle%20Coffee',
        ),
      )!;
      expect(p.amount, 6.45);
      expect(p.merchant, 'Blue Bottle Coffee');
    });

    test('ignores links that are not runway://log', () {
      expect(ApplePayPurchase.fromUri(Uri.parse('runway://home')), isNull);
      expect(
        ApplePayPurchase.fromUri(Uri.parse('https://log?amount=4')),
        isNull,
      );
    });

    test('blank merchant and zero amount become null, not wrong values', () {
      final p = ApplePayPurchase.fromUri(
        Uri.parse('runway://log?amount=%240.00&merchant=%20'),
      )!;
      expect(p.amount, isNull);
      expect(p.merchant, isNull);
      expect(
        ApplePayPurchase.fromUri(Uri.parse('runway://log'))!.amount,
        isNull,
      );
    });

    test('understands the ways Shortcuts formats money', () {
      expect(ApplePayPurchase.parseAmount(r'$4.50'), 4.5);
      expect(ApplePayPurchase.parseAmount('US\$12'), 12);
      expect(ApplePayPurchase.parseAmount(r'$1,234.56'), 1234.56);
      expect(ApplePayPurchase.parseAmount('1,234'), 1234);
      expect(ApplePayPurchase.parseAmount('4,50 €'), 4.5);
      expect(ApplePayPurchase.parseAmount('1.234,56 €'), 1234.56);
      expect(ApplePayPurchase.parseAmount('£3.999'), 4.0);
      expect(ApplePayPurchase.parseAmount('free'), isNull);
      expect(ApplePayPurchase.parseAmount('250000'), isNull);
    });
  });
}
