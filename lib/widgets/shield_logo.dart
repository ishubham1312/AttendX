import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme/app_theme.dart';

/// Custom-painted shield logo with clock ticks and a checkmark,
/// matching the green gradient emblem in the design.
class ShieldLogo extends StatelessWidget {
  final double size;
  const ShieldLogo({super.key, this.size = 120});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _ShieldPainter()),
    );
  }
}

class _ShieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final path = Path()
      ..moveTo(w * 0.5, h * 0.02)
      ..lineTo(w * 0.95, h * 0.18)
      ..lineTo(w * 0.95, h * 0.55)
      ..quadraticBezierTo(w * 0.95, h * 0.85, w * 0.5, h * 0.98)
      ..quadraticBezierTo(w * 0.05, h * 0.85, w * 0.05, h * 0.55)
      ..lineTo(w * 0.05, h * 0.18)
      ..close();

    final shieldPaint = Paint()
      ..shader = const LinearGradient(
        colors: [AppColors.lime, AppColors.forestGreen],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(path, shieldPaint);

    // Clock ticks around top arc
    final center = Offset(w * 0.5, h * 0.42);
    final tickPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = w * 0.018
      ..strokeCap = StrokeCap.round;
    final r = w * 0.30;
    for (int i = 0; i < 12; i++) {
      final angle = (i * 30) * math.pi / 180;
      final p1 = Offset(
          center.dx + r * math.cos(angle), center.dy + r * math.sin(angle));
      final p2 = Offset(center.dx + (r - w * 0.05) * math.cos(angle),
          center.dy + (r - w * 0.05) * math.sin(angle));
      canvas.drawLine(p1, p2, tickPaint);
    }

    // Layered checkmarks
    final checkPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = w * 0.06
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final check = Path()
      ..moveTo(w * 0.34, h * 0.43)
      ..lineTo(w * 0.46, h * 0.55)
      ..lineTo(w * 0.68, h * 0.30);
    canvas.drawPath(check, checkPaint);

    final checkPaint2 = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..strokeWidth = w * 0.06
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final check2 = Path()
      ..moveTo(w * 0.34, h * 0.55)
      ..lineTo(w * 0.46, h * 0.67)
      ..lineTo(w * 0.68, h * 0.42);
    canvas.drawPath(check2, checkPaint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
