import 'package:flutter/material.dart';

/// Собственный крестик: две округлые диагональные линии с запасом от краёв,
/// чтобы штрих нигде не обрезался. Стиль — как у остальных иконок приложения.
class CloseIcon extends StatelessWidget {
  final double size;
  final Color color;
  final double stroke;
  const CloseIcon({
    super.key,
    this.size = 12,
    this.color = const Color(0xFFD06060),
    this.stroke = 1.6,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _ClosePainter(color, stroke),
    );
  }
}

/// Круглая плашка удаления: кольцо и крестик рисуются одним painter'ом,
/// поэтому штрихи не обрезаются рамкой и всегда отцентрованы.
class CloseBadge extends StatelessWidget {
  final double size;
  const CloseBadge({super.key, this.size = 22});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _CloseBadgePainter(),
    );
  }
}

class _CloseBadgePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final center = Offset(size.width / 2, size.height / 2);
    final ringStroke = s * 1.5 / 22;
    final crossStroke = s * 1.7 / 22;
    // Кольцо: радиус с запасом под половину толщины штриха.
    canvas.drawCircle(
      center,
      s / 2 - ringStroke / 2 - 0.5,
      Paint()
        ..color = const Color(0xFFA03030)
        ..strokeWidth = ringStroke
        ..style = PaintingStyle.stroke,
    );
    final paint = Paint()
      ..color = const Color(0xFFD06060)
      ..strokeWidth = crossStroke
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final inset = s * 0.30;
    canvas
      ..drawLine(Offset(inset, inset),
          Offset(size.width - inset, size.height - inset), paint)
      ..drawLine(Offset(size.width - inset, inset),
          Offset(inset, size.height - inset), paint);
  }

  @override
  bool shouldRepaint(_CloseBadgePainter old) => false;
}

class _ClosePainter extends CustomPainter {
  final Color color;
  final double stroke;
  const _ClosePainter(this.color, this.stroke);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    // Отступ с учётом радиуса округлых концов линий.
    final inset = size.shortestSide * 0.18 + stroke / 2;
    final a = Offset(inset, inset);
    final b = Offset(size.width - inset, size.height - inset);
    final c = Offset(size.width - inset, inset);
    final d = Offset(inset, size.height - inset);
    canvas
      ..drawLine(a, b, paint)
      ..drawLine(c, d, paint);
  }

  @override
  bool shouldRepaint(_ClosePainter old) =>
      old.color != color || old.stroke != stroke;
}
