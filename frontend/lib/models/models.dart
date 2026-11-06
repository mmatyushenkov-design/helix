/// Модели и чистые расчёты приложения. В БД вес всегда в кг, время в секундах,
/// дистанция в метрах. UI преобразует их в выбранные единицы только на границе.
library;

import 'package:uuid/uuid.dart';

const _uuid = Uuid();
String newId() => _uuid.v4();
String stableId(String kind, Object key) => _uuid.v5(Namespace.url.value, 'workout-tracker/$kind/$key');
String exerciseIdForName(String name) => stableId('exercise', name.trim().toLowerCase());

enum RecordFormat {
  weightReps('WEIGHT_REPS'),
  weightTime('WEIGHT_TIME'),
  timeReps('TIME_REPS'),
  timeDistance('TIME_DISTANCE');

  final String code;
  const RecordFormat(this.code);

  static RecordFormat fromCode(String? code) => RecordFormat.values.firstWhere(
        (f) => f.code == code,
        orElse: () => RecordFormat.weightReps,
      );

  String label(String language) => switch ((this, language)) {
        (RecordFormat.weightReps, 'en') => 'Weight + reps',
        (RecordFormat.weightTime, 'en') => 'Weight + time',
        (RecordFormat.timeReps, 'en') => 'Time + reps',
        (RecordFormat.timeDistance, 'en') => 'Time + distance',
        (RecordFormat.weightReps, _) => 'Вес + повторения',
        (RecordFormat.weightTime, _) => 'Вес + время',
        (RecordFormat.timeReps, _) => 'Время + повторения',
        (RecordFormat.timeDistance, _) => 'Время + дистанция',
      };

  bool get usesWeight => this == RecordFormat.weightReps || this == RecordFormat.weightTime;
  bool get usesReps => this == RecordFormat.weightReps || this == RecordFormat.timeReps;
  bool get usesTime => this != RecordFormat.weightReps;
  bool get usesDistance => this == RecordFormat.timeDistance;
  bool get usesRir => this != RecordFormat.timeDistance;
}

enum WeightUnit { kg, lb }
enum DistanceUnit { km, mi }

double kgToDisplay(double kg, WeightUnit unit) => unit == WeightUnit.lb ? kg * 2.2046226218 : kg;
double displayToKg(double value, WeightUnit unit) => unit == WeightUnit.lb ? value / 2.2046226218 : value;
double metersToDisplay(double meters, DistanceUnit unit) =>
    unit == DistanceUnit.mi ? meters / 1609.344 : meters / 1000;
double displayToMeters(double value, DistanceUnit unit) =>
    unit == DistanceUnit.mi ? value * 1609.344 : value * 1000;
String weightUnitLabel(WeightUnit unit) => unit == WeightUnit.lb ? 'lb' : 'кг';
String distanceUnitLabel(DistanceUnit unit) => unit == DistanceUnit.mi ? 'mi' : 'км';

String fmtW(double w) {
  if (w == w.truncateToDouble()) return w.truncate().toString();
  var s = w.toStringAsFixed(2);
  s = s.replaceFirst(RegExp(r'0+$'), '');
  if (s.endsWith('.')) s = s.substring(0, s.length - 1);
  return s.replaceAll('.', ',');
}

String fmtDuration(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  return '$m:${s.toString().padLeft(2, '0')}';
}

String dkey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class MuscleGroup {
  final String code;
  final String ru;
  final String en;
  final List<Muscle> muscles;
  const MuscleGroup(this.code, this.ru, this.en, this.muscles);
  String name(String language) => language == 'en' ? en : ru;
}

class Muscle {
  final String code;
  final String ru;
  final String en;
  const Muscle(this.code, this.ru, this.en);
  String name(String language) => language == 'en' ? en : ru;
}

