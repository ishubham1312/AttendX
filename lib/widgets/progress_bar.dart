import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Gradient progress bar with a striped unfilled track, matching the design.
class GradientProgressBar extends StatelessWidget {
  final double value; // 0..1
  final double height;
  const GradientProgressBar({super.key, required this.value, this.height = 10});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            // striped track
            CustomPaint(
              size: Size.infinite,
              painter: _StripePainter(),
            ),
            FractionallySizedBox(
              widthFactor: value.clamp(0, 1),
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppColors.accentGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFFE9EBEF);
    canvas.drawRect(Offset.zero & size, bg);

    final stripe = Paint()
      ..color = const Color(0xFFDADDE3)
      ..strokeWidth = 2;
    const gap = 8.0;
    for (double x = -size.height; x < size.width; x += gap) {
      canvas.drawLine(
          Offset(x, size.height), Offset(x + size.height, 0), stripe);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
