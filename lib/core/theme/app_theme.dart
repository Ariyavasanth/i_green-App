import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

abstract final class AppTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    fontFamily: AppTextStyles.fontFamily,
    fontFamilyFallback: AppTextStyles.fontFamilyFallback,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.active,
      surface: AppColors.surface,
    ),
    scaffoldBackgroundColor: AppColors.canvas,
    dividerColor: AppColors.divider,
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontFamily: AppTextStyles.displayFontFamily,
        fontSize: 34,
        fontWeight: FontWeight.w700,
        height: 1.12,
        letterSpacing: -0.7,
      ),
      headlineMedium: TextStyle(
        fontFamily: AppTextStyles.displayFontFamily,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.16,
        letterSpacing: -0.5,
      ),
      titleLarge: AppTextStyles.pageTitle,
      titleMedium: AppTextStyles.heading,
      titleSmall: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.3),
      bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.45),
      bodyMedium: AppTextStyles.body,
      bodySmall: AppTextStyles.caption,
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.2),
      labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, height: 1.2),
    ),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textPrimary,
      surfaceTintColor: Colors.transparent,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: .72),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
    ),
    cardTheme: const CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: AppColors.divider),
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
      },
    ),
  );
}
