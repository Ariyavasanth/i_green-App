import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTextStyles {
  static const pageTitle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 20,
    fontWeight: FontWeight.w600,
  );
  static const heading = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );
  static const body = TextStyle(color: AppColors.textPrimary, fontSize: 14);
  static const navigation = TextStyle(
    color: AppColors.sidebarText,
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );
  static const caption = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 12,
  );
}
