import 'package:flutter/material.dart';

/// Bright, playful palette aimed at young learners, reused across the
/// gamified student app and (in a calmer variant) the CMS/dashboards.
class AppColors {
  static const primary = Color(0xFF2F80ED);
  static const secondary = Color(0xFFF2994A);
  static const success = Color(0xFF27AE60);
  static const error = Color(0xFFEB5757);
  static const background = Color(0xFFFAF9F6);
  static const points = Color(0xFFF2C94C);
}

class AppTheme {
  static ThemeData get studentTheme {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        secondary: AppColors.secondary,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Roboto',
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(fontSizeFactor: 1.05),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  static ThemeData get adminTheme {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF34495E)),
    );
    return base;
  }
}