const muscleCatalog = <MuscleGroup>[
  MuscleGroup('chest', 'Грудь', 'Chest', [
    Muscle('upper_chest', 'Верх груди', 'Upper chest'),
    Muscle('mid_chest', 'Центр груди', 'Mid chest'),
    Muscle('lower_chest', 'Низ груди', 'Lower chest'),
  ]),
  MuscleGroup('arms', 'Руки', 'Arms', [
    Muscle('biceps', 'Бицепс', 'Biceps'),
    Muscle('triceps', 'Трицепс', 'Triceps'),
    Muscle('forearms', 'Предплечья', 'Forearms'),
  ]),
  MuscleGroup('back', 'Спина', 'Back', [
    Muscle('mid_back', 'Центр спины', 'Mid back'),
    Muscle('lats', 'Широчайшие', 'Lats'),
    Muscle('lower_back', 'Поясница', 'Lower back'),
  ]),
  MuscleGroup('legs', 'Ноги', 'Legs', [
    Muscle('quads', 'Квадрицепсы', 'Quads'),
    Muscle('hamstrings', 'Бицепс бедра', 'Hamstrings'),
    Muscle('glutes', 'Ягодицы', 'Glutes'),
    Muscle('calves', 'Икры', 'Calves'),
  ]),
  MuscleGroup('shoulders', 'Плечи', 'Shoulders', [
    Muscle('front_delts', 'Передние дельты', 'Front delts'),
    Muscle('side_delts', 'Средние дельты', 'Side delts'),
    Muscle('rear_delts', 'Задние дельты', 'Rear delts'),
  ]),
  MuscleGroup('core', 'Корпус', 'Core', [
    Muscle('abs', 'Пресс', 'Abs'),
    Muscle('obliques', 'Косые мышцы', 'Obliques'),
    Muscle('core_stability', 'Стабилизаторы', 'Stabilizers'),
  ]),
  MuscleGroup('full_body', 'Фулбади', 'Full body', [
    Muscle('whole_body', 'Всё тело', 'Whole body'),
  ]),
  MuscleGroup('cardio', 'Кардио', 'Cardio', [
    Muscle('cardio', 'Кардионагрузка', 'Cardio'),
  ]),
];

class Exercise {
  String id;
  String nameRu;
  String nameEn;
  RecordFormat format;
  double defaultStepKg;
  List<String> primaryMuscles;
  List<String> secondaryMuscles;
  bool isCustom;
  bool archived;

  Exercise({
    String? id,
    required this.nameRu,
    String? nameEn,
    this.format = RecordFormat.weightReps,
    this.defaultStepKg = 5,
    this.primaryMuscles = const [],
    this.secondaryMuscles = const [],
    this.isCustom = false,
    this.archived = false,
  })  : id = id ?? exerciseIdForName(nameRu),
        nameEn = nameEn ?? nameRu;

  String name(String language) => language == 'en' ? nameEn : nameRu;

  Map<String, dynamic> toJson() => {
        'id': id,
        'nameRu': nameRu,
        'nameEn': nameEn,
        'format': format.code,
        'defaultStepKg': defaultStepKg,
        'primaryMuscles': primaryMuscles,
        'secondaryMuscles': secondaryMuscles,
        'isCustom': isCustom,
        'archived': archived,
      };

  factory Exercise.fromJson(Map<String, dynamic> j) => Exercise(
        id: j['id']?.toString(),
        nameRu: j['nameRu'] as String? ?? j['name'] as String? ?? 'Упражнение',
        nameEn: j['nameEn'] as String?,
        format: RecordFormat.fromCode(j['format'] as String?),
        defaultStepKg: (j['defaultStepKg'] as num? ?? j['defaultStep'] as num? ?? 5).toDouble(),
        primaryMuscles: [for (final v in j['primaryMuscles'] as List? ?? const []) v.toString()],
        secondaryMuscles: [for (final v in j['secondaryMuscles'] as List? ?? const []) v.toString()],
        isCustom: j['isCustom'] as bool? ?? false,
        archived: j['archived'] as bool? ?? false,
      );
}

List<Exercise> defaultExercises() => [
      Exercise(nameRu: 'Приседания', nameEn: 'Squat', primaryMuscles: ['quads', 'glutes'], secondaryMuscles: ['hamstrings', 'lower_back']),
      Exercise(nameRu: 'Жим лёжа', nameEn: 'Bench press', defaultStepKg: 2.5, primaryMuscles: ['mid_chest'], secondaryMuscles: ['triceps', 'front_delts']),
      Exercise(nameRu: 'Становая тяга', nameEn: 'Deadlift', primaryMuscles: ['lower_back', 'glutes'], secondaryMuscles: ['hamstrings', 'forearms']),
      Exercise(nameRu: 'Жим лёжа узким хватом', nameEn: 'Close-grip bench press', defaultStepKg: 2.5, primaryMuscles: ['triceps'], secondaryMuscles: ['mid_chest', 'front_delts']),
      Exercise(nameRu: 'Жим стоя', nameEn: 'Overhead press', primaryMuscles: ['front_delts', 'side_delts'], secondaryMuscles: ['triceps']),
      Exercise(nameRu: 'Тяга штанги в наклоне', nameEn: 'Barbell row', primaryMuscles: ['lats', 'mid_back'], secondaryMuscles: ['biceps', 'lower_back']),
      Exercise(nameRu: 'Подтягивания', nameEn: 'Pull-up', primaryMuscles: ['lats'], secondaryMuscles: ['biceps', 'mid_back']),
      Exercise(nameRu: 'Болгарские выпады', nameEn: 'Bulgarian split squat', primaryMuscles: ['quads', 'glutes'], secondaryMuscles: ['hamstrings']),
      Exercise(nameRu: 'Румынская тяга', nameEn: 'Romanian deadlift', primaryMuscles: ['hamstrings', 'glutes'], secondaryMuscles: ['lower_back']),
      Exercise(nameRu: 'Французский жим', nameEn: 'Skull crusher', defaultStepKg: 2.5, primaryMuscles: ['triceps']),
      Exercise(nameRu: 'Бицепс со штангой', nameEn: 'Barbell curl', defaultStepKg: 2.5, primaryMuscles: ['biceps'], secondaryMuscles: ['forearms']),
      Exercise(nameRu: 'Планка', nameEn: 'Plank', format: RecordFormat.weightTime, primaryMuscles: ['abs', 'core_stability']),
      Exercise(nameRu: 'Бег', nameEn: 'Running', format: RecordFormat.timeDistance, primaryMuscles: ['cardio']),
      Exercise(nameRu: 'Вис на турнике', nameEn: 'Dead hang', format: RecordFormat.timeReps, primaryMuscles: ['forearms'], secondaryMuscles: ['lats']),
    ];

