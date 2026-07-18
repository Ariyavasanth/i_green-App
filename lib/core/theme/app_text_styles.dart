import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTextStyles {
  // Apple platforms use San Francisco natively; the fallbacks keep the same
  // clean, system-font character on platforms where SF is not installed.
  static const fontFamily = '.SF Pro Text';
  static const displayFontFamily = '.SF Pro Display';
  static const fontFamilyFallback = <String>[
    'SF Pro Text',
    'SF Pro Display',
    'Segoe UI Variable',
    'Segoe UI',
    'Roboto',
    'Arial',
  ];

  static const pageTitle = TextStyle(
    color: AppColors.textPrimary,
    fontFamily: displayFontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.18,
    letterSpacing: -0.35,
  );
  static const heading = TextStyle(
    color: AppColors.textPrimary,
    fontFamily: displayFontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.25,
    letterSpacing: -0.2,
  );
  static const body = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.42,
    letterSpacing: -0.05,
  );
  static const navigation = TextStyle(
    color: AppColors.sidebarText,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.3,
    letterSpacing: -0.05,
  );
  static const caption = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    height: 1.35,
  );
}
