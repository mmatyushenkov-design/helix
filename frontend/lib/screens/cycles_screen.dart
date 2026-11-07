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

  @override
  Widget build(BuildContext context) {
    final language = appState.language;
    final items = appState.exercises.where((e) {
      if (e.archived || e.format != RecordFormat.weightReps) return false;
      if (!e.name(language).toLowerCase().contains(_filter.toLowerCase()) &&
          !e.nameRu.toLowerCase().contains(_filter.toLowerCase())) {
        return false;
      }
      if (_group == null) return true;
      final codes = muscleCatalog
          .firstWhere((g) => g.code == _group)
          .muscles
          .map((m) => m.code);
      return [...e.primaryMuscles, ...e.secondaryMuscles].any(codes.contains);
    }).toList();
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
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final exercise = items[i];
                    return InkWell(
                      onTap: () => Navigator.pop(context, exercise.id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 6),
                        decoration: const BoxDecoration(
                            border: Border(
                                bottom: BorderSide(color: AppColors.border))),
                        child: Text(exercise.name(language),
                            style: const TextStyle(fontSize: 15)),
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
            for (final c in appState.cycles)
              CycleCard(cycle: c, accent: accent),
          ],
        );
      },
    );
  }
}
