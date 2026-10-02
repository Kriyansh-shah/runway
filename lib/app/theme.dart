import 'package:flutter/material.dart';

/// Brand palette. Dark + neon.
abstract final class AppColors {
  static const bg = Color(0xFF07070D);
  static const surface = Color(0xFF11111B);
  static const text = Color(0xFFF5F5FA);
  static const muted = Color(0xFF8C8CA6);

  static const violet = Color(0xFF8B6CFF);
  static const cyan = Color(0xFF2EE6FF);
  static const pink = Color(0xFFFF4FB8);
  static const mint = Color(0xFF3DFFA8);
  static const amber = Color(0xFFFFB547);
  static const coral = Color(0xFFFF5C7A);

  static const need = cyan;
  static const want = pink;

  static final glass = Colors.white.withValues(alpha: 0.07);
  static final glassStrong = Colors.white.withValues(alpha: 0.10);
  static final hairline = Colors.white.withValues(alpha: 0.12);
}

abstract final class AppGradients {
  static const brand = LinearGradient(
    colors: [AppColors.violet, AppColors.cyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const hot = LinearGradient(
    colors: [AppColors.pink, AppColors.violet],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const good = LinearGradient(
    colors: [AppColors.mint, AppColors.cyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
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
      primary: AppColors.violet,
      secondary: AppColors.cyan,
      surface: AppColors.surface,
      error: AppColors.coral,
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
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.cyan,
    ),
  );
}
