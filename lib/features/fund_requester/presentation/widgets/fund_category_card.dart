import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/theme/app_colors.dart';
import 'package:flutter_application_1/features/fund_requester/domain/models/fund_category_constants.dart';

/// Category selection card matching the design in the reference screenshot (Image 1).
class FundCategoryCard extends StatelessWidget {
  final FundCategoryDefinition category;
  final VoidCallback onTap;
  final bool isSelected;

  const FundCategoryCard({
    required this.category,
    required this.onTap,
    this.isSelected = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: AppColors.primary.withValues(alpha: 0.1),
          highlightColor: AppColors.primary.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    category.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? AppColors.primary : const Color(0xFF1E293B),
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                _buildCategoryGraphic(category),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryGraphic(FundCategoryDefinition cat) {
    // Rich graphical icon matching the reference screenshot
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: cat.secondaryColor.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: cat.primaryColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            cat.icon,
            size: 32,
            color: cat.primaryColor,
          ),
          if (cat.title == 'Others')
            Positioned(
              bottom: 12,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _dot(),
                  const SizedBox(width: 3),
                  _dot(),
                  const SizedBox(width: 3),
                  _dot(),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _dot() {
    return Container(
      width: 4,
      height: 4,
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        shape: BoxShape.circle,
      ),
    );
  }
}
