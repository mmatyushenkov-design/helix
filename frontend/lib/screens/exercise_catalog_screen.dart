import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme.dart';

Future<void> showExerciseEditDialog(BuildContext context,
    {Exercise? exercise, String? initialGroup}) {
  return showDialog<void>(
    context: context,
    builder: (_) =>
        ExerciseEditDialog(exercise: exercise, initialGroup: initialGroup),
  );
}

class ExerciseEditDialog extends StatefulWidget {
  final Exercise? exercise;
  final String? initialGroup;
  const ExerciseEditDialog({super.key, this.exercise, this.initialGroup});

  @override
  State<ExerciseEditDialog> createState() => _ExerciseEditDialogState();
}

class _ExerciseEditDialogState extends State<ExerciseEditDialog> {
  late final TextEditingController name =
      TextEditingController(text: widget.exercise?.nameRu ?? '');
  late RecordFormat format = widget.exercise?.format ?? RecordFormat.weightReps;
  late bool favorite = widget.exercise?.favorite ?? false;
  late String group = _groupOf(widget.exercise);

  String _groupOf(Exercise? exercise) {
    if (exercise != null) {
      for (final item in muscleCatalog) {
        if (item.muscles.any((m) => exercise.primaryMuscles.contains(m.code))) {
          return item.code;
        }
      }
    }
    return widget.initialGroup ?? muscleCatalog.first.code;
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  void _save() {
    if (name.text.trim().isEmpty) return;
    final old = widget.exercise;
    final selected = muscleCatalog.firstWhere((g) => g.code == group);
    final sameGroup = old != null && _groupOf(old) == group;
    appState.saveExercise(Exercise(
      id: old?.id,
      nameRu: name.text.trim(),
      nameEn: old?.nameEn ?? name.text.trim(),
      format: format,
      defaultStepKg: old?.defaultStepKg ?? 5,
      primaryMuscles: sameGroup
          ? old.primaryMuscles
          : [for (final muscle in selected.muscles) muscle.code],
      secondaryMuscles: sameGroup ? old.secondaryMuscles : const [],
      isCustom: old?.isCustom ?? true,
      archived: old?.archived ?? false,
      favorite: favorite,
    ));
    Navigator.pop(context);
  }

  InputDecoration get _nameDecoration => InputDecoration(
        hintText: 'Название упражнения',
        hintStyle: const TextStyle(color: AppColors.textDim),
        filled: true,
        fillColor: AppColors.surface2,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      );

  Widget _dropdown<T>(
      T value, List<DropdownMenuItem<T>> items, ValueChanged<T?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(13),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: AppColors.surface2,
          borderRadius: BorderRadius.circular(13),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  ButtonStyle _buttonStyle({bool danger = false, bool filled = false}) {
    final style = filled ? FilledButton.styleFrom : OutlinedButton.styleFrom;
    return style(
      foregroundColor: filled
          ? Colors.black
          : danger
              ? const Color(0xFFD06060)
              : AppColors.text,
      backgroundColor: filled ? appState.accent : AppColors.surface2,
      side: filled
          ? BorderSide.none
          : BorderSide(
              color: danger ? const Color(0xFFA03030) : AppColors.border),
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final language = appState.language;
    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.exercise == null
                  ? 'Новое упражнение'
                  : 'Изменить упражнение',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: IconButton(
                    key: const Key('exercise-favorite'),
                    onPressed: () => setState(() => favorite = !favorite),
                    icon: Icon(favorite ? Icons.star : Icons.star_border),
                    color: const Color(0xFFFFC84A),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surface2,
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    key: const Key('exercise-name'),
                    controller: name,
                    decoration: _nameDecoration,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _dropdown<RecordFormat>(
              format,
              [
                for (final value in RecordFormat.values)
                  DropdownMenuItem(
                      value: value, child: Text(value.label(language))),
              ],
              (value) => setState(() => format = value ?? format),
            ),
            const SizedBox(height: 12),
            _dropdown<String>(
              group,
              [
                for (final value in muscleCatalog)
                  DropdownMenuItem(
                      value: value.code, child: Text(value.name(language))),
              ],
              (value) => setState(() => group = value ?? group),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                if (widget.exercise != null) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        appState.archiveExercise(widget.exercise!);
                        Navigator.pop(context);
                      },
                      style: _buttonStyle(danger: true),
                      child:
                          const Text('Удалить', style: TextStyle(fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: _buttonStyle(),
                    child: const Text('Отмена', style: TextStyle(fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: _save,
                    style: _buttonStyle(filled: true),
                    child: const Text('Сохранить',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
