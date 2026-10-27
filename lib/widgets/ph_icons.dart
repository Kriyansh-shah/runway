// Phosphor icons (MIT, https://phosphoricons.com), used straight from the
// bundled icon fonts in assets/fonts/phosphor. Only the icons Runway uses are
// listed; add more by copying codepoints from phosphor's icon list.
// ignore_for_file: constant_identifier_names
import 'package:flutter/widgets.dart';

abstract final class PhIcons {
  static const house = IconData(0xe2c2, fontFamily: 'PhosphorRegular');
  static const piggyBank = IconData(0xea04, fontFamily: 'PhosphorRegular');
  static const sparkle = IconData(0xe6a2, fontFamily: 'PhosphorRegular');
  static const usersThree = IconData(0xe68e, fontFamily: 'PhosphorRegular');
  static const at = IconData(0xe0ac, fontFamily: 'PhosphorRegular');
  static const backspace = IconData(0xe0ae, fontFamily: 'PhosphorRegular');
  static const notePencil = IconData(0xe34c, fontFamily: 'PhosphorRegular');
  static const microphone = IconData(0xe326, fontFamily: 'PhosphorRegular');
  static const warningCircle = IconData(0xe4e2, fontFamily: 'PhosphorRegular');
  static const lock = IconData(0xe2fa, fontFamily: 'PhosphorRegular');
  static const signOut = IconData(0xe42a, fontFamily: 'PhosphorRegular');
  static const user = IconData(0xe4c2, fontFamily: 'PhosphorRegular');
  static const eye = IconData(0xe220, fontFamily: 'PhosphorRegular');
  static const eyeSlash = IconData(0xe224, fontFamily: 'PhosphorRegular');
  static const gearSix = IconData(0xe272, fontFamily: 'PhosphorRegular');
  static const caretRight = IconData(0xe13a, fontFamily: 'PhosphorRegular');
  static const trash = IconData(0xe4a6, fontFamily: 'PhosphorRegular');
  static const checkCircle = IconData(0xe184, fontFamily: 'PhosphorRegular');
  static const handCoins = IconData(0xea8c, fontFamily: 'PhosphorRegular');
  static const repeat = IconData(0xe3f6, fontFamily: 'PhosphorRegular');
  static const stopCircle = IconData(0xe46e, fontFamily: 'PhosphorRegular');
  static const calendarBlank = IconData(0xe10a, fontFamily: 'PhosphorRegular');
  static const clockCounterClockwise = IconData(
    0xe1a0,
    fontFamily: 'PhosphorRegular',
  );
  static const houseFill = IconData(0xe2c2, fontFamily: 'PhosphorFill');
  static const piggyBankFill = IconData(0xea04, fontFamily: 'PhosphorFill');
  static const sparkleFill = IconData(0xe6a2, fontFamily: 'PhosphorFill');
  static const usersThreeFill = IconData(0xe68e, fontFamily: 'PhosphorFill');
  static const plusBold = IconData(0xe3d4, fontFamily: 'PhosphorBold');
  static const arrowRightBold = IconData(0xe06c, fontFamily: 'PhosphorBold');
  static const arrowUpBold = IconData(0xe08e, fontFamily: 'PhosphorBold');
  static const checkBold = IconData(0xe182, fontFamily: 'PhosphorBold');
  static const xBold = IconData(0xe4f6, fontFamily: 'PhosphorBold');
  static const caretLeftBold = IconData(0xe138, fontFamily: 'PhosphorBold');
}

/// A two-tone icon: [primary] drawn on top of a faded [secondary] fill.
class DuotoneIconData {
  const DuotoneIconData(this.primary, this.secondary);
  final IconData primary;
  final IconData secondary;
}

abstract final class PhDuotone {
  static const coffee = DuotoneIconData(
    IconData(0xe1c3, fontFamily: 'PhosphorDuotone'),
    IconData(0xe1c2, fontFamily: 'PhosphorDuotone'),
  );
  static const shoppingCart = DuotoneIconData(
    IconData(0xe41f, fontFamily: 'PhosphorDuotone'),
    IconData(0xe41e, fontFamily: 'PhosphorDuotone'),
  );
  static const train = DuotoneIconData(
    IconData(0xe497, fontFamily: 'PhosphorDuotone'),
    IconData(0xe496, fontFamily: 'PhosphorDuotone'),
  );
  static const pizza = DuotoneIconData(
    IconData(0xe797, fontFamily: 'PhosphorDuotone'),
    IconData(0xe796, fontFamily: 'PhosphorDuotone'),
  );
  static const package = DuotoneIconData(
    IconData(0xe391, fontFamily: 'PhosphorDuotone'),
    IconData(0xe390, fontFamily: 'PhosphorDuotone'),
  );
  static const books = DuotoneIconData(
    IconData(0xe759, fontFamily: 'PhosphorDuotone'),
    IconData(0xe758, fontFamily: 'PhosphorDuotone'),
  );
  static const taxi = DuotoneIconData(
    IconData(0xe903, fontFamily: 'PhosphorDuotone'),
    IconData(0xe902, fontFamily: 'PhosphorDuotone'),
  );
  static const airplaneTilt = DuotoneIconData(
    IconData(0xe5d7, fontFamily: 'PhosphorDuotone'),
    IconData(0xe5d6, fontFamily: 'PhosphorDuotone'),
  );
  static const hamburger = DuotoneIconData(
    IconData(0xe791, fontFamily: 'PhosphorDuotone'),
    IconData(0xe790, fontFamily: 'PhosphorDuotone'),
  );
  static const shoppingBag = DuotoneIconData(
    IconData(0xe417, fontFamily: 'PhosphorDuotone'),
    IconData(0xe416, fontFamily: 'PhosphorDuotone'),
  );
  static const confetti = DuotoneIconData(
    IconData(0xe81b, fontFamily: 'PhosphorDuotone'),
    IconData(0xe81a, fontFamily: 'PhosphorDuotone'),
  );
  static const receipt = DuotoneIconData(
    IconData(0xe3f1, fontFamily: 'PhosphorDuotone'),
    IconData(0xe3ec, fontFamily: 'PhosphorDuotone'),
  );
  static const wallet = DuotoneIconData(
    IconData(0xe68b, fontFamily: 'PhosphorDuotone'),
    IconData(0xe68a, fontFamily: 'PhosphorDuotone'),
  );
}