final exerciseNames = [for (final e in defaultExercises()) e.nameRu];

class CycleSet {
  double? w;
  int? pct;
  int reps;
  int rir;
  int durationSec;
  double distanceM;

  CycleSet({
    this.w,
    this.pct,
    required this.reps,
    required this.rir,
    this.durationSec = 0,
    this.distanceM = 0,
  });

  Map<String, dynamic> toJson() => {
        'w': w,
        'pct': pct,
        'reps': reps,
        'rir': rir,
        'durationSec': durationSec,
        'distanceM': distanceM,
      };

  factory CycleSet.fromJson(Map<String, dynamic> j) => CycleSet(
        w: (j['w'] as num?)?.toDouble(),
        pct: j['pct'] as int?,
        reps: j['reps'] as int? ?? 0,
        rir: j['rir'] as int? ?? 0,
        durationSec: j['durationSec'] as int? ?? 0,
        distanceM: (j['distanceM'] as num? ?? 0).toDouble(),
      );
}

class CycleDay {
  List<CycleSet> sets;
  CycleDay(this.sets);
  Map<String, dynamic> toJson() => {'sets': [for (final s in sets) s.toJson()]};
  factory CycleDay.fromJson(Map<String, dynamic> j) =>
      CycleDay([for (final s in j['sets'] as List) CycleSet.fromJson(s)]);
}

class Cycle {
  String id;
  String exerciseId;
  String name;
  double bestW;
  int bestR;
  double tm;
  double step;
  double wOffset;
  int curDay;
  List<CycleDay> days;

  Cycle({
    String? id,
    String? exerciseId,
    required this.name,
    required this.bestW,
    required this.bestR,
    required this.tm,
    required this.step,
    this.wOffset = 0,
    this.curDay = 0,
    required this.days,
  })  : id = id ?? newId(),
        exerciseId = exerciseId ?? exerciseIdForName(name);

  Map<String, dynamic> toJson() => {
        'id': id,
        'exerciseId': exerciseId,
        'name': name,
        'bestW': bestW,
        'bestR': bestR,
        'tm': tm,
        'step': step,
        'wOffset': wOffset,
        'curDay': curDay,
        'days': [for (final d in days) d.toJson()],
      };

  factory Cycle.fromJson(Map<String, dynamic> j) => Cycle(
        id: j['id'] is int ? stableId('cycle', j['id']) : j['id']?.toString(),
        exerciseId: j['exerciseId']?.toString(),
        name: j['name'] as String,
        bestW: (j['bestW'] as num).toDouble(),
        bestR: j['bestR'] as int,
        tm: (j['tm'] as num).toDouble(),
        step: (j['step'] as num).toDouble(),
        wOffset: (j['wOffset'] as num?)?.toDouble() ?? 0,
        curDay: j['curDay'] as int? ?? 0,
        days: [for (final d in j['days'] as List) CycleDay.fromJson(d)],
      );
}

double setWeight(Cycle c, CycleSet s) {
  if (s.w != null) return s.w!;
  final exact = c.tm * s.pct! / 100 + c.wOffset;
  return ((exact / c.step).round() * c.step * 100).roundToDouble() / 100;
}

String dayChipLabel(Cycle c, int i) => c.days.length <= 5 ? 'день ${i + 1}' : 'д.${i + 1}';

class DiarySet {
  double w;
  int reps;
  int rir;
  int durationSec;
  double distanceM;
  bool planned;

  DiarySet({
    this.w = 0,
    this.reps = 0,
    this.rir = 0,
    this.durationSec = 0,
    this.distanceM = 0,
    this.planned = false,
  });

  Map<String, dynamic> toJson() => {
        'w': w,
        'reps': reps,
        'rir': rir,
        'durationSec': durationSec,
        'distanceM': distanceM,
        'planned': planned,
      };

