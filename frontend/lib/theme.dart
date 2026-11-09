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

/// Цвета мышечных групп для точек календаря и пометок.
const muscleGroupColors = <String, Color>{
  'chest': Color(0xFFFF4D5E),
  'arms': Color(0xFFFF9F1C),
  'back': Color(0xFF29B6FF),
  'legs': Color(0xFF39FF88),
  'shoulders': Color(0xFFC77DFF),
  'core': Color(0xFFFFE600),
  'full_body': Color(0xFF00FFC8),
  'cardio': Color(0xFF00E5FF),
};

Color muscleGroupColor(String code) =>
    muscleGroupColors[code] ?? AppColors.textDim;

class AppTheme {
  static ThemeData dark({Color accent = AppColors.accentOrange}) {
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
