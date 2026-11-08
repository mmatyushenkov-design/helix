import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme.dart';

class FinishResult {
  final double oldTm;
  final double step;
  const FinishResult(this.oldTm, this.step);
}

/// Единое состояние локального приложения. Все операции доступны офлайн.
class AppState extends ChangeNotifier {
  final List<Exercise> exercises = [];
  final List<Cycle> cycles = [];
  final List<WorkoutTemplate> templates = [];
  final Map<String, List<DiaryEntry>> log = {};
  Color accent = AppColors.accentGreen;
  String language = 'ru';
  WeightUnit weightUnit = WeightUnit.kg;
  DistanceUnit distanceUnit = DistanceUnit.km;
  int tabIndex = 0;

  void seed() {
    exercises
      ..clear()
      ..addAll(defaultExercises());
    cycles.clear();
    templates.clear();
    log.clear();
    for (final (name, bestW, bestR, tm, step, curDay) in [
      ('Приседания', 140.0, 5, 163.0, 5.0, 1),
      ('Жим лёжа', 100.0, 6, 120.0, 2.5, 0),
      ('Становая тяга', 180.0, 3, 195.0, 5.0, 3),
    ]) {
      cycles.add(Cycle(
        name: name,
        bestW: bestW,
        bestR: bestR,
        tm: tm,
        step: step,
        curDay: curDay,
        days: tmpl531days(),
      ));
    }
    final today = DateTime.now();
    void mk(int daysAgo, String name, List<List<num>> sets,
        [String? cycleId, int? dayIdx]) {
      final exercise = exerciseByName(name);
      final k = dkey(today.subtract(Duration(days: daysAgo)));
      (log[k] ??= []).add(DiaryEntry(
        exerciseId: exercise?.id,
        name: name,
        recordFormat: exercise?.format ?? RecordFormat.weightReps,
        cycleId: cycleId,
        dayIdx: dayIdx,
        done: true,
        sets: [
          for (final s in sets)
            DiarySet(
              w: s[0].toDouble(),
              reps: s[1].toInt(),
              rir: s[2].toInt(),
              durationSec: s.length > 3 ? s[3].toInt() : 0,
              distanceM: s.length > 4 ? s[4].toDouble() : 0,
            )
        ],
      ));
    }

    const benchW = [
      92.0,
      95,
      95,
      97.5,
      100,
      100,
      102.5,
      105,
      105,
      107.5,
      110,
      112.5,
      115,
      117.5
    ];
    for (var i = 0; i < benchW.length; i++) {
      mk(60 - i * 4, 'Жим лёжа', [
        [benchW[i], 5, 2],
        [benchW[i], 5, 2],
        [benchW[i], 4, 1]
      ]);
    }
    const squatW = [115.0, 120, 122.5, 125, 127.5, 130, 132.5, 135, 137.5, 140];
    for (var i = 0; i < squatW.length; i++) {
      mk(55 - i * 5, 'Приседания', [
        [squatW[i], 5, 2],
        [squatW[i], 5, 1],
        [squatW[i], 4, 1]
      ]);
    }
    const pullR = [6, 7, 7, 8, 8, 9];
    for (var i = 0; i < pullR.length; i++) {
      mk(40 - i * 6, 'Подтягивания', [
        [0, pullR[i], 2],
        [0, pullR[i] - 1, 1]
      ]);
    }
    mk(
        0,
        'Жим лёжа',
        [
          [60, 10, 5],
          [114, 3, 2],
          [114, 3, 2]
        ],
        cycles[1].id,
        0);
  }

  Exercise? exerciseById(String? id) {
    if (id == null) return null;
    for (final e in exercises) {
      if (e.id == id) return e;
    }
    return null;
  }

  Exercise? exerciseByName(String name) {
    for (final e in exercises) {
      if (e.nameRu == name || e.nameEn == name) return e;
    }
    return null;
  }

  String exerciseName(String exerciseId, [String? fallback]) =>
      exerciseById(exerciseId)?.name(language) ?? fallback ?? '';

  double weightFromKg(double kg) => kgToDisplay(kg, weightUnit);
  double weightToKg(double value) => displayToKg(value, weightUnit);
  double distanceFromMeters(double meters) =>
      metersToDisplay(meters, distanceUnit);
  double distanceToMeters(double value) => displayToMeters(value, distanceUnit);
  String get weightLabel => weightUnitLabel(weightUnit, language);
  String get distanceLabel => distanceUnitLabel(distanceUnit, language);

  void setAccent(Color c) {
    accent = c;
    notifyListeners();
  }

  void setLanguage(String value) {
    language = value;
    notifyListeners();
  }

  void setWeightUnit(WeightUnit value) {
    weightUnit = value;
    notifyListeners();
  }

  void setDistanceUnit(DistanceUnit value) {
    distanceUnit = value;
    notifyListeners();
  }

  void goToTab(int i) {
    if (tabIndex == i) return;
    tabIndex = i;
    notifyListeners();
  }

