import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../state/strings.dart';
import '../theme.dart';

class ExerciseCatalogScreen extends StatefulWidget {
  const ExerciseCatalogScreen({super.key});

  @override
  State<ExerciseCatalogScreen> createState() => _ExerciseCatalogScreenState();
}

class _ExerciseCatalogScreenState extends State<ExerciseCatalogScreen> {
  String query = '';
  String? group;
  String? muscle;
  RecordFormat? format;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final language = appState.language;
        final items = appState.exercises.where((e) {
          if (e.archived) return false;
          if (format != null && e.format != format) return false;
          if (muscle != null &&
              ![...e.primaryMuscles, ...e.secondaryMuscles].contains(muscle)) {
            return false;
          }
          if (group != null) {
            final codes = muscleCatalog
                .firstWhere((g) => g.code == group)
                .muscles
                .map((m) => m.code);
            if (![...e.primaryMuscles, ...e.secondaryMuscles]
                .any(codes.contains)) {
              return false;
            }
          }
          final q = query.toLowerCase();
          return e.name(language).toLowerCase().contains(q) ||
              e.nameRu.toLowerCase().contains(q);
        }).toList();
        final muscles = group == null
            ? muscleCatalog.expand((g) => g.muscles).toList()
            : muscleCatalog.firstWhere((g) => g.code == group).muscles;
        return Scaffold(
          appBar: AppBar(
            leading: const BackButton(),
            title: Text(tr('exercises')),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const ExerciseEditScreen())),
                child: Text(tr('addExercise')),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                onChanged: (v) => setState(() => query = v),
                decoration: InputDecoration(
                  hintText: tr('searchExercise'),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  filled: true,
                  fillColor: AppColors.surface2,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),
              _filter<String>(
                value: group,
                hint: tr('allGroups'),
                items: [
                  for (final g in muscleCatalog) (g.code, g.name(language))
                ],
                onChanged: (v) => setState(() {
                  group = v;
                  muscle = null;
                }),
              ),
              const SizedBox(height: 8),
              _filter<String>(
                value: muscle,
                hint: tr('allMuscles'),
                items: [for (final m in muscles) (m.code, m.name(language))],
                onChanged: (v) => setState(() => muscle = v),
              ),
              const SizedBox(height: 8),
              _filter<RecordFormat>(
                value: format,
                hint: tr('allFormats'),
                items: [
                  for (final f in RecordFormat.values) (f, f.label(language))
                ],
                onChanged: (v) => setState(() => format = v),
              ),
              const SizedBox(height: 14),
              for (final e in items)
                Card(
                  color: AppColors.surface,
                  child: ListTile(
                    title: Text(e.name(language)),
                    subtitle: Text(e.format.label(language),
                        style: const TextStyle(
                            color: AppColors.textDim, fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right,
                        color: AppColors.textDim),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ExerciseEditScreen(exercise: e))),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _filter<T>({
    required T? value,
    required String hint,
    required List<(T, String)> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButton<T>(
        value: value,
        hint: Text(hint),
        isExpanded: true,
        underline: const SizedBox.shrink(),
        dropdownColor: AppColors.surface2,
        items: [
          DropdownMenuItem<T>(value: null, child: Text(hint)),
          for (final item in items)
            DropdownMenuItem(value: item.$1, child: Text(item.$2)),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class ExerciseEditScreen extends StatefulWidget {
  final Exercise? exercise;
  const ExerciseEditScreen({super.key, this.exercise});

  @override
  State<ExerciseEditScreen> createState() => _ExerciseEditScreenState();
}

class _ExerciseEditScreenState extends State<ExerciseEditScreen> {
  late final TextEditingController ru =
      TextEditingController(text: widget.exercise?.nameRu ?? '');
  late final TextEditingController en =
      TextEditingController(text: widget.exercise?.nameEn ?? '');
  late RecordFormat format = widget.exercise?.format ?? RecordFormat.weightReps;
  late double step = widget.exercise?.defaultStepKg ?? 5;
  late final Set<String> primary = {...?widget.exercise?.primaryMuscles};
  late final Set<String> secondary = {...?widget.exercise?.secondaryMuscles};
  String group = muscleCatalog.first.code;

  @override
  void dispose() {
    ru.dispose();
    en.dispose();
    super.dispose();
  }

  void _save() {
    if (ru.text.trim().isEmpty) return;
    final old = widget.exercise;
    final exercise = Exercise(
      id: old?.id,
      nameRu: ru.text.trim(),
      nameEn: en.text.trim().isEmpty ? ru.text.trim() : en.text.trim(),
      format: format,
      defaultStepKg: step,
      primaryMuscles: primary.toList(),
      secondaryMuscles: secondary.toList(),
      isCustom: old?.isCustom ?? true,
    );
    appState.saveExercise(exercise);
    Navigator.pop(context);
  }

  InputDecoration _input(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textDim),
        filled: true,
        fillColor: AppColors.surface2,
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

  @override
  Widget build(BuildContext context) {
    final language = appState.language;
    final muscles = muscleCatalog.firstWhere((g) => g.code == group).muscles;
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(widget.exercise == null
            ? tr('addExercise')
            : widget.exercise!.name(language)),
        actions: [TextButton(onPressed: _save, child: Text(tr('save')))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: ru, decoration: _input(tr('nameRu'))),
          const SizedBox(height: 12),
          TextField(controller: en, decoration: _input(tr('nameEn'))),
          const SizedBox(height: 16),
          Text(tr('recordFormat'),
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _dropdown<RecordFormat>(
            format,
            [
              for (final f in RecordFormat.values)
                DropdownMenuItem(value: f, child: Text(f.label(language))),
            ],
            (v) => setState(() => format = v ?? format),
          ),
          if (format.usesWeight) ...[
            const SizedBox(height: 12),
            Text('${tr('weightUnits')}: ${appState.weightLabel}'),
            const SizedBox(height: 8),
            _dropdown<double>(
              step,
              [
                for (final value in [1.0, 1.25, 2.0, 2.5, 4.0, 5.0])
                  DropdownMenuItem(value: value, child: Text(fmtW(value))),
              ],
              (v) => setState(() => step = v ?? step),
            ),
          ],
          const SizedBox(height: 16),
          _dropdown<String>(
            group,
            [
              for (final g in muscleCatalog)
                DropdownMenuItem(value: g.code, child: Text(g.name(language))),
            ],
            (v) => setState(() => group = v ?? group),
          ),
          const SizedBox(height: 14),
          Text(tr('primaryMuscles'),
              style: const TextStyle(fontWeight: FontWeight.w700)),
          Wrap(
            spacing: 8,
            children: [
              for (final m in muscles)
                FilterChip(
                  label: Text(m.name(language)),
                  backgroundColor: AppColors.surface2,
                  selectedColor: AppColors.accentDim(appState.accent),
                  showCheckmark: false,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  selected: primary.contains(m.code),
                  onSelected: (v) => setState(() {
                    if (v) {
                      primary.add(m.code);
                      secondary.remove(m.code);
                    } else {
                      primary.remove(m.code);
                    }
                  }),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(tr('secondaryMuscles'),
              style: const TextStyle(fontWeight: FontWeight.w700)),
          Wrap(
            spacing: 8,
            children: [
              for (final m in muscles)
                FilterChip(
                  label: Text(m.name(language)),
                  backgroundColor: AppColors.surface2,
                  selectedColor: AppColors.accentDim(appState.accent),
                  showCheckmark: false,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  selected: secondary.contains(m.code),
                  onSelected: (v) => setState(() {
                    if (v) {
                      secondary.add(m.code);
                      primary.remove(m.code);
                    } else {
                      secondary.remove(m.code);
                    }
                  }),
                ),
            ],
          ),
          if (widget.exercise != null) ...[
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () {
                appState.archiveExercise(widget.exercise!);
                Navigator.pop(context);
              },
              child: Text(tr('archive')),
            ),
          ],
        ],
      ),
    );
  }
}
