import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Thèmes clair et sombre de l'application.
class AppTheme {
  AppTheme._();

  /// Police des titres (serif élégante, comme sur la maquette vidéo).
  static TextStyle display(double size, {Color? color}) =>
      GoogleFonts.dmSerifDisplay(fontSize: size, color: color, height: 1.1);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.violet,
      brightness: brightness,
      primary: AppColors.violet,
      secondary: AppColors.blue,
      error: AppColors.error,
      surface: isDark ? AppColors.darkSurface : AppColors.white,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: brightness);

    return base.copyWith(
      scaffoldBackgroundColor: isDark ? AppColors.black : AppColors.lightSurface,
      textTheme: GoogleFonts.manropeTextTheme(base.textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.manrope(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : AppColors.black,
        ),
      ),
      cardTheme: CardThemeData(
        color: isDark ? AppColors.darkCard : AppColors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.violetLight, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w700),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.white,
        indicatorColor: AppColors.violet.withValues(alpha: 0.18),
      ),
    );
  }
}
