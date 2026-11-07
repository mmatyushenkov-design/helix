import 'package:flutter/material.dart';

import '../state/strings.dart';
import '../theme.dart';

/// Вкладка-заглушка. Модель WorkoutTemplate и применение уже есть в AppState;
/// наполнение экрана будет следующим отдельным UI-этапом.
class TemplatesScreen extends StatelessWidget {
  const TemplatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.view_list_outlined,
                size: 42, color: AppColors.textDim),
            const SizedBox(height: 16),
            Text(tr('templatesEmpty'),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(tr('templatesEmptySub'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.textDim)),
          ],
        ),
      ),
    );
  }
}
