import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTextStyles {
  // Primary font family across the ERP/HRMS system: Inter
  static const fontFamily = 'Inter';
  static const displayFontFamily = 'Inter';
  static const fontFamilyFallback = <String>[
    'Inter',
    '-apple-system',
    'BlinkMacSystemFont',
    'Segoe UI',
    'Roboto',
    'Helvetica Neue',
    'Arial',
    'sans-serif',
  ];

  /// Page title: 24px / 28px, Weight: 600–700
  static const pageTitle = TextStyle(
    color: AppColors.textPrimary,
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: -0.3,
  );

  /// Section headings: 20px / 24px, Weight: 600
  static const sectionTitle = TextStyle(
    color: AppColors.textPrimary,
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.25,
    letterSpacing: -0.2,
  );

  /// Card/module names: 16px / 20px, Weight: 600
  static const cardTitle = TextStyle(
    color: AppColors.textPrimary,
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.25,
    letterSpacing: -0.2,
  );

  /// General headings: 16px, Weight: 600
  static const heading = TextStyle(
    color: AppColors.textPrimary,
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.25,
    letterSpacing: -0.2,
  );

  /// Normal text / Body: 14px / 20px, Weight: 400
  static const body = TextStyle(
    color: AppColors.textPrimary,
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.42,
    letterSpacing: -0.05,
  );

  /// Labels: 13px / 18px, Weight: 500
  static const label = TextStyle(
    color: AppColors.textSecondary,
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.38,
  );

  /// Buttons: 14px / 20px, Weight: 600
  static const button = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.42,
  );

  /// Navigation items: 13px, Weight: 500
  static const navigation = TextStyle(
    color: AppColors.sidebarText,
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.3,
    letterSpacing: -0.05,
  );

  /// Caption: 12px / 16px, Weight: 400
  static const caption = TextStyle(
    color: AppColors.textSecondary,
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.35,
  );

  /// Numbers / Statistics: Weight: 600–700
  static const statNumber = TextStyle(
    color: AppColors.textPrimary,
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.5,
  );

  /// Table Cells: 13px–14px, Weight: 400–500
  static const tableCell = TextStyle(
    color: AppColors.textPrimary,
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  /// Table Header: 12px, Weight: 600
  static const tableHeader = TextStyle(
    color: AppColors.textSecondary,
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: 0.2,
  );
}
