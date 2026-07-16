import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

abstract final class AppTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    fontFamily: AppTextStyles.fontFamily,
    fontFamilyFallback: AppTextStyles.fontFamilyFallback,
    splashFactory: NoSplash.splashFactory,
    visualDensity: VisualDensity.standard,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.active,
      surface: AppColors.surface,
    ),
    scaffoldBackgroundColor: AppColors.canvas,
    dividerColor: AppColors.divider,
    dividerTheme: const DividerThemeData(
      color: AppColors.divider,
      thickness: 0.5,
      space: 1,
    ),
    iconTheme: const IconThemeData(color: AppColors.active, size: 22),
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
      centerTitle: true,
      titleTextStyle: AppTextStyles.heading,
      toolbarHeight: 52,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.active,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(44, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(44, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.active,
        minimumSize: const Size(44, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        side: const BorderSide(color: AppColors.divider),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.active,
        minimumSize: const Size(44, 44),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      hintStyle: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
      labelStyle: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
      floatingLabelStyle: AppTextStyles.caption.copyWith(color: AppColors.active),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.active, width: 1.5),
      ),
    ),
    cardTheme: const CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: AppColors.divider),
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: AppColors.divider),
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 4,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: AppColors.divider),
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      side: const BorderSide(color: AppColors.divider, width: 1.5),
    ),
    switchTheme: SwitchThemeData(
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.primary
            : AppColors.divider,
      ),
      thumbColor: const WidgetStatePropertyAll(Colors.white),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: AppColors.active,
      textColor: AppColors.textPrimary,
      minTileHeight: 48,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
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
