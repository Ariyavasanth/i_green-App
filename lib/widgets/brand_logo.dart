import 'package:flutter/material.dart';

import '../core/theme/brand_logo_data.dart';

/// Clean brand logo widget using the updated high-res transparent iGreen logo.
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    this.height = 54,
    this.fit = BoxFit.contain,
    super.key,
  });

  final double height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image.memory(
      kBrandLogoBytes,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => Image.asset(
        'assets/igreen_logo_clean.png',
        height: height,
        fit: fit,
      ),
    );
  }
}
