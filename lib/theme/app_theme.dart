import 'package:flutter/material.dart';

class AppColors {
  static const teal = Color(0xFF55D6BE);
  static const amber = Color(0xFFF0A857);
  static const darkBg = Color(0xFF0F1319);
  static const darkSurface = Color(0xFF171D26);
  static const lightBg = Color(0xFFF7F8FA);
  static const lightSurface = Color(0xFFFFFFFF);
}

class AppTheme {
  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.darkBg,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.teal,
          secondary: AppColors.amber,
          surface: AppColors.darkSurface,
        ),
        cardTheme: CardThemeData(
          color: AppColors.darkSurface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFF2A3340)),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.darkBg,
          elevation: 0,
        ),
        useMaterial3: true,
      );

  static ThemeData get light => ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.lightBg,
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF1F9E8A),
          secondary: AppColors.amber,
          surface: AppColors.lightSurface,
        ),
        cardTheme: CardThemeData(
          color: AppColors.lightSurface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFE2E6EC)),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.lightBg,
          elevation: 0,
        ),
        useMaterial3: true,
      );
}
