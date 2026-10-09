import 'package:flutter/material.dart';

/// Colour tokens for the minimalist dark-neon "Cyber Vault" look.
class AppColors {
  AppColors._();

  static const Color background = Color(0xFF070A10);
  static const Color surface = Color(0xFF0D121C);
  static const Color surfaceHigh = Color(0xFF141C2B);
  static const Color border = Color(0xFF1F2B40);

  static const Color neonCyan = Color(0xFF00E5FF);
  static const Color neonGreen = Color(0xFF39FF88);
  static const Color neonMagenta = Color(0xFFFF3DCB);

  static const Color danger = Color(0xFFFF4D6D);
  static const Color warning = Color(0xFFFFC857);

  static const Color text = Color(0xFFE8EEF8);
  static const Color textMuted = Color(0xFF8A97AD);
}

class AppTheme {
  AppTheme._();

  static ThemeData dark() {
    final ColorScheme scheme = ColorScheme.dark(
      primary: AppColors.neonCyan,
      onPrimary: const Color(0xFF00141A),
      secondary: AppColors.neonGreen,
      onSecondary: const Color(0xFF00170B),
      tertiary: AppColors.neonMagenta,
      onTertiary: const Color(0xFF1A0014),
      surface: AppColors.surface,
      onSurface: AppColors.text,
      error: AppColors.danger,
      onError: const Color(0xFF1A0006),
      outline: AppColors.border,
      inverseSurface: AppColors.surfaceHigh,
      onInverseSurface: AppColors.text,
    );

    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      dividerColor: AppColors.border,
    );
  }
}
