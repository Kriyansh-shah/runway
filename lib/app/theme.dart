import 'package:flutter/material.dart';

/// "Lime & Lilac": warm charcoal, one electric lime for action, lilac for
/// personality. Glow is used sparingly (main button, ring, nav pill).
abstract final class AppColors {
  static const bg = Color(0xFF0D0D10);
  static const surface = Color(0xFF18181D);
  static const text = Color(0xFFF4F4F1);
  static const muted = Color(0xFF8E8E99);

  /// Main accent: buttons, ring, active tab, "good" states.
  static const lime = Color(0xFFC6FF3D);

  /// Dark ink for text and icons sitting on lime.
  static const onLime = Color(0xFF0D0D10);

  /// Second accent: Mochi, highlights, selected chips.
  static const lilac = Color(0xFFB9A4FF);
  static const pink = Color(0xFFFF9BD6);

  /// Caution ("trade for it") and problems ("14 days short").
  static const butter = Color(0xFFFFD66B);
  static const red = Color(0xFFFF6B6B);

  static const need = Color(0xFF8FD3FF);
  static const want = pink;

  static final glass = Colors.white.withValues(alpha: 0.055);
  static final glassStrong = Colors.white.withValues(alpha: 0.09);
  static final hairline = Colors.white.withValues(alpha: 0.10);
}

abstract final class AppGradients {
  /// Main call-to-action: lime with a slight sheen. Text on it is [AppColors.onLime].
  static const brand = LinearGradient(
    colors: [Color(0xFFD6FF70), AppColors.lime],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Personality: lilac → pink (avatars, chat bubbles, sign out).
  static const hot = LinearGradient(
    colors: [AppColors.lilac, AppColors.pink],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Success / settled.
  static const good = brand;
}

/// Shared motion tokens so every animation feels like the same app.
abstract final class Motion {
  static const fast = Duration(milliseconds: 180);
  static const med = Duration(milliseconds: 320);
  static const slow = Duration(milliseconds: 650);

  static const out = Curves.easeOutCubic;
  static const spring = Curves.easeOutBack;
  static const roll = Curves.easeOutExpo;

  /// Delay between items in a staggered entrance.
  static const stagger = Duration(milliseconds: 60);

  /// Bouncy-but-quick spring for press release and small pops.
  static const pressSpring = SpringDescription(
    mass: 1,
    stiffness: 520,
    damping: 20,
  );

  /// True when the phone asks for reduced motion (Accessibility setting).
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}

abstract final class AppText {
  static const _tabular = [FontFeature.tabularFigures()];

  static const display = TextStyle(
    fontSize: 52,
    fontWeight: FontWeight.w800,
    letterSpacing: -2.2,
    height: 1.0,
    color: AppColors.text,
    fontFeatures: _tabular,
  );
  static const number = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.8,
    color: AppColors.text,
    fontFeatures: _tabular,
  );
  static const title = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.0,
    color: AppColors.text,
  );
  static const heading = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    color: AppColors.text,
  );
  static const body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.2,
    color: AppColors.text,
  );
  static const label = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    color: AppColors.muted,
  );
  static const caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.4,
    color: AppColors.muted,
    fontFeatures: _tabular,
  );
}

ThemeData buildTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.lime,
      onPrimary: AppColors.onLime,
      secondary: AppColors.lilac,
      surface: AppColors.surface,
      error: AppColors.red,
      onSurface: AppColors.text,
    ),
  );
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF26262E),
      contentTextStyle: AppText.body,
      actionTextColor: AppColors.lime,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppColors.hairline),
      ),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.lime,
      selectionColor: Color(0x55B9A4FF),
      selectionHandleColor: AppColors.lilac,
    ),
  );
}
