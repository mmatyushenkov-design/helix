import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../state/strings.dart';
import '../theme.dart';
import '../widgets/cycle_card.dart';
import 'cycle_edit_screen.dart';

/// Выбор силового упражнения для нового цикла. Возвращает UUID упражнения.
Future<String?> showExercisePicker(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => const _ExercisePicker(),
  );
}

class _ExercisePicker extends StatefulWidget {
  const _ExercisePicker();

  @override
  State<_ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends State<_ExercisePicker> {
  String _filter = '';
  String? _group;
  late bool _showAll = appState.cycles.isNotEmpty;

  static const mainPriorityNames = [
    'Жим лёжа',
    'Становая тяга',
    'Приседания со штангой',
    'Жим стоя',
  ];

  static const priorityNames = [
    ...mainPriorityNames,
    'Тяга верхнего блока',
    'Тяга блока к поясу сидя',
    'Подтягивания',
    'Сгибание рук со штангой',
    'Разгибание рук на блоке',
    'Шраги в тренажере Смита',
  ];

  @override
  Widget build(BuildContext context) {
    final language = appState.language;
    final searching = _filter.isNotEmpty || _group != null;
    final items = appState.exercises.where((e) {
      // Формат отсекаем до поиска: время и дистанция недоступны для циклов.
      if (e.archived || !e.canUseInCycle) return false;
      if (!e.name(language).toLowerCase().contains(_filter.toLowerCase()) &&
          !e.nameRu.toLowerCase().contains(_filter.toLowerCase())) {
        return false;
      }
      if (_group != null) {
        final codes = muscleCatalog
            .firstWhere((g) => g.code == _group)
            .muscles
            .map((m) => m.code);
        return [...e.primaryMuscles, ...e.secondaryMuscles].any(codes.contains);
      }
      if (!searching && !_showAll && !mainPriorityNames.contains(e.nameRu)) {
        return false;
      }
      return true;
    }).toList()
      ..sort((a, b) {
        final ai = priorityNames.indexOf(a.nameRu);
        final bi = priorityNames.indexOf(b.nameRu);
        if (ai >= 0 || bi >= 0) {
          if (ai < 0) return 1;
          if (bi < 0) return -1;
          return ai.compareTo(bi);
        }
        return 0;
      });
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: tr('searchExercise'),
                  filled: true,
                  fillColor: AppColors.surface2,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (v) => setState(() => _filter = v),
              ),
              const SizedBox(height: 10),
              DropdownButton<String>(
                value: _group,
                hint: Text(tr('allGroups')),
                isExpanded: true,
                dropdownColor: AppColors.surface2,
                items: [
                  DropdownMenuItem(value: null, child: Text(tr('allGroups'))),
                  for (final g in muscleCatalog)
                    DropdownMenuItem(
                        value: g.code, child: Text(g.name(language))),
                ],
                onChanged: (v) => setState(() => _group = v),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  itemCount: items.length + (!_showAll && !searching ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i == items.length) {
                      return TextButton.icon(
                        onPressed: () => setState(() => _showAll = true),
                        icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                        label: const Text('Все упражнения'),
                      );
                    }
                    final exercise = items[i];
                    final hasCycle =
                        appState.cycles.any((c) => c.exerciseId == exercise.id);
                    return InkWell(
                      onTap: hasCycle
                          ? null
                          : () => Navigator.pop(context, exercise.id),
                      child: Opacity(
                        opacity: hasCycle ? 0.38 : 1,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 6),
                          decoration: const BoxDecoration(
                              border: Border(
                                  bottom: BorderSide(color: AppColors.border))),
                          child: Row(children: [
                            Expanded(
                              child: Text(exercise.name(language),
                                  style: const TextStyle(fontSize: 15)),
                            ),
                            if (hasCycle)
                              const Text('Уже в цикле',
                                  style: TextStyle(
                                      fontSize: 12, color: AppColors.textDim)),
                          ]),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CyclesScreen extends StatelessWidget {
  const CyclesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final accent = appState.accent;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(tr('cycles'),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () async {
                    final exerciseId = await showExercisePicker(context);
                    if (exerciseId == null || !context.mounted) return;
                    final c = appState.addCycle(exerciseId);
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => CycleEditScreen(cycle: c)));
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                  child: Text(tr('newCycle'),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (appState.cycles.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 42, left: 22, right: 22),
                child: Text(
                  'ВНИМАНИЕ!\n\n'
                  'Для правильного подбора нагрузки и избежания травм '
                  'необходимо выполнять упражнение в хорошей технике\n\n'
                  'Составление программы тренировок с использованием '
                  'тренировочных циклов (периодизации) помогает стабильнее '
                  'прогрессировать в рабочих весах за счёт чередования '
                  'тяжёлых и лёгких тренировочных дней, использования разных '
                  'диапазонов повторений и регулирования нагрузки.\n\n'
                  'Рекомендуется делать каждое упражнение в цикле два раза в неделю:\n'
                  'одна тренировка в рамках цикла,\n'
                  'вторая - вне цикла, поддерживающая, с маленькими весами.\n'
                  'по умолчанию цикл рассчитан именно на такой режим тренировок.',
                  style: TextStyle(
                      fontSize: 15, height: 1.45, color: Color(0xFF858585)),
                ),
              ),
            for (final c in appState.cycles)
              CycleCard(cycle: c, accent: accent),
          ],
        );
      },
    );
  }
}
