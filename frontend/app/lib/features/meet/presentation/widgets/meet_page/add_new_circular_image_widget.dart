import 'package:flutter/material.dart';

class AddNewCircularImageWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 74,
      height: 74,
      child: CustomPaint(
        painter: DashedCirclePainter(),
        child: Center(
          child: Container(
            width: 67.57,
            height: 67.57,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFE72410).withOpacity(0.05),
            ),
            child: Center(
              child: Icon(
                Icons.add,
                color: Color(0xFFE72410),
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DashedCirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Color(0xFFE72410)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final radius = size.width / 2;
    final dashCount = 12;
    final dashWidth = 10;
    final angleStep = (2 * 3.14159265359) / dashCount;

    for (int i = 0; i < dashCount; i++) {
      final startAngle = i * angleStep;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(radius, radius), radius: radius),
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