  void touch() => notifyListeners();

  Exercise saveExercise(Exercise exercise) {
    final index = exercises.indexWhere((e) => e.id == exercise.id);
    if (index < 0) {
      exercises.add(exercise);
    } else {
      exercises[index] = exercise;
    }
    notifyListeners();
    return exercise;
  }

  void archiveExercise(Exercise exercise) {
    exercise.archived = true;
    notifyListeners();
  }

  void moveExercise(Exercise exercise, Exercise target, bool after) {
    exercises.removeWhere((e) => e.id == exercise.id);
    var index = exercises.indexWhere((e) => e.id == target.id);
    if (index < 0) index = exercises.length;
    exercises.insert(after ? index + 1 : index, exercise);
    notifyListeners();
  }

  Cycle? cycleById(String? id) {
    if (id == null) return null;
    for (final c in cycles) {
      if (c.id == id) return c;
    }
    return null;
  }

  Cycle addCycle(String exerciseIdOrName) {
    final exercise =
        exerciseById(exerciseIdOrName) ?? exerciseByName(exerciseIdOrName);
    if (exercise == null) throw ArgumentError('Неизвестное упражнение');
    if (exercise.format != RecordFormat.weightReps) {
      throw ArgumentError(
          'Силовой цикл доступен только для формата «вес + повторения»');
    }
    final c = Cycle(
      exerciseId: exercise.id,
      name: exercise.nameRu,
      bestW: 100,
      bestR: 5,
      tm: calcTM(100, 5),
      step: exercise.defaultStepKg,
      days: tmpl531days(),
    );
    cycles.add(c);
    notifyListeners();
    return c;
  }

  void deleteCycle(Cycle c) {
    cycles.removeWhere((x) => x.id == c.id);
    notifyListeners();
  }

  WorkoutTemplate saveTemplate(WorkoutTemplate template) {
    final index = templates.indexWhere((t) => t.id == template.id);
    if (index < 0) {
      templates.add(template);
    } else {
      templates[index] = template;
    }
    notifyListeners();
    return template;
  }

  void deleteTemplate(WorkoutTemplate template) {
    templates.removeWhere((t) => t.id == template.id);
    notifyListeners();
  }

  List<DiaryEntry> entriesOf(DateTime date) => log[dkey(date)] ??= [];

  /// Мышечные группы, задействованные в записи дня (по основным мышцам).
  Set<String> entryMuscleGroups(DiaryEntry entry) {
    final exercise =
        exerciseById(entry.exerciseId) ?? exerciseByName(entry.name);
    if (exercise == null) return {};
    final groups = <String>{};
    for (final group in muscleCatalog) {
      final codes = group.muscles.map((m) => m.code);
      if (exercise.primaryMuscles.any(codes.contains)) groups.add(group.code);
    }
    return groups;
  }

  /// Уникальные группы мышц дня в порядке каталога — для точек календаря.
  List<String> dayMuscleGroups(DateTime date) {
    final entries = log[dkey(date)];
    if (entries == null || entries.isEmpty) return const [];
    final groups = <String>{};
    for (final entry in entries) {
      groups.addAll(entryMuscleGroups(entry));
    }
    return [
      for (final group in muscleCatalog)
        if (groups.contains(group.code)) group.code
    ];
  }

  DiaryEntry addEntry(
    DateTime date,
    String name, {
    String? exerciseId,
    RecordFormat? recordFormat,
    String? cycleId,
    int? dayIdx,
    String? templateItemId,
    List<DiarySet>? presetSets,
    bool notify = true,
  }) {
    final exercise = exerciseById(exerciseId) ?? exerciseByName(name);
    final e = DiaryEntry(
      exerciseId: exercise?.id ?? exerciseId,
      name: exercise?.nameRu ?? name,
      recordFormat: recordFormat ?? exercise?.format ?? RecordFormat.weightReps,
      cycleId: cycleId,
      dayIdx: dayIdx,
      templateItemId: templateItemId,
      sets: presetSets ?? [],
    );
    entriesOf(date).add(e);
    if (notify) notifyListeners();
    return e;
  }

  void startCycleDay(Cycle c) {
    addEntry(
      DateTime.now(),
      c.name,
      exerciseId: c.exerciseId,
      recordFormat: RecordFormat.weightReps,
      cycleId: c.id,
      dayIdx: c.curDay,
      presetSets: [
        for (final s in c.days[c.curDay].sets)
          DiarySet(w: setWeight(c, s), reps: s.reps, rir: s.rir, planned: true),
      ],
    );
    goToTab(2);
  }

