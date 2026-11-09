import 'package:flutter/material.dart';

import 'haptics.dart';

/// Цвета сегментов шкалы RIR: от «в отказ» до «10+».
const scaleColors = [
  Color(0xFF8E1616),
  Color(0xFFB03226),
  Color(0xFFC16222),
  Color(0xFFC9A227),
  Color(0xFF3D9C80),
  Color(0xFF2E86B0),
  Color(0xFF4FA3D1),
];

const rirTexts = [
  'в отказ',
  '1 повторение до отказа',
  '2 повторения до отказа',
  '3 повторения до отказа',
  '4 повторения до отказа',
  '5+ повторений в запасе',
  '10+ повторений в запасе',
];

/// Градиентная шкала RIR: ползунок ездит по сегментам и встаёт ровно
/// в середину каждого отрезка.
class RirSlider extends StatelessWidget {
  final int index; // 0..6
  final ValueChanged<int> onChanged;
  const RirSlider({super.key, required this.index, required this.onChanged});

  void _fromPosition(BuildContext context, double x) {
    final box = context.findRenderObject() as RenderBox;
    final i = (x / (box.size.width / 7)).floor().clamp(0, 6);
    if (i != index) hapticTick(); // короткий тик на каждый сегмент
    onChanged(i);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (d) => _fromPosition(context, d.localPosition.dx),
      onHorizontalDragUpdate: (d) => _fromPosition(context, d.localPosition.dx),
      child: SizedBox(
        height: 26,
        child: LayoutBuilder(builder: (context, cons) {
          final segW = cons.maxWidth / 7;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Container(
                  height: 22,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: scaleColors),
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 120),
                left: (index + 0.5) * segW - 13,
                top: 0,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scaleColors[index],
                    border:
                        Border.all(color: const Color(0xFF111111), width: 3),
                    boxShadow: const [
                      BoxShadow(color: Colors.black54, blurRadius: 10)
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}
