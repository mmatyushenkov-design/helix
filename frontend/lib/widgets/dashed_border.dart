import 'package:flutter/material.dart';

/// Пунктирная обводка вокруг child (как в макете у кнопок добавления).
class DashedBorder extends StatelessWidget {
  final Widget child;
  final Color color;
  final double radius;
  const DashedBorder({super.key, required this.child, required this.color, this.radius = 12});

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _DashedPainter(color, radius),
        child: child,
      );
}

class _DashedPainter extends CustomPainter {
  final Color color;
  final double radius;
  _DashedPainter(this.color, this.radius);

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      var dist = 0.0;
      while (dist < metric.length) {
        final end = (dist + 6).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(dist, end), paint);
        dist = end + 4;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedPainter old) => old.color != color || old.radius != radius;
}
