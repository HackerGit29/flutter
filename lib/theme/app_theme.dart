import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();

  static const Color bgApp = Color(0xFFC8D9E0);
  static const Color bgPrimary = Color(0xFFFFFFFF);
  static const Color bgSecondary = Color(0xFFF0F6F8);
  static const Color bgTertiary = Color(0xFFE8F2F5);

  static const Color accentTeal = Color(0xFF1A3A4A);
  static const Color accentPink = Color(0xFFF0B8C8);
  static const Color accentPurple = Color(0xFFC8A8D8);
  static const Color accentSage = Color(0xFFA8C8A8);
  static const Color accentCoral = Color(0xFFE8C0A8);
  static const Color accentBlue = Color(0xFFA8C8E0);
  static const Color accentMint = Color(0xFFB8E0D0);
  static const Color accentGold = Color(0xFFF5C842);
  static const Color accentDot = Color(0xFFE8506A);

  static const Color textPrimary = Color(0xFF1A2530);
  static const Color textSecondary = Color(0xFF4A5A68);
  static const Color textMuted = Color(0xFF8A9AAA);
  static const Color textInverse = Color(0xFFFFFFFF);
  static const Color textAccent = Color(0xFF1A3A4A);

  static const Color interactive = Color(0xFF1A3A4A);
  static Color get borderSubtle => const Color(0xFF1A3A4A).withValues(alpha: 0.08);
  static Color get shadowCard => const Color(0xFF1A3A4A).withValues(alpha: 0.08);

  // Dark theme overrides
  static const Color darkBgApp = Color(0xFF1A2530);
  static const Color darkBgPrimary = Color(0xFF2A3540);
  static const Color darkBgSecondary = Color(0xFF354050);
  static const Color darkBgTertiary = Color(0xFF3A4555);
  static const Color darkTextPrimary = Color(0xFFE8EDF0);
  static const Color darkTextSecondary = Color(0xFFA8B5C0);
  static const Color darkTextMuted = Color(0xFF6A7A8A);
}

class AppRadius {
  AppRadius._();
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double full = 9999;
}

class AppSpacing {
  AppSpacing._();
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 20;
  static const double s6 = 24;
  static const double s7 = 28;
  static const double s8 = 32;
  static const double s10 = 40;
  static const double s12 = 48;
  static const double s16 = 64;
}

class AppShadows {
  AppShadows._();
  static const xs = BoxShadow(
    color: Color(0x0F1A3A4A),
    blurRadius: 3,
    offset: Offset(0, 1),
  );
  static const sm = BoxShadow(
    color: Color(0x141A3A4A),
    blurRadius: 8,
    offset: Offset(0, 2),
  );
  static const md = BoxShadow(
    color: Color(0x1A1A3A4A),
    blurRadius: 16,
    offset: Offset(0, 4),
  );
  static const lg = BoxShadow(
    color: Color(0x1F1A3A4A),
    blurRadius: 32,
    offset: Offset(0, 8),
  );
  static const float = BoxShadow(
    color: Color(0x291A3A4A),
    blurRadius: 48,
    offset: Offset(0, 16),
  );
}

class AppTheme {
  static ThemeData _baseTheme({
    required Brightness brightness,
    required Color bgPrimary,
    required Color bgSecondary,
    required Color bgTertiary,
    required Color textPrimary,
    required Color textSecondary,
    required Color textMuted,
    required Color textInverse,
    required Color interactive,
    required Color scaffoldBg,
    required Color cardBg,
  }) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: interactive,
      onPrimary: textInverse,
      secondary: const Color(0xFF4A5A68),
      onSecondary: textInverse,
      tertiary: const Color(0xFFC8A8D8),
      onTertiary: textPrimary,
      surface: bgPrimary,
      onSurface: textPrimary,
      error: const Color(0xFFE8506A),
      onError: textInverse,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBg,
      fontFamily: GoogleFonts.dmSans().fontFamily,
      textTheme: GoogleFonts.dmSansTextTheme(
        TextTheme(
          displayLarge: GoogleFonts.dmSerifDisplay(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: textPrimary,
            height: 1.1,
          ),
          displayMedium: GoogleFonts.dmSerifDisplay(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: textPrimary,
            height: 1.1,
          ),
          headlineLarge: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: textPrimary,
            height: 1.3,
          ),
          headlineMedium: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: textPrimary,
            height: 1.3,
          ),
          titleLarge: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: textPrimary,
            height: 1.3,
          ),
          titleMedium: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: textPrimary,
            height: 1.4,
          ),
          titleSmall: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: textSecondary,
            height: 1.4,
          ),
          bodyLarge: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: textPrimary,
            height: 1.5,
          ),
          bodyMedium: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: textSecondary,
            height: 1.5,
          ),
          bodySmall: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w400,
            color: textMuted,
            height: 1.4,
          ),
          labelLarge: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: interactive,
            height: 1.4,
          ),
          labelMedium: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: textMuted,
            height: 1.4,
          ),
          labelSmall: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: textMuted,
            height: 1.3,
            letterSpacing: 0.03,
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: textPrimary, size: 20),
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 0,
        shadowColor: const Color(0x141A3A4A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        surfaceTintColor: Colors.transparent,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: interactive,
          foregroundColor: textInverse,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s5, vertical: AppSpacing.s3),
          textStyle: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: textInverse,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgTertiary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s4,
          vertical: AppSpacing.s3,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
          borderSide: const BorderSide(color: AppColors.interactive, width: 1.5),
        ),
        hintStyle: TextStyle(
          color: textMuted,
          fontSize: 14,
        ),
        labelStyle: TextStyle(
          color: textSecondary,
          fontSize: 14,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.borderSubtle,
        thickness: 1,
        space: 0,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: bgPrimary,
        selectedItemColor: interactive,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w400,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: interactive,
        foregroundColor: textInverse,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
      ),
    );
  }

  static final ThemeData lightTheme = _baseTheme(
    brightness: Brightness.light,
    bgPrimary: AppColors.bgPrimary,
    bgSecondary: AppColors.bgSecondary,
    bgTertiary: AppColors.bgTertiary,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    textMuted: AppColors.textMuted,
    textInverse: AppColors.textInverse,
    interactive: AppColors.interactive,
    scaffoldBg: AppColors.bgApp,
    cardBg: AppColors.bgPrimary,
  );

  static final ThemeData darkTheme = _baseTheme(
    brightness: Brightness.dark,
    bgPrimary: AppColors.darkBgPrimary,
    bgSecondary: AppColors.darkBgSecondary,
    bgTertiary: AppColors.darkBgTertiary,
    textPrimary: AppColors.darkTextPrimary,
    textSecondary: AppColors.darkTextSecondary,
    textMuted: AppColors.darkTextMuted,
    textInverse: AppColors.textPrimary,
    interactive: const Color(0xFF4A7A8A),
    scaffoldBg: AppColors.darkBgApp,
    cardBg: AppColors.darkBgPrimary,
  );
}
