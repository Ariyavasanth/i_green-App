import 'package:flutter/material.dart';

/// Shared viewport rules keep responsive behavior consistent across screens.
abstract final class AppBreakpoints {
  static const double tablet = 600;
  static const double laptop = 900;
  static const double desktop = 1200;
}

abstract final class AppLayout {
  static double gutter(double width) {
    if (width >= AppBreakpoints.desktop) return 32;
    if (width >= AppBreakpoints.tablet) return 24;
    return 14;
  }

  static const double maxContentWidth = 1440;
  static const double maxFormWidth = 760;
}

class ResponsiveContent extends StatelessWidget {
  const ResponsiveContent({
    required this.child,
    this.maxWidth = AppLayout.maxContentWidth,
    super.key,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}
