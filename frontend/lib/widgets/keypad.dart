import 'package:flutter/material.dart';

import '../theme.dart';

/// Цифровая клавиатура 3×4: 1–9, запятая, 0, бэкспейс.
class NumKeypad extends StatelessWidget {
  final ValueChanged<String> onKey;
  const NumKeypad({super.key, required this.onKey});

  static const keys = [
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    ',',
    '0',
    '⌫'
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.4,
      children: [
        for (final k in keys)
          Material(
            color: const Color(0xFF161616),
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => onKey(k),
              child: Center(
                child: Text(k,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text)),
              ),
            ),
          ),
      ],
    );
  }
}
