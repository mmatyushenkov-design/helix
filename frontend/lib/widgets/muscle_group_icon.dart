import 'package:flutter/material.dart';

class MuscleGroupIcon extends StatelessWidget {
  final String code;
  final double size;
  const MuscleGroupIcon({super.key, required this.code, this.size = 58});

  static Color color(String code) => switch (code) {
        'chest' => const Color(0xFF69B985),
        'arms' => const Color(0xFFD36B6B),
        'back' => const Color(0xFF6598D1),
        'legs' => const Color(0xFFA4BE5F),
        'shoulders' => const Color(0xFF67B8C7),
        'core' => const Color(0xFFA17AC5),
        'full_body' => const Color(0xFFD69A5D),
        'cardio' => const Color(0xFFD77C9E),
        _ => const Color(0xFF8B9691),
      };

  @override
  Widget build(BuildContext context) {
    final color = MuscleGroupIcon.color(code);
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.06),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.27),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Image.asset(
        'assets/muscle_groups_consistent/$code.png',
        fit: BoxFit.contain,
      ),
    );
  }
}
