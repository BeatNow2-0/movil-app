import 'package:flutter/material.dart';

abstract final class BeatNowTokens {
  static const background = Color(0xFF08090C);
  static const surface0 = Color(0xFF0D0F14);
  static const surface1 = Color(0xFF12151B);
  static const surface2 = Color(0xFF181C24);
  static const surface3 = Color(0xFF202531);
  static const accent = Color(0xFF7C3AED);
  static const accentHover = Color(0xFF8B5CF6);
  static const accentSoft = Color(0xFFB9A1FF);
  static const accentMuted = Color(0xFF2B2041);
  static const rose = Color(0xFFE879A7);
  static const text = Color(0xFFF6F7FB);
  static const textMuted = Color(0xFFA8ADB9);
  static const textSubtle = Color(0xFF737987);
  static const border = Color(0x1FFFFFFF);
  static const borderStrong = Color(0x38FFFFFF);
  static const danger = Color(0xFFFB7185);
  static const success = Color(0xFF4ADE80);

  static const space1 = 4.0;
  static const space2 = 8.0;
  static const space3 = 12.0;
  static const space4 = 16.0;
  static const space5 = 24.0;
  static const space6 = 32.0;

  static const radiusSmall = 4.0;
  static const radiusMedium = 8.0;
  static const radiusLarge = 12.0;
  static const radiusPill = 999.0;
}

abstract final class BeatNowTheme {
  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      primary: BeatNowTokens.accent,
      onPrimary: Colors.white,
      secondary: BeatNowTokens.rose,
      onSecondary: BeatNowTokens.background,
      surface: BeatNowTokens.surface1,
      onSurface: BeatNowTokens.text,
      error: BeatNowTokens.danger,
      onError: Colors.white,
      outline: BeatNowTokens.borderStrong,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: BeatNowTokens.background,
      canvasColor: BeatNowTokens.surface0,
      fontFamily: 'Roboto',
      textTheme: const TextTheme(
        displayLarge: TextStyle(
            color: BeatNowTokens.text,
            fontSize: 32,
            fontWeight: FontWeight.w700),
        displayMedium: TextStyle(
            color: BeatNowTokens.text,
            fontSize: 28,
            fontWeight: FontWeight.w700),
        headlineLarge: TextStyle(
            color: BeatNowTokens.text,
            fontSize: 26,
            fontWeight: FontWeight.w700),
        headlineMedium: TextStyle(
            color: BeatNowTokens.text,
            fontSize: 22,
            fontWeight: FontWeight.w700),
        titleLarge: TextStyle(
            color: BeatNowTokens.text,
            fontSize: 20,
            fontWeight: FontWeight.w700),
        titleMedium: TextStyle(
            color: BeatNowTokens.text,
            fontSize: 16,
            fontWeight: FontWeight.w600),
        titleSmall: TextStyle(
            color: BeatNowTokens.text,
            fontSize: 14,
            fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: BeatNowTokens.text, fontSize: 16),
        bodyMedium: TextStyle(color: BeatNowTokens.textMuted, fontSize: 14),
        bodySmall: TextStyle(color: BeatNowTokens.textMuted, fontSize: 12),
        labelLarge: TextStyle(
            color: BeatNowTokens.text,
            fontSize: 14,
            fontWeight: FontWeight.w600),
        labelMedium: TextStyle(
            color: BeatNowTokens.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w500),
        labelSmall: TextStyle(
            color: BeatNowTokens.textSubtle,
            fontSize: 11,
            fontWeight: FontWeight.w600),
      ),
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: BeatNowTokens.background,
        foregroundColor: BeatNowTokens.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: BeatNowTokens.text,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          fontFamily: 'Roboto',
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: BeatNowTokens.accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: BeatNowTokens.surface3,
          disabledForegroundColor: BeatNowTokens.textSubtle,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: BeatNowTokens.space4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BeatNowTokens.radiusMedium),
          ),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: BeatNowTokens.surface0,
        selectedItemColor: BeatNowTokens.accentSoft,
        unselectedItemColor: BeatNowTokens.textSubtle,
        selectedLabelStyle:
            TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle:
            TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: BeatNowTokens.surface2,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: BeatNowTokens.space4,
          vertical: BeatNowTokens.space3,
        ),
        hintStyle: const TextStyle(color: BeatNowTokens.textSubtle),
        labelStyle: const TextStyle(color: BeatNowTokens.textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BeatNowTokens.radiusMedium),
          borderSide: const BorderSide(color: BeatNowTokens.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BeatNowTokens.radiusMedium),
          borderSide: const BorderSide(color: BeatNowTokens.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BeatNowTokens.radiusMedium),
          borderSide:
              const BorderSide(color: BeatNowTokens.accentSoft, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BeatNowTokens.radiusMedium),
          borderSide: const BorderSide(color: BeatNowTokens.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BeatNowTokens.radiusMedium),
          borderSide: const BorderSide(color: BeatNowTokens.danger, width: 1.4),
        ),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: BeatNowTokens.accentSoft,
        selectionColor: BeatNowTokens.accentMuted,
        selectionHandleColor: BeatNowTokens.accentSoft,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: BeatNowTokens.accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: BeatNowTokens.surface3,
          disabledForegroundColor: BeatNowTokens.textSubtle,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: BeatNowTokens.space4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BeatNowTokens.radiusMedium),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: BeatNowTokens.text,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: BeatNowTokens.space4),
          side: const BorderSide(color: BeatNowTokens.borderStrong),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BeatNowTokens.radiusMedium),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: BeatNowTokens.accentSoft,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BeatNowTokens.radiusSmall),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: BeatNowTokens.surface1,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BeatNowTokens.radiusMedium),
          side: const BorderSide(color: BeatNowTokens.border),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: BeatNowTokens.surface2,
        selectedColor: BeatNowTokens.accentMuted,
        disabledColor: BeatNowTokens.surface1,
        labelStyle: const TextStyle(color: BeatNowTokens.textMuted),
        secondaryLabelStyle: const TextStyle(color: BeatNowTokens.text),
        side: const BorderSide(color: BeatNowTokens.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BeatNowTokens.radiusSmall),
        ),
        padding: const EdgeInsets.symmetric(horizontal: BeatNowTokens.space2),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: BeatNowTokens.accentSoft,
        linearTrackColor: BeatNowTokens.surface3,
        circularTrackColor: BeatNowTokens.surface3,
      ),
      dividerTheme: const DividerThemeData(
        color: BeatNowTokens.border,
        thickness: 1,
        space: BeatNowTokens.space4,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: BeatNowTokens.surface3,
        contentTextStyle: const TextStyle(color: BeatNowTokens.text),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BeatNowTokens.radiusMedium),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: BeatNowTokens.surface1,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
      ),
    );
  }
}
