import 'package:flutter/material.dart';

import '../theme.dart';

/// Диалог подтверждения: «Нет» — серая плашка, «Да» — красная обводка,
/// обе одинакового размера, как кнопки «Завершить»/«+ Подход».
Future<bool> showConfirmDialog(BuildContext context, String text) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _ConfirmBtn(
                    label: 'Нет',
                    color: AppColors.text,
                    borderColor: AppColors.border,
                    onTap: () => Navigator.pop(ctx, false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ConfirmBtn(
                    label: 'Да',
                    color: const Color(0xFFD06060),
                    borderColor: const Color(0xFFA03030),
                    onTap: () => Navigator.pop(ctx, true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return ok ?? false;
}

class _ConfirmBtn extends StatelessWidget {
  final String label;
  final Color color;
  final Color borderColor;
  final VoidCallback onTap;
  const _ConfirmBtn({required this.label, required this.color, required this.borderColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        height: 45,
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Center(
          child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
        ),
      ),
    );
  }
}
