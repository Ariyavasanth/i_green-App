import 'package:flutter/material.dart';
import '../../utils/organization_branding_helper.dart';

class PayslipBrandLogoWidget extends StatelessWidget {
  final OrganizationPayslipBranding branding;
  final double height;

  const PayslipBrandLogoWidget({
    super.key,
    required this.branding,
    this.height = 54,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      branding.logoAssetPath,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (context, error, stackTrace) => _buildFallback(),
    );
  }

  Widget _buildFallback() {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF9CC70A).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF9CC70A).withValues(alpha: 0.3)),
      ),
      child: Center(
        child: Text(
          branding.orgName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: Color(0xFF414A51),
          ),
        ),
      ),
    );
  }
}

