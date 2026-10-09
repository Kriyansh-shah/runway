/// An Apple Pay purchase handed over by an iOS Shortcuts "Transaction"
/// automation, which opens `runway://log?amount=<Amount>&merchant=<Merchant>`.
///
/// Shortcuts formats the amount for the phone's locale ("$4.50", "4,50 €",
/// "1,234.56") and occasionally sends it blank or as zero, so [amount] is null
/// whenever it can't be trusted and the user types it instead.
class ApplePayPurchase {
  const ApplePayPurchase({this.amount, this.merchant});

  final double? amount;
  final String? merchant;

  /// Null if [uri] isn't a Runway log link.
  static ApplePayPurchase? fromUri(Uri uri) {
    if (uri.scheme != 'runway' || uri.host != 'log') return null;
    final merchant = uri.queryParameters['merchant']?.trim();
    return ApplePayPurchase(
      amount: parseAmount(uri.queryParameters['amount']),
      merchant: merchant == null || merchant.isEmpty ? null : merchant,
    );
  }

  /// "$4.50" → 4.5, "1,234.56" → 1234.56, "4,50 €" → 4.5, "0" → null.
  static double? parseAmount(String? raw) {
    if (raw == null) return null;
    var s = raw.replaceAll(RegExp(r'[^0-9.,]'), '');
    final dot = s.lastIndexOf('.');
    final comma = s.lastIndexOf(',');
    if (dot >= 0 && comma >= 0) {
      // Whichever separator comes last is the decimal point.
      s = dot > comma
          ? s.replaceAll(',', '')
          : s.replaceAll('.', '').replaceAll(',', '.');
    } else if (comma >= 0) {
      // "4,50" is a decimal comma; "1,234" is a thousands separator.
      final decimals = s.length - comma - 1;
      s = decimals == 2 && s.indexOf(',') == comma
          ? s.replaceAll(',', '.')
          : s.replaceAll(',', '');
    }
    final value = double.tryParse(s);
    if (value == null || value <= 0 || value >= 100000) return null;
    return (value * 100).round() / 100;
  }
}