  void applyTemplate(WorkoutTemplate template, DateTime date) {
    for (final item in template.items) {
      final exercise = exerciseById(item.exerciseId);
      if (exercise == null) continue;
      addEntry(
        date,
        exercise.nameRu,
        exerciseId: exercise.id,
        recordFormat: exercise.format,
        templateItemId: item.id,
        presetSets: [
          for (final s in item.sets)
            DiarySet(
              w: s.w,
              reps: s.reps,
              rir: s.rir,
              durationSec: s.durationSec,
              distanceM: s.distanceM,
              planned: true,
            )
        ],
        notify: false,
      );
    }
    notifyListeners();
  }

  bool _hasLater(DiaryEntry e, Cycle c) =>
      log.values.expand((x) => x).any((x) =>
          !identical(x, e) &&
          x.cycleId == c.id &&
          x.dayIdx != null &&
          x.dayIdx! > (e.dayIdx ?? -1));

  void _bump(Cycle c, double dir) {
    c.tm += c.step * dir;
    c.wOffset += c.step * dir;
    for (final d in c.days) {
      for (final s in d.sets) {
        if (s.w != null) {
          s.w = ((s.w! + c.step * dir) * 100).roundToDouble() / 100;
        }
      }
    }
  }

  FinishResult? finishEntry(DiaryEntry e) {
    e.sets.removeWhere((s) => s.planned);
    e.done = true;
    FinishResult? res;
    final c = cycleById(e.cycleId);
    if (c != null && e.dayIdx == c.curDay) {
      if (c.curDay >= c.days.length - 1) {
        res = FinishResult(c.tm, c.step);
        _bump(c, 1);
        c.curDay = 0;
        e.bumped = true;
      } else {
        c.curDay++;
      }
    }
    notifyListeners();
    return res;
  }

  void undoFinish(DiaryEntry e) {
    e.done = false;
    final c = cycleById(e.cycleId);
    if (c != null && !_hasLater(e, c)) {
      if (e.bumped) {
        _bump(c, -1);
        c.curDay = e.dayIdx!;
        e.bumped = false;
      } else if (c.curDay == (e.dayIdx ?? -2) + 1) {
        c.curDay = e.dayIdx!;
      }
    }
    notifyListeners();
  }

  void deleteEntry(DateTime date, DiaryEntry e) {
    entriesOf(date).removeWhere((x) => x.id == e.id);
    final c = cycleById(e.cycleId);
    if (c != null && !_hasLater(e, c)) {
      if (e.bumped) {
        _bump(c, -1);
        c.curDay = e.dayIdx!;
      } else if (c.curDay == (e.dayIdx ?? -2) + 1) {
        c.curDay = e.dayIdx!;
      }
    }
    notifyListeners();
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': 2,
        'exercises': [for (final e in exercises) e.toJson()],
        'cycles': [for (final c in cycles) c.toJson()],
        'templates': [for (final t in templates) t.toJson()],
        'log': log.map((k, v) => MapEntry(k, [for (final e in v) e.toJson()])),
        'accent': accent.toARGB32(),
        'language': language,
        'weightUnit': weightUnit.name,
        'distanceUnit': distanceUnit.name,
      };

  void loadJson(Map<String, dynamic> j) {
    exercises.clear();
    for (final raw in j['exercises'] as List? ?? const []) {
      exercises.add(Exercise.fromJson(Map<String, dynamic>.from(raw as Map)));
    }
    for (final exercise in defaultExercises()) {
      if (!exercises.any((e) => e.id == exercise.id)) exercises.add(exercise);
    }
    cycles
      ..clear()
      ..addAll([
        for (final c in j['cycles'] as List? ?? const []) Cycle.fromJson(c)
      ]);
    log
      ..clear()
      ..addAll((j['log'] as Map<String, dynamic>? ?? {}).map((k, v) =>
          MapEntry(k, [for (final e in v as List) DiaryEntry.fromJson(e)])));
    templates
      ..clear()
      ..addAll([
        for (final t in j['templates'] as List? ?? const [])
          WorkoutTemplate.fromJson(t)
      ]);

    // Старые снапшоты не содержали каталога и формата: восстанавливаем связи.
    for (final cycle in cycles) {
      final exercise =
          exerciseById(cycle.exerciseId) ?? exerciseByName(cycle.name);
      if (exercise != null) cycle.exerciseId = exercise.id;
    }
    for (final entries in log.values) {
      for (final entry in entries) {
        final exercise =
            exerciseById(entry.exerciseId) ?? exerciseByName(entry.name);
        if (exercise != null) {
          entry.exerciseId = exercise.id;
          if (j['schemaVersion'] == null) entry.recordFormat = exercise.format;
        }
      }
    }
    accent = Color(j['accent'] as int? ?? AppColors.accentGreen.toARGB32());
    language = j['language'] as String? ?? 'ru';
    weightUnit = WeightUnit.values.firstWhere((u) => u.name == j['weightUnit'],
        orElse: () => WeightUnit.kg);
    distanceUnit = DistanceUnit.values.firstWhere(
        (u) => u.name == j['distanceUnit'],
        orElse: () => DistanceUnit.km);
  }
}

final AppState appState = AppState()..seed();
