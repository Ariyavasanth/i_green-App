import 'package:flutter/material.dart';

/// A custom widget that renders the Organization Chart monitor icon
/// exactly matching the reference graphic.
class OrganizationChartIcon extends StatelessWidget {
  const OrganizationChartIcon({
    super.key,
    this.size = 56.0,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _OrganizationChartPainter(),
      ),
    );
  }
}

class _OrganizationChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 512.0;
    canvas.save();
    canvas.scale(scale, scale);

    // 1. Monitor Screen Body
    final bodyRRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(20, 32, 472, 340),
      const Radius.circular(38),
    );
    canvas.drawRRect(bodyRRect, Paint()..color = const Color(0xFFE2EDF6));

    // 2. Monitor Bottom Bezel (Chin)
    canvas.save();
    canvas.clipRRect(bodyRRect);
    canvas.drawRect(
      const Rect.fromLTWH(20, 324, 472, 60),
      Paint()..color = const Color(0xFF2E4D71),
    );
    canvas.restore();

    // 3. Monitor Stand Neck
    canvas.drawRect(
      const Rect.fromLTWH(222, 372, 68, 52),
      Paint()..color = const Color(0xFF2E4D71),
    );

    // 4. Monitor Stand Base
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(168, 416, 176, 54),
        const Radius.circular(27),
      ),
      Paint()..color = const Color(0xFF2E4D71),
    );

    // 5. Top-Right Status Indicators
    final greenPaint = Paint()..color = const Color(0xFF78D122);
    final orangePaint = Paint()..color = const Color(0xFFE25821);

    // Green row
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(348, 70, 32, 20), const Radius.circular(10)),
      greenPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(390, 70, 62, 20), const Radius.circular(10)),
      greenPaint,
    );

    // Orange row
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(348, 108, 32, 20), const Radius.circular(10)),
      orangePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(390, 108, 62, 20), const Radius.circular(10)),
      orangePaint,
    );

    // 6. Hierarchy Tree Lines
    final treeLinePaint = Paint()
      ..color = const Color(0xFF6C9FBF)
      ..strokeWidth = 20
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final branchPath = Path()
      ..moveTo(146, 226)
      ..lineTo(146, 186)
      ..quadraticBezierTo(146, 172, 160, 172)
      ..lineTo(352, 172)
      ..quadraticBezierTo(366, 172, 366, 186)
      ..lineTo(366, 226);
    canvas.drawPath(branchPath, treeLinePaint);

    // Center stem
    canvas.drawLine(const Offset(256, 140), const Offset(256, 226), treeLinePaint);

    // 7. Root Node
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(225, 92, 62, 48), const Radius.circular(4)),
      Paint()..color = const Color(0xFF54C2FA),
    );

    // 8. Child Nodes (Bottom Row)
    // Left Node (Lime Green)
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(115, 226, 62, 48), const Radius.circular(4)),
      greenPaint,
    );

    // Center Node (Golden Yellow)
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(225, 226, 62, 48), const Radius.circular(4)),
      Paint()..color = const Color(0xFFF7CE27),
    );

    // Right Node (Deep Orange)
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(335, 226, 62, 48), const Radius.circular(4)),
      Paint()..color = const Color(0xFFE05C1F),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
