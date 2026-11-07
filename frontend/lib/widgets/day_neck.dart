import 'dart:math' as math;

import 'package:flutter/material.dart';

/// «Шейка» от выделенного дня к панели подходов.
///
/// Виджет шире чипа на 12px с каждой стороны: видимая часть шейки —
/// центральная полоса, по бокам внизу — вогнутые дуги радиусом 12px,
/// сливающиеся с верхней кромкой панели. У крайних дней дуга со стороны
/// края панели не рисуется.
class NeckPainter extends CustomPainter {
  final Color color;
  final bool edgeL;
  final bool edgeR;

  NeckPainter({required this.color, this.edgeL = false, this.edgeR = false});

  static const r = 12.0;

  @override
  void paint(Canvas canvas, Size size) {
    const left = r;
    final right = size.width - r;
    final bottom = size.height;
    final path = Path()..moveTo(left, 0);

    if (edgeL) {
      path.lineTo(left, bottom);
    } else {
      path
        ..lineTo(left, bottom - r)
        ..arcTo(
            Rect.fromCircle(center: Offset(left - r, bottom - r), radius: r),
            0,
            math.pi / 2,
            false);
    }
    // дуга закончилась в (left - r, bottom) — идём по верхней кромке панели
    if (edgeR) {
      path.lineTo(right, bottom);
    } else {
      path
        ..lineTo(right + r, bottom)
        ..arcTo(
            Rect.fromCircle(center: Offset(right + r, bottom - r), radius: r),
            math.pi / 2,
            math.pi / 2,
            false);
    }
    path
      ..lineTo(right, 0)
      ..close();

    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(NeckPainter old) =>
      old.color != color || old.edgeL != edgeL || old.edgeR != edgeR;
}
