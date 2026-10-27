/// Turns something said out loud ("I spent 8 bucks on coffee", "$12 at
/// Chipotle") into an expense: how much, what it was, and a best guess at
/// the category. Used by the mic in Quick Add and by expenses logged
/// through Siri.
library;

import 'models.dart';

class SpokenExpense {
  const SpokenExpense({this.amount, this.note});

  /// Null if no amount was heard, so the person types it instead.
  final double? amount;

  /// What it was, cleaned up: "Chipotle", "Coffee". Null if nothing's left
  /// once the amount and filler words are taken out.
  final String? note;

  static SpokenExpense parse(String said) {
    final words = said
        .replaceAll(RegExp(r'[!?;]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    final found = _digitAmount(words) ?? _wordAmount(words);
    if (found != null) words.removeRange(found.start, found.end);
    return SpokenExpense(amount: found?.amount, note: _note(words));
  }

  /// A category for [note]: one of the person's own [customs] if its name
  /// is in there, else a built-in one from familiar words and places, else
  /// null.
  static CategoryRef? guessCategory(
    String? note,
    List<CustomCategory> customs,
  ) {
    if (note == null) return null;
    final text = ' ${_plain(note)} ';
    for (final c in customs) {
      if (text.contains(' ${_plain(c.name)} ')) {
        return CategoryRef(ExpenseCategory.other, c);
      }
    }
    for (final MapEntry(key: category, value: words) in _keywords.entries) {
      if (words.any((w) => text.contains(' $w '))) return CategoryRef(category);
    }
    return null;
  }

  /// Whether [category] is usually something you need rather than want.
  static bool isNeed(ExpenseCategory category) => switch (category) {
    ExpenseCategory.groceries ||
    ExpenseCategory.transit ||
    ExpenseCategory.supplies ||
    ExpenseCategory.bills => true,
    _ => false,
  };
}

typedef _Found = ({int start, int end, double amount});

/// "$4.50", "12 dollars", "12.50", "20 bucks and 50 cents", "1,200".
_Found? _digitAmount(List<String> words) {
  final number = RegExp(r'^\$?(\d{1,3}(?:,\d{3})+|\d+)(?:\.(\d{1,2}))?$');
  for (var i = 0; i < words.length; i++) {
    final m = number.firstMatch(_trimPunctuation(words[i]));
    if (m == null) continue;
    var cents = m.group(2) == null
        ? 0
        : int.parse(m.group(2)!.padRight(2, '0'));
    var end = i + 1;
    if (end < words.length && _isCurrency(words[end])) end++;
    // "and 50 cents"
    if (end + 2 < words.length &&
        words[end].toLowerCase() == 'and' &&
        RegExp(r'^\d{1,2}$').hasMatch(words[end + 1]) &&
        _plain(words[end + 2]).startsWith('cent')) {
      cents = int.parse(words[end + 1]);
      end += 3;
    }
    final dollars = int.parse(m.group(1)!.replaceAll(',', ''));
    final amount = dollars + cents / 100;
    if (amount <= 0 || amount >= 100000) continue;
    return (start: i, end: end, amount: amount);
  }
  return null;
}

/// "twelve dollars", "forty five bucks", "a hundred and twenty dollars".
/// Only counted when "dollars" or "bucks" follows, so "two coffees" stays
/// a note.
_Found? _wordAmount(List<String> words) {
  for (var i = 0; i < words.length; i++) {
    var j = i;
    var total = 0;
    var current = 0;
    var any = false;
    while (j < words.length) {
      final w = _plain(words[j]);
      if (_ones.containsKey(w)) {
        current += _ones[w]!;
      } else if (_tens.containsKey(w)) {
        current += _tens[w]!;
      } else if (w == 'hundred') {
        current = (current == 0 ? 1 : current) * 100;
      } else if (w == 'thousand') {
        total += (current == 0 ? 1 : current) * 1000;
        current = 0;
      } else if ((w == 'and' || w == 'a') && j + 1 < words.length) {
        // "a hundred", "hundred and twenty"
      } else {
        break;
      }
      if (w != 'and' && w != 'a') any = true;
      j++;
    }
    if (!any || j >= words.length || !_isCurrency(words[j])) continue;
    final amount = (total + current).toDouble();
    if (amount <= 0 || amount >= 100000) continue;
    return (start: i, end: j + 1, amount: amount);
  }
  return null;
}

/// What's left once the amount is gone, minus "I spent ... on" and the like.
String? _note(List<String> words) {
  final kept = [for (final w in words) _trimPunctuation(w)]
    ..removeWhere((w) => w.isEmpty);
  while (kept.isNotEmpty && _filler.contains(_plain(kept.first))) {
    kept.removeAt(0);
  }
  while (kept.isNotEmpty && _filler.contains(_plain(kept.last))) {
    kept.removeLast();
  }
  if (kept.isEmpty) return null;
  final note = kept.join(' ');
  return note[0].toUpperCase() + note.substring(1);
}

bool _isCurrency(String word) =>
    const {'dollar', 'dollars', 'buck', 'bucks', 'usd'}.contains(_plain(word));

String _trimPunctuation(String w) =>
    w.replaceAll(RegExp(r'^[^\w$]+|[^\w]+$'), '');

String _plain(String s) =>
    s.toLowerCase().replaceAll(RegExp(r"[^a-z0-9' ]"), '').trim();

const _filler = {
  'i',
  "i've",
  'just',
  'spent',
  'spend',
  'paid',
  'pay',
  'log',
  'add',
  'an',
  'a',
  'expense',
  'of',
  'for',
  'on',
  'at',
  'to',
  'in',
  'the',
  'and',
  'was',
  'it',
  'today',
  'runway',
};

const _ones = {
  'one': 1,
  'two': 2,
  'three': 3,
  'four': 4,
  'five': 5,
  'six': 6,
  'seven': 7,
  'eight': 8,
  'nine': 9,
  'ten': 10,
  'eleven': 11,
  'twelve': 12,
  'thirteen': 13,
  'fourteen': 14,
  'fifteen': 15,
  'sixteen': 16,
  'seventeen': 17,
  'eighteen': 18,
  'nineteen': 19,
};

const _tens = {
  'twenty': 20,
  'thirty': 30,
  'forty': 40,
  'fifty': 50,
  'sixty': 60,
  'seventy': 70,
  'eighty': 80,
  'ninety': 90,
};

/// Checked in order, so "uber eats" lands in Delivery before "uber" can
/// make it a ride.
const _keywords = {
  ExpenseCategory.delivery: [
    'doordash',
    'door dash',
    'uber eats',
    'ubereats',
    'grubhub',
    'postmates',
    'instacart',
    'delivery',
    'amazon',
  ],
  ExpenseCategory.coffee: [
    'coffee',
    'starbucks',
    'dunkin',
    'latte',
    'cafe',
    'espresso',
    'boba',
    'tea',
    'matcha',
  ],
  ExpenseCategory.groceries: [
    'groceries',
    'grocery',
    'trader joe\'s',
    'trader joes',
    'whole foods',
    'aldi',
    'costco',
    'safeway',
    'kroger',
    'publix',
    'wegmans',
    'supermarket',
  ],
  ExpenseCategory.rideshare: ['uber', 'lyft', 'taxi', 'cab', 'ride'],
  ExpenseCategory.transit: [
    'subway',
    'metro',
    'bus',
    'train',
    'transit',
    'gas',
    'parking',
    'metrocard',
  ],
  ExpenseCategory.lateNight: ['late night', 'pizza', 'wings'],
  ExpenseCategory.eatingOut: [
    'lunch',
    'dinner',
    'breakfast',
    'brunch',
    'restaurant',
    'food',
    'chipotle',
    'mcdonald\'s',
    'mcdonalds',
    'chick-fil-a',
    'chick fil a',
    'taco bell',
    'burger',
    'sushi',
    'sweetgreen',
    'panera',
    'wendy\'s',
  ],
  ExpenseCategory.supplies: [
    'textbook',
    'textbooks',
    'book',
    'books',
    'notebook',
    'supplies',
    'printing',
    'calculator',
  ],
  ExpenseCategory.travel: ['flight', 'hotel', 'airbnb', 'trip', 'airline'],
  ExpenseCategory.bills: [
    'rent',
    'bill',
    'electric',
    'internet',
    'phone bill',
    'netflix',
    'spotify',
    'subscription',
    'insurance',
  ],
  ExpenseCategory.fun: [
    'movie',
    'movies',
    'concert',
    'tickets',
    'ticket',
    'game',
    'games',
    'bar',
    'drinks',
    'party',
  ],
  ExpenseCategory.shopping: [
    'clothes',
    'shoes',
    'target',
    'walmart',
    'shopping',
    'hoodie',
    'shirt',
    'mall',
  ],
};