  factory DiarySet.fromJson(Map<String, dynamic> j) => DiarySet(
        w: (j['w'] as num? ?? 0).toDouble(),
        reps: j['reps'] as int? ?? 0,
        rir: j['rir'] as int? ?? 0,
        durationSec: j['durationSec'] as int? ?? 0,
        distanceM: (j['distanceM'] as num? ?? 0).toDouble(),
        planned: j['planned'] as bool? ?? false,
      );
}

class DiaryEntry {
  String id;
  String exerciseId;
  String name;
  RecordFormat recordFormat;
  String? cycleId;
  int? dayIdx;
  String? templateItemId;
  bool done;
  bool bumped;
  List<DiarySet> sets;

  DiaryEntry({
    String? id,
    String? exerciseId,
    required this.name,
    this.recordFormat = RecordFormat.weightReps,
    this.cycleId,
    this.dayIdx,
    this.templateItemId,
    this.done = false,
    this.bumped = false,
    required this.sets,
  })  : id = id ?? newId(),
        exerciseId = exerciseId ?? exerciseIdForName(name);

  Map<String, dynamic> toJson() => {
        'id': id,
        'exerciseId': exerciseId,
        'name': name,
        'recordFormat': recordFormat.code,
        'cycleId': cycleId,
        'dayIdx': dayIdx,
        'templateItemId': templateItemId,
        'done': done,
        'bumped': bumped,
        'sets': [for (final s in sets) s.toJson()],
      };

  factory DiaryEntry.fromJson(Map<String, dynamic> j) => DiaryEntry(
        id: j['id'] is int ? stableId('entry', j['id']) : j['id']?.toString(),
        exerciseId: j['exerciseId']?.toString(),
        name: j['name'] as String,
        recordFormat: RecordFormat.fromCode(j['recordFormat'] as String?),
        cycleId: j['cycleId'] is int ? stableId('cycle', j['cycleId']) : j['cycleId']?.toString(),
        dayIdx: j['dayIdx'] as int?,
        templateItemId: j['templateItemId']?.toString(),
        done: j['done'] as bool? ?? false,
        bumped: j['bumped'] as bool? ?? false,
        sets: [for (final s in j['sets'] as List) DiarySet.fromJson(s)],
      );
}

class TemplateItem {
  String id;
  String exerciseId;
  List<DiarySet> sets;
  TemplateItem({String? id, required this.exerciseId, this.sets = const []}) : id = id ?? newId();
  Map<String, dynamic> toJson() => {'id': id, 'exerciseId': exerciseId, 'sets': [for (final s in sets) s.toJson()]};
  factory TemplateItem.fromJson(Map<String, dynamic> j) => TemplateItem(
        id: j['id']?.toString(),
        exerciseId: j['exerciseId'] as String,
        sets: [for (final s in j['sets'] as List? ?? const []) DiarySet.fromJson(s)],
      );
}

class WorkoutTemplate {
  String id;
  String name;
  String description;
  List<TemplateItem> items;
  WorkoutTemplate({String? id, required this.name, this.description = '', this.items = const []}) : id = id ?? newId();
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'items': [for (final i in items) i.toJson()],
      };
  factory WorkoutTemplate.fromJson(Map<String, dynamic> j) => WorkoutTemplate(
        id: j['id']?.toString(),
        name: j['name'] as String,
        description: j['description'] as String? ?? '',
        items: [for (final i in j['items'] as List? ?? const []) TemplateItem.fromJson(i)],
      );
}

List<CycleDay> tmpl531days() => [
      CycleDay([CycleSet(pct: 65, reps: 5, rir: 2), CycleSet(pct: 75, reps: 5, rir: 1), CycleSet(pct: 85, reps: 5, rir: 0)]),
      CycleDay([CycleSet(pct: 70, reps: 3, rir: 2), CycleSet(pct: 80, reps: 3, rir: 1), CycleSet(pct: 90, reps: 3, rir: 0)]),
      CycleDay([CycleSet(pct: 75, reps: 5, rir: 1), CycleSet(pct: 85, reps: 3, rir: 1), CycleSet(pct: 95, reps: 1, rir: 0)]),
      CycleDay([CycleSet(pct: 40, reps: 5, rir: 5), CycleSet(pct: 50, reps: 5, rir: 5), CycleSet(pct: 60, reps: 5, rir: 5)]),
    ];

String rirLabel(int code) => switch (code) {
      -1 => '',
      0 => 'отказ',
      6 => '10+',
      _ => 'RIR $code',
    };

double epley(double w, int r) => w * (1 + r / 30);
double roundDownToStep(double v, double step) => (v / step).floor() * step;
double calcTM(double w, int r) => (w * (1 + r / 30)).roundToDouble();
double defaultStep(String name) => (name.contains('Жим') && !name.contains('стоя')) ? 2.5 : 5;
