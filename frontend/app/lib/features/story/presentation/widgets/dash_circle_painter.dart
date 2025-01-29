import 'package:flutter/cupertino.dart';

class DashedCirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE72410)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final radius = size.width / 2;
    const dashCount = 12;
    const dashWidth = 10;
    const angleStep = (2 * 3.14159265359) / dashCount;

    for (int i = 0; i < dashCount; i++) {
      final startAngle = i * angleStep;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(radius, radius), radius: radius - 1),
        startAngle,
        dashWidth / radius,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
