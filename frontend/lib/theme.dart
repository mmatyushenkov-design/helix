import 'package:flutter/material.dart';

/// Палитра и тема, перенесённые из утверждённого HTML-макета.
class AppColors {
  static const bg = Color(0xFF121212);
  static const surface = Color(0xFF1E1E1E);
  static const surface2 = Color(0xFF262626);
  static const border = Color(0xFF333333);
  static const text = Color(0xFFEAEAEA);
  static const textDim = Color(0xFF9E9E9E);

  /// Акцентные цвета на выбор (как в настройках макета).
  static const accentGreen = Color(0xFF3FBF7F);
  static const accentBlue = Color(0xFF4D9FD1);
  static const accentOrange = Color(0xFFD98A3D);
  static const accentPurple = Color(0xFF9C6BC0);
  static const accentRed = Color(0xFFC9504C);

  /// Приглушённый фон панели подходов / бейджей (accent 18%).
  static Color accentDim(Color accent) => accent.withValues(alpha: 0.18);
}

class AppTheme {
  static ThemeData dark({Color accent = AppColors.accentGreen}) {
    final scheme = ColorScheme.dark(
      primary: accent,
      surface: AppColors.surface,
      onSurface: AppColors.text,
      outline: AppColors.border,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.bg,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.text,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
            fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.text),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.accentDim(accent),
        labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12)),
      ),
    );
  }
}
