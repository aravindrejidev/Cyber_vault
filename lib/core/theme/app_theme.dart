import 'package:flutter/material.dart';

/// Cyber-brutalist design tokens: pitch-black background, hard white lines,
/// one volt-lime accent, hot magenta and red for emphasis.
/// No gradients, no blur, no rounded corners.
class AppColors {
  AppColors._();

  /// Pitch black, the background of the whole app.
  static const Color black = Color(0xFF000000);
  static const Color panel = Color(0xFF0A0A0A);
  static const Color panelHigh = Color(0xFF161616);

  /// Hard white: text and strong borders.
  static const Color ink = Color(0xFFFFFFFF);
  static const Color muted = Color(0xFF8E8E8E);
  static const Color line = Color(0xFF2B2B2B);

  /// Volt lime: the one accent colour.
  static const Color accent = Color(0xFFCCFF00);
  static const Color hot = Color(0xFFFF2E93);
  static const Color danger = Color(0xFFFF3B30);
  static const Color warn = Color(0xFFFFB800);
}

class AppStyle {
  AppStyle._();

  /// Monospace everywhere: terminal feel.
  static const String font = 'monospace';
  static const double stroke = 2;
  static const double strokeHeavy = 3;
  static const double shadowOffset = 4;

  static const TextStyle label = TextStyle(
    fontFamily: font,
    fontSize: 12,
    fontWeight: FontWeight.w800,
    letterSpacing: 2,
    color: AppColors.accent,
  );

  static const TextStyle heading = TextStyle(
    fontFamily: font,
    fontSize: 32,
    fontWeight: FontWeight.w900,
    height: 1.05,
    color: AppColors.ink,
  );

  static const TextStyle button = TextStyle(
    fontFamily: font,
    fontSize: 14,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.6,
  );

  static const TextStyle muted = TextStyle(
    fontFamily: font,
    fontSize: 13,
    height: 1.4,
    color: AppColors.muted,
  );

  /// Hard offset shadow (no blur): the signature of the style.
  static List<BoxShadow> hardShadow(Color color, [double offset = shadowOffset]) {
    return <BoxShadow>[
      BoxShadow(color: color, offset: Offset(offset, offset), blurRadius: 0),
    ];
  }
}

class AppTheme {
  AppTheme._();

  static ThemeData dark() {
    final ColorScheme scheme = ColorScheme.dark(
      primary: AppColors.accent,
      onPrimary: AppColors.black,
      secondary: AppColors.hot,
      onSecondary: AppColors.black,
      tertiary: AppColors.warn,
      onTertiary: AppColors.black,
      error: AppColors.danger,
      onError: AppColors.black,
      surface: AppColors.black,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.muted,
      outline: AppColors.ink,
      outlineVariant: AppColors.line,
      shadow: AppColors.black,
      surfaceTint: Colors.transparent,
      inverseSurface: AppColors.ink,
      onInverseSurface: AppColors.black,
      surfaceContainerLowest: AppColors.black,
      surfaceContainerLow: AppColors.panel,
      surfaceContainer: AppColors.panel,
      surfaceContainerHigh: AppColors.panelHigh,
      surfaceContainerHighest: AppColors.panelHigh,
    );

    const RoundedRectangleBorder square = RoundedRectangleBorder();

    return ThemeData(
      colorScheme: scheme,
      fontFamily: AppStyle.font,
      scaffoldBackgroundColor: AppColors.black,
      canvasColor: AppColors.black,
      dividerColor: AppColors.line,
      dividerTheme: const DividerThemeData(
        color: AppColors.line,
        thickness: 2,
        space: 2,
      ),
      splashFactory: NoSplash.splashFactory,
      highlightColor: const Color(0x22CCFF00),
      iconTheme: const IconThemeData(color: AppColors.ink),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.accent,
        selectionColor: Color(0x66CCFF00),
        selectionHandleColor: AppColors.accent,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.black,
          disabledBackgroundColor: AppColors.panelHigh,
          disabledForegroundColor: AppColors.muted,
          shape: square,
          textStyle: AppStyle.button,
          minimumSize: const Size(64, 48),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          disabledForegroundColor: AppColors.muted,
          side: const BorderSide(color: AppColors.ink, width: 2),
          shape: square,
          textStyle: AppStyle.button,
          minimumSize: const Size(64, 48),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          shape: square,
          textStyle: AppStyle.button,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.ink,
          shape: square,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.black,
        modalBackgroundColor: AppColors.black,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: AppColors.ink, width: 3),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.accent,
        contentTextStyle: TextStyle(
          fontFamily: AppStyle.font,
          color: AppColors.black,
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: AppColors.ink, width: 2),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.accent,
        inactiveTrackColor: AppColors.line,
        thumbColor: AppColors.ink,
        overlayColor: Color(0x22CCFF00),
        valueIndicatorColor: AppColors.accent,
        valueIndicatorTextStyle: TextStyle(
          color: AppColors.black,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
