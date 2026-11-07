import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/muscle_group_icon.dart';
import 'exercise_catalog_screen.dart';

class PickedExercise {
  final String name;
  final bool withCycle;
  final String? cycleId;
  const PickedExercise(this.name, {this.withCycle = false, this.cycleId});
}

Future<PickedExercise?> showDiaryExercisePicker(BuildContext context) {
  return showModalBottomSheet<PickedExercise>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => const SafeArea(top: false, child: _DiaryExercisePicker()),
  );
}

class _DiaryExercisePicker extends StatefulWidget {
  const _DiaryExercisePicker();

  @override
  State<_DiaryExercisePicker> createState() => _DiaryExercisePickerState();
}

class _DiaryExercisePickerState extends State<_DiaryExercisePicker> {
  String _filter = '';
  String? _groupCode;
  String? _expanded;

  bool _inGroup(Exercise exercise, MuscleGroup group) {
    final codes = group.muscles.map((m) => m.code).toSet();
    return {...exercise.primaryMuscles, ...exercise.secondaryMuscles}
        .any(codes.contains);
  }

  String _recency(MuscleGroup group) {
    final ids = appState.exercises
        .where((e) => _inGroup(e, group))
        .map((e) => e.id)
        .toSet();
    DateTime? last;
    for (final item in appState.log.entries) {
      if (!item.value.any((entry) => ids.contains(entry.exerciseId))) continue;
      final date = DateTime.tryParse(item.key);
      if (date != null && (last == null || date.isAfter(last))) last = date;
    }
    if (last == null) return 'ещё не тренировали';
    final today = DateTime.now();
    final days = DateTime(today.year, today.month, today.day)
        .difference(DateTime(last.year, last.month, last.day))
        .inDays;
    if (days <= 0) return 'сегодня';
    if (days == 1) return 'вчера';
    final mod100 = days % 100;
    final mod10 = days % 10;
    final word = mod100 >= 11 && mod100 <= 14
        ? 'дней'
        : mod10 == 1
            ? 'день'
            : mod10 >= 2 && mod10 <= 4
                ? 'дня'
                : 'дней';
    return '$days $word назад';
  }

  String _exerciseCount(int count) {
    final mod100 = count % 100;
    final mod10 = count % 10;
    final word = mod100 >= 11 && mod100 <= 14
        ? 'упражнений'
        : mod10 == 1
            ? 'упражнение'
            : mod10 >= 2 && mod10 <= 4
                ? 'упражнения'
                : 'упражнений';
    return '$count $word';
  }

  Future<void> _createExercise() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ExerciseEditScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final language = appState.language;
    final accent = appState.accent;
    final group = _groupCode == null
        ? null
        : muscleCatalog.firstWhere((g) => g.code == _groupCode);
    final query = _filter.trim().toLowerCase();
    final items = appState.exercises.where((e) {
      if (e.archived || (group != null && !_inGroup(e, group))) return false;
      return e.name(language).toLowerCase().contains(query) ||
          e.nameRu.toLowerCase().contains(query) ||
          e.nameEn.toLowerCase().contains(query);
    }).toList();

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.76,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
          child: Column(
            children: [
              SizedBox(
                height: 32,
                child: Row(
                  children: [
                    if (group != null)
                      IconButton(
                        onPressed: () => setState(() {
                          _groupCode = null;
                          _expanded = null;
                        }),
                        icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                        color: AppColors.textDim,
                        tooltip: 'К группам',
                      )
                    else
                      const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        group?.name(language) ?? 'Добавить упражнение',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: TextField(
                        key: const Key('exercise-search'),
                        autofocus: false,
                        style: const TextStyle(
                            color: AppColors.text, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Поиск упражнения',
                          hintStyle: const TextStyle(color: AppColors.textDim),
                          prefixIcon: const Icon(Icons.search,
                              size: 20, color: AppColors.textDim),
                          filled: true,
                          fillColor: AppColors.surface2,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(13),
                              borderSide:
                                  const BorderSide(color: AppColors.border)),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(13),
                              borderSide:
                                  const BorderSide(color: AppColors.border)),
                        ),
                        onChanged: (v) => setState(() {
                          _filter = v;
                          _expanded = null;
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: IconButton(
                      key: const Key('create-exercise'),
                      onPressed: _createExercise,
                      tooltip: 'Создать упражнение',
                      icon: const Icon(Icons.add, size: 24),
                      color: AppColors.text,
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.surface2,
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: ListenableBuilder(
                  listenable: appState,
                  builder: (context, _) {
                    if (query.isEmpty && group == null) {
                      return _buildGroups(language);
                    }
                    if (items.isEmpty) {
                      return const Center(
                        child: Text('Упражнения не найдены',
                            style: TextStyle(
                                color: AppColors.textDim, fontSize: 14)),
                      );
                    }
                    return ListView.builder(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: items.length,
                      itemBuilder: (context, i) =>
                          _exerciseTile(items[i], language, accent),
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

  Widget _buildGroups(String language) {
    return ListView.separated(
      itemCount: muscleCatalog.length,
      separatorBuilder: (_, __) => const SizedBox(height: 9),
      itemBuilder: (context, i) {
        final group = muscleCatalog[i];
        final count = appState.exercises
            .where((e) => !e.archived && _inGroup(e, group))
            .length;
        return Material(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(15),
          child: InkWell(
            key: Key('muscle-group-${group.code}'),
            borderRadius: BorderRadius.circular(15),
            onTap: () => setState(() {
              _groupCode = group.code;
              _expanded = null;
            }),
            child: Container(
              height: 76,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  MuscleGroupIcon(code: group.code),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(group.name(language),
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 5),
                        Text('${_exerciseCount(count)} · ${_recency(group)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11.5, color: AppColors.textDim)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.textDim),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _exerciseTile(Exercise exercise, String language, Color accent) {
    final name = exercise.name(language);
    Cycle? cycle;
    for (final c in appState.cycles) {
      if (c.exerciseId == exercise.id) cycle = c;
    }
    final open = _expanded == exercise.id;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        border: Border.all(
            color: open ? accent.withValues(alpha: 0.55) : AppColors.border),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(13),
            onTap: () {
              if (cycle == null) {
                Navigator.pop(context, PickedExercise(name));
              } else {
                setState(() => _expanded = open ? null : exercise.id);
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 13),
              child: Row(
                children: [
                  Expanded(
                      child: Text(name,
                          style: const TextStyle(
                              fontSize: 14.5, fontWeight: FontWeight.w600))),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      cycle != null
                          ? 'цикл · день ${cycle.curDay + 1}/${cycle.days.length}'
                          : exercise.format.label(language),
                      textAlign: TextAlign.end,
                      style: TextStyle(
                          fontSize: 11,
                          color: cycle != null ? accent : AppColors.textDim),
                    ),
                  ),
                  const Icon(Icons.chevron_right,
                      size: 19, color: AppColors.textDim),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: open && cycle != null
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                Navigator.pop(context, PickedExercise(name)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.text,
                              side: const BorderSide(color: AppColors.border),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Без цикла'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => Navigator.pop(
                                context,
                                PickedExercise(name,
                                    withCycle: true, cycleId: cycle!.id)),
                            style: FilledButton.styleFrom(
                              backgroundColor: accent,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                                'Цикл · день ${cycle.curDay + 1}/${cycle.days.length}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}
