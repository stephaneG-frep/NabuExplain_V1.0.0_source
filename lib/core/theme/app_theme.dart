import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NabuColors {
  static const violetElectric = Color(0xFF7C3AED);
  static const blueDeep = Color(0xFF1E40AF);
  static const cyanSoft = Color(0xFF06B6D4);
  static const turquoise = Color(0xFF14B8A6);
  static const orange = Color(0xFFF97316);
  static const magenta = Color(0xFFEC4899);
  static const red = Color(0xFFEF4444);
  static const green = Color(0xFF22C55E);

  static const violetLight = Color(0xFFDDD6FE);
  static const blueLight = Color(0xFFBFDBFE);
  static const cyanLight = Color(0xFFCFFAFE);
  static const turquoiseLight = Color(0xFFCCFBF1);
  static const orangeLight = Color(0xFFFED7AA);
  static const magentaLight = Color(0xFFFBCFE8);
  static const redLight = Color(0xFFFECACA);
  static const greenLight = Color(0xFFBBF7D0);

  static const backgroundLight = Color(0xFFF8F7FF);
  static const backgroundDark = Color(0xFF0F0A1F);
  static const surfaceDark = Color(0xFF1A1333);
  static const surfaceLight = Color(0xFFFFFFFF);

  static const gradientViolet = LinearGradient(
    colors: [violetElectric, blueDeep],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const gradientCyan = LinearGradient(
    colors: [cyanSoft, turquoise],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const gradientOrange = LinearGradient(
    colors: [orange, magenta],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const gradientMagenda = LinearGradient(
    colors: [magenta, violetElectric],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const gradientMulti = LinearGradient(
    colors: [violetElectric, cyanSoft, turquoise],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static Color forType(String type) {
    switch (type) {
      case 'comprendre': return violetElectric;
      case 'exemple': return cyanSoft;
      case 'retenir': return turquoise;
      case 'attention': return orange;
      case 'erreur': return red;
      case 'quiz': return magenta;
      case 'exercice': return blueDeep;
      default: return violetElectric;
    }
  }
}

class AppTheme {
  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: NabuColors.violetElectric,
      brightness: Brightness.light,
      primary: NabuColors.violetElectric,
      secondary: NabuColors.cyanSoft,
      tertiary: NabuColors.turquoise,
      error: NabuColors.red,
      surface: NabuColors.surfaceLight,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: NabuColors.backgroundLight,
      textTheme: GoogleFonts.nunitoTextTheme(),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.nunito(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: NabuColors.violetElectric,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: Colors.white.withValues(alpha: 0.8),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: NabuColors.violetLight, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: NabuColors.violetElectric, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: NabuColors.violetElectric,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: NabuColors.violetElectric,
        unselectedItemColor: Colors.grey.shade400,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: NabuColors.violetElectric,
      brightness: Brightness.dark,
      primary: NabuColors.violetElectric,
      secondary: NabuColors.cyanSoft,
      tertiary: NabuColors.turquoise,
      error: NabuColors.red,
      surface: NabuColors.surfaceDark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: NabuColors.backgroundDark,
      textTheme: GoogleFonts.nunitoTextTheme(ThemeData.dark().textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.nunito(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: NabuColors.violetLight,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: NabuColors.surfaceDark.withValues(alpha: 0.8),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: NabuColors.surfaceDark.withValues(alpha: 0.6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: NabuColors.violetElectric.withValues(alpha: 0.3), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: NabuColors.violetElectric, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: NabuColors.violetElectric,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: NabuColors.surfaceDark,
        selectedItemColor: NabuColors.violetLight,
        unselectedItemColor: Colors.grey.shade600,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }
}
