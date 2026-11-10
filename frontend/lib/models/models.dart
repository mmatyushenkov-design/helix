/// Модели и чистые расчёты приложения. В БД вес всегда в кг, время в секундах,
/// дистанция в метрах. UI преобразует их в выбранные единицы только на границе.
library;

import 'package:uuid/uuid.dart';

const _uuid = Uuid();
String newId() => _uuid.v4();
String stableId(String kind, Object key) =>
    _uuid.v5(Namespace.url.value, 'workout-tracker/$kind/$key');
String exerciseIdForName(String name) =>
    stableId('exercise', name.trim().toLowerCase());

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

  bool get usesWeight =>
      this == RecordFormat.weightReps || this == RecordFormat.weightTime;
  bool get usesReps =>
      this == RecordFormat.weightReps || this == RecordFormat.timeReps;
  bool get usesTime => this != RecordFormat.weightReps;
  bool get usesDistance => this == RecordFormat.timeDistance;
  // RIR только у повторений: вес+повторения и время+повторения.
  bool get usesRir =>
      this == RecordFormat.weightReps || this == RecordFormat.timeReps;
}

enum WeightUnit { kg, lb }

enum DistanceUnit { km, mi }

double kgToDisplay(double kg, WeightUnit unit) =>
    unit == WeightUnit.lb ? kg * 2.2046226218 : kg;
double displayToKg(double value, WeightUnit unit) =>
    unit == WeightUnit.lb ? value / 2.2046226218 : value;
double metersToDisplay(double meters, DistanceUnit unit) =>
    unit == DistanceUnit.mi ? meters / 1609.344 : meters / 1000;
double displayToMeters(double value, DistanceUnit unit) =>
    unit == DistanceUnit.mi ? value * 1609.344 : value * 1000;
String weightUnitLabel(WeightUnit unit, [String language = 'ru']) =>
    unit == WeightUnit.lb
        ? 'lb'
        : language == 'en'
            ? 'kg'
            : 'кг';
String distanceUnitLabel(DistanceUnit unit, [String language = 'ru']) =>
    unit == DistanceUnit.mi
        ? language == 'en'
            ? 'ml'
            : 'mi'
        : language == 'en'
            ? 'km'
            : 'км';

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
  if (h > 0) {
    return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// Длительность с единицей измерения для крупного показателя подхода.
String fmtDurationUnit(int seconds) {
  if (seconds < 60) return '$seconds с';
  if (seconds < 3600) {
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')} мин';
  }
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')} ч';
}

/// Дистанция: до 999 м — в метрах, дальше — километры с двумя знаками.
String fmtDistanceMeters(double meters) {
  if (meters > 999) {
    return '${(meters / 1000).toStringAsFixed(2).replaceAll('.', ',')} км';
  }
  return '${meters.round()} м';
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
  MuscleGroup('back', 'Спина', 'Back', [
    Muscle('mid_back', 'Центр спины', 'Mid back'),
    Muscle('lats', 'Широчайшие', 'Lats'),
    Muscle('lower_back', 'Поясница', 'Lower back'),
  ]),
  MuscleGroup('shoulders', 'Плечи', 'Shoulders', [
    Muscle('front_delts', 'Передние дельты', 'Front delts'),
    Muscle('side_delts', 'Средние дельты', 'Side delts'),
    Muscle('rear_delts', 'Задние дельты', 'Rear delts'),
  ]),
  MuscleGroup('arms', 'Руки', 'Arms', [
    Muscle('biceps', 'Бицепс', 'Biceps'),
    Muscle('triceps', 'Трицепс', 'Triceps'),
    Muscle('forearms', 'Предплечья', 'Forearms'),
  ]),
  MuscleGroup('legs', 'Ноги', 'Legs', [
    Muscle('quads', 'Квадрицепсы', 'Quads'),
    Muscle('hamstrings', 'Бицепс бедра', 'Hamstrings'),
    Muscle('glutes', 'Ягодицы', 'Glutes'),
    Muscle('calves', 'Икры', 'Calves'),
  ]),
  MuscleGroup('core', 'Корпус', 'Core', [
    Muscle('abs', 'Пресс', 'Abs'),
    Muscle('obliques', 'Косые мышцы', 'Obliques'),
    Muscle('core_stability', 'Стабилизаторы', 'Stabilizers'),
  ]),
  MuscleGroup('cardio', 'Кардио', 'Cardio', [
    Muscle('cardio', 'Кардионагрузка', 'Cardio'),
  ]),
  MuscleGroup('full_body', 'Фулбади', 'Full body', [
    Muscle('whole_body', 'Всё тело', 'Whole body'),
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
  bool favorite;

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
    this.favorite = false,
  })  : id = id ?? exerciseIdForName(nameRu),
        nameEn = nameEn ?? nameRu;

  String name(String language) => language == 'en' ? nameEn : nameRu;

  /// В силовой цикл можно добавлять только классический формат веса и повторений.
  bool get canUseInCycle => format == RecordFormat.weightReps;

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
        'favorite': favorite,
      };

  factory Exercise.fromJson(Map<String, dynamic> j) => Exercise(
        id: j['id']?.toString(),
        nameRu: j['nameRu'] as String? ?? j['name'] as String? ?? 'Упражнение',
        nameEn: j['nameEn'] as String?,
        format: RecordFormat.fromCode(j['format'] as String?),
        defaultStepKg:
            (j['defaultStepKg'] as num? ?? j['defaultStep'] as num? ?? 5)
                .toDouble(),
        primaryMuscles: [
          for (final v in j['primaryMuscles'] as List? ?? const []) v.toString()
        ],
        secondaryMuscles: [
          for (final v in j['secondaryMuscles'] as List? ?? const [])
            v.toString()
        ],
        isCustom: j['isCustom'] as bool? ?? false,
        archived: j['archived'] as bool? ?? false,
        favorite: j['favorite'] as bool? ?? false,
      );
}

const _defaultExerciseNames = <(String, List<String>)>[
  (
    'chest',
    [
      'Жим лёжа',
      'Жим лёжа · накл',
      'Жим в Смите лежа',
      'Жим в Смите лежа · накл',
      'Жим гантелей лежа',
      'Жим гантелей лежа · накл',
      'Жим в тренажёре',
      'Бабочка',
      'Разведение гантелей',
      'Разведение гантелей · накл',
      'Сведение рук в кроссовере',
      'Отжимания',
      'Отжимания в наклоне',
      'Отжимания с ногами на возвышении',
      'Брусья на грудь',
      'Пуловер со штангой',
      'Пуловер с гантелью',
    ]
  ),
  (
    'back',
    [
      'Тяга верхнего блока',
      'Тяга верхнего блока широким хватом',
      'Вертикальная тяга в тренажере',
      'Тяга верхнего блока узким хватом',
      'Подтягивания',
      'Подтягивания средним хватом',
      'Подтягивания широким хватом',
      'Горизонтальные подтягивания',
      'Подтягивания в гравитроне',
      'Тяга блока к поясу сидя',
      'Тяга штанги в наклоне',
      'Тяга штанги в наклоне в тренажере Смита',
      'Тяга штанги к поясу',
      'Тяга гантелей в наклоне',
      'Тяга одной гантели в наклоне',
      'Тяга гантелей на наклонной скамье',
      'Горизонтальная рычажная тяга',
      'Тяга Т-грифа',
      'Тяга верхнего блока обратным узким хватом',
      'Пуловер в кроссовере по одной руке',
      'Пуловер в тренажере',
      'Шраги на горизонтальном блоке',
      'Шраги в тренажере Смита',
      'Шраги с гантелями',
      'Шраги со штангой',
      'Шраги со штангой за спиной',
      'Шраги со штангой за спиной в тренажере Смита',
      'Шраги в тренажере',
      'Шраги с гантелями на наклонной скамье',
      'Гиперэкстензия',
      'Обратная гиперэкстензия',
      'Гиперэкстензия на фитболе',
      'Лодочка',
    ]
  ),
  (
    'shoulders',
    [
      'Жим стоя',
      'Жим сидя',
      'Жим сидя в тренажере Смита',
      'Жим гантелей сидя',
      'Махи на блоке',
      'Махи в тренажёре',
      'Тяга каната на задние дельты',
      'Махи гантелей в наклоне',
      'Отжимания уголком',
      'Отжимания стоя на руках',
      'Тяга штанги к подбородку',
      'Тяга гантелей к подбородку',
      'Тяга к подбородку в тренажере Смита',
    ]
  ),
  (
    'arms',
    [
      'Сгибание рук со штангой',
      'Сгибание рук с гантелями',
      'Сгибание рук с гантелями сидя',
      'Сгибание рук с гантелями молотковым хватом',
      'Сгибания рук со штангой на скамье Скотта',
      'Сгибание одной руки с гантелью на скамье Скотта',
      'Сгибание рук на блоке',
      'Сгибание рук в тренажере на скамье Скотта',
      'Жим лёжа узким хватом',
      'Подтягивания обратным хватом',
      'Разгибание рук со штангой',
      'Разгибание рук с гантелями',
      'Разгибание рук с гантелями в наклоне',
      'Французский жим',
      'Разгибание рук на блоке',
      'Разгибание рук на блоке из-за головы',
      'Разгибание рук в тренажёре',
      'Алмазные отжимания',
      'Брусья на трицепс',
      'Обратные отжимания',
      'Боковые отжимания',
      'Сгибание кистей со штангой',
      'Сгибание кистей со штангой за спиной',
      'Сгибание кистей с гантелями сидя',
      'Скручивания предплечий',
      'Пальцы',
      'Подъем ларратта',
      'Вис на турнике',
    ]
  ),
  (
    'legs',
    [
      'Становая тяга',
      'Приседания со штангой',
      'Приседания с гантелями',
      'Приседания со штангой на скамью',
      'Приседания Зерчера',
      'Гакк-приседания со штангой',
      'Гакк-приседания в тренажере Смита',
      'Приседания со штангой на груди',
      'Приседания на одной ноге',
      'Выпады',
      'Выпады с гантелями',
      'Боковые выпады',
      'Болгарские выпады',
      'Разгибание ног в тренажере',
      'Сгибание ног в тренажере',
      'Сведение ног',
      'Разведение ног',
      'Стульчик у стены',
      'Прыжки на тумбу',
      'Боковые прыжки на тумбу',
      'Становая тяга с гантелями',
      'Румынская тяга',
      'Румынская тяга с гантелями',
      'Становая тяга в Смите',
      'Тяга в силовой раме',
      'Доброе утро',
      'Отведение ноги назад на блоке',
      'Ягодичный мостик',
      'Ягодичный мостик на одной ноге',
      'Приседания',
      'Подъем на носки',
      'Подъем на носки сидя',
      'Подъем на носок одной ноги',
      'Жим носками в тренажере',
    ]
  ),
  (
    'core',
    [
      'Скручивания',
      'Скручивания с блоком',
      'Скручивания на скамье с обратным наклоном',
      'Скручивания в тренажере',
      'Обратные скручивания',
      'Ситапы',
      'Ситапы на скамье с обратным наклоном',
      'Прокладка с колен на гимнастическом ролике',
      'Планка',
      'Боковая планка',
      'Обратная планка',
      'Мертвый жук',
      'Подъем ног в упоре',
      'Подъем ног в висе',
      'Подъемы ног лежа',
      'Подъем коленей в висе',
      'Подъем коленей в упоре',
      'Поочередные подъемы прямых ног',
      'Складной нож',
      'Русские скручивания',
      'Косые скручивания',
      'Косые скручивания на полу',
      'Наклоны в стороны с гантелями',
      'Наклоны в стороны у нижнего блока',
      'Наклоны вбок на блоке',
      'Повороты корпуса на блоке',
      'Дровосек с гантелью',
      'Дровосек на блоке',
      'Боковая гиперэкстензия',
    ]
  ),
  (
    'cardio',
    [
      'Беговая дорожка',
      'Эллипсоид',
      'Велосипед',
      'Степпер',
      'Лестница-степпер',
      'Скалолаз',
      'Скакалка',
      'Волны с канатами',
      'Бёрпи',
      'Приседания с выпрыгиванием',
      'Джампинг Джек',
      'Бег с высоким подниманием бедра',
    ]
  ),
  (
    'full_body',
    [
      'Рывок штанги',
      'Толчок штанги',
      'Подъем штанги на грудь',
      'Махи гирей',
      'Турецкий подъем с гирей',
      'Трастеры с гирями',
      'Трастеры со штангой',
      'Железный крест с гантелями',
      'Приседания с тягой нижнего блока',
      'Прогулка фермера',
      'Броски мяча об стену',
      'Броски мяча об пол',
      'выход силой на перекладине',
    ]
  ),
];

const _defaultPrimaryMuscles = <String, String>{
  'chest': 'mid_chest',
  'back': 'lats',
  'shoulders': 'side_delts',
  'arms': 'biceps',
  'legs': 'quads',
  'core': 'abs',
  'cardio': 'cardio',
  'full_body': 'whole_body',
};

const _timeRepsExercises = <String>{
  'Стульчик у стены',
  'Планка',
  'Боковая планка',
  'Обратная планка',
  'Лодочка',
  'Скакалка',
  'Волны с канатами',
  'Бёрпи',
  'Приседания с выпрыгиванием',
  'Джампинг Джек',
  'Бег с высоким подниманием бедра',
  'Вис на турнике',
};

List<Exercise> defaultExercises() => [
      for (final (group, names) in _defaultExerciseNames)
        for (final name in names)
          Exercise(
            nameRu: name,
            defaultStepKg: defaultStep(name),
            format: group == 'cardio' && !_timeRepsExercises.contains(name)
                ? RecordFormat.timeDistance
                : _timeRepsExercises.contains(name)
                    ? RecordFormat.timeReps
                    : name == 'Прогулка фермера'
                        ? RecordFormat.weightTime
                        : RecordFormat.weightReps,
            primaryMuscles: [_defaultPrimaryMuscles[group]!],
          ),
    ];

final exerciseNames = [for (final e in defaultExercises()) e.nameRu];

class CycleSet {
  double? w;
  double? pct;
  int reps;
  int rir;

  /// Минимальное число повторений в подходе AMRAP: в дневник переносится
  /// базовое число, которое пользователь может изменить.
  bool amrap;

  /// Для подхода, который пишется на 1 повторение, но считается как 2 до отказа.
  int? rirReps;
  int durationSec;
  double distanceM;

  CycleSet({
    this.w,
    this.pct,
    required this.reps,
    required this.rir,
    this.amrap = false,
    this.rirReps,
    this.durationSec = 0,
    this.distanceM = 0,
  });

  Map<String, dynamic> toJson() => {
        'w': w,
        'pct': pct,
        'reps': reps,
        'rir': rir,
        if (amrap) 'amrap': true,
        if (rirReps != null) 'rirReps': rirReps,
        'durationSec': durationSec,
        'distanceM': distanceM,
      };

  factory CycleSet.fromJson(Map<String, dynamic> j) => CycleSet(
        w: (j['w'] as num?)?.toDouble(),
        pct: (j['pct'] as num?)?.toDouble(),
        reps: j['reps'] as int? ?? 0,
        rir: j['rir'] as int? ?? 0,
        amrap: j['amrap'] as bool? ?? false,
        rirReps: j['rirReps'] as int?,
        durationSec: j['durationSec'] as int? ?? 0,
        distanceM: (j['distanceM'] as num? ?? 0).toDouble(),
      );
}

class CycleDay {
  List<CycleSet> sets;
  CycleDay(this.sets);
  Map<String, dynamic> toJson() => {
        'sets': [for (final s in sets) s.toJson()]
      };
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
  if (s.pct == null || c.step <= 0) return 0;
  final exact = c.tm * s.pct! / 100 + c.wOffset;
  return ((exact / c.step).round() * c.step * 100).roundToDouble() / 100;
}

String dayChipLabel(Cycle c, int i) =>
    c.days.length > 8 ? '${i + 1}' : 'д.${i + 1}';

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
        cycleId: j['cycleId'] is int
            ? stableId('cycle', j['cycleId'])
            : j['cycleId']?.toString(),
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
  TemplateItem({String? id, required this.exerciseId, this.sets = const []})
      : id = id ?? newId();
  Map<String, dynamic> toJson() => {
        'id': id,
        'exerciseId': exerciseId,
        'sets': [for (final s in sets) s.toJson()]
      };
  factory TemplateItem.fromJson(Map<String, dynamic> j) => TemplateItem(
        id: j['id']?.toString(),
        exerciseId: j['exerciseId'] as String,
        sets: [
          for (final s in j['sets'] as List? ?? const []) DiarySet.fromJson(s)
        ],
      );
}

class WorkoutTemplate {
  String id;
  String name;
  String description;
  List<TemplateItem> items;
  WorkoutTemplate(
      {String? id,
      required this.name,
      this.description = '',
      this.items = const []})
      : id = id ?? newId();
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
        items: [
          for (final i in j['items'] as List? ?? const [])
            TemplateItem.fromJson(i)
        ],
      );
}

const mainCycleExercises = <String>{
  'Жим лёжа',
  'Становая тяга',
  'Приседания со штангой',
  'Жим стоя',
};

/// Схема 5/3/1 с заданным запасом до отказа и AMRAP в последнем подходе
/// первых трёх дней. В дневник попадает базовое число повторений без «+».
List<CycleDay> tmpl531days() => [
      CycleDay([
        CycleSet(pct: 65, reps: 5, rir: 5),
        CycleSet(pct: 71, reps: 5, rir: 4),
        CycleSet(pct: 79, reps: 5, rir: 3, amrap: true),
      ]),
      CycleDay([
        CycleSet(pct: 72.5, reps: 3, rir: 4),
        CycleSet(pct: 80, reps: 3, rir: 3),
        CycleSet(pct: 87, reps: 3, rir: 2, amrap: true),
      ]),
      CycleDay([
        CycleSet(pct: 75, reps: 5, rir: 3),
        CycleSet(pct: 85, reps: 3, rir: 2),
        CycleSet(pct: 95, reps: 1, rir: 1, amrap: true),
      ]),
      CycleDay([
        CycleSet(pct: 50, reps: 5, rir: 6),
        CycleSet(pct: 50, reps: 5, rir: 6),
        CycleSet(pct: 50, reps: 5, rir: 6),
      ]),
    ];

/// Предыдущая схема 5/3/1 для обновления существующих нетронутых циклов.
List<CycleDay> previousTmpl531days() => [
      CycleDay([
        CycleSet(pct: 65, reps: 5, rir: 4),
        CycleSet(pct: 75, reps: 5, rir: 3),
        CycleSet(pct: 85, reps: 5, rir: 1),
      ]),
      CycleDay([
        CycleSet(pct: 70, reps: 3, rir: 4),
        CycleSet(pct: 80, reps: 3, rir: 3),
        CycleSet(pct: 90, reps: 3, rir: 1),
      ]),
      CycleDay([
        CycleSet(pct: 75, reps: 5, rir: 3),
        CycleSet(pct: 85, reps: 3, rir: 2),
        CycleSet(pct: 95, reps: 1, rir: 0, rirReps: 2),
      ]),
      CycleDay([
        CycleSet(pct: 50, reps: 5, rir: 6),
        CycleSet(pct: 50, reps: 5, rir: 6),
        CycleSet(pct: 50, reps: 5, rir: 6),
      ]),
    ];

/// Самая ранняя версия 5/3/1 — тоже нужна для аккуратной миграции.
List<CycleDay> legacyTmpl531days() => [
      CycleDay([
        CycleSet(pct: 55, reps: 5, rir: 2),
        CycleSet(pct: 65, reps: 5, rir: 1),
        CycleSet(pct: 75, reps: 5, rir: 0),
      ]),
      CycleDay([
        CycleSet(pct: 60, reps: 3, rir: 2),
        CycleSet(pct: 70, reps: 3, rir: 1),
        CycleSet(pct: 80, reps: 3, rir: 0),
      ]),
      CycleDay([
        CycleSet(pct: 65, reps: 5, rir: 1),
        CycleSet(pct: 75, reps: 3, rir: 1),
        CycleSet(pct: 85, reps: 1, rir: 0),
      ]),
      CycleDay([
        CycleSet(pct: 30, reps: 5, rir: 5),
        CycleSet(pct: 40, reps: 5, rir: 5),
        CycleSet(pct: 50, reps: 5, rir: 5),
      ]),
    ];

bool cycleDaysEqual(Cycle c, List<CycleDay> days) =>
    c.days.length == days.length &&
    [
          for (var i = 0; i < c.days.length; i++)
            for (var k = 0; k < c.days[i].sets.length; k++)
              (
                c.days[i].sets[k].pct,
                c.days[i].sets[k].reps,
                c.days[i].sets[k].rir,
                c.days[i].sets[k].amrap,
                c.days[i].sets[k].rirReps,
              )
        ].toString() ==
        [
          for (var i = 0; i < days.length; i++)
            for (var k = 0; k < days[i].sets.length; k++)
              (
                days[i].sets[k].pct,
                days[i].sets[k].reps,
                days[i].sets[k].rir,
                days[i].sets[k].amrap,
                days[i].sets[k].rirReps,
              )
        ].toString();

bool hasLegacyTmpl531Days(Cycle c) =>
    cycleDaysEqual(c, legacyTmpl531days()) ||
    cycleDaysEqual(c, previousTmpl531days());

/// Пятидневная волна для остальных упражнений: на два повторения больше,
/// чем в основном 5/3/1, при тех же RIR. Четвёртый день повторяет второй.
List<CycleDay> waveCycleDays() => [
      for (final day in [
        [(60.0, 7, 5, false), (66.0, 7, 4, false), (74.0, 7, 3, true)],
        [(67.5, 5, 4, false), (75.0, 5, 3, false), (82.0, 5, 2, true)],
        [(70.0, 7, 3, false), (80.0, 5, 2, false), (90.0, 3, 1, true)],
        [(67.5, 5, 4, false), (75.0, 5, 3, false), (82.0, 5, 2, true)],
        [(50.0, 7, 6, false), (50.0, 7, 6, false), (50.0, 7, 6, false)],
      ])
        CycleDay([
          for (final (pct, reps, rir, amrap) in day)
            CycleSet(pct: pct, reps: reps, rir: rir, amrap: amrap),
        ]),
    ];

/// Прежняя пятидневная волна с дополнительным днём по схеме третьего.
List<CycleDay> previousWaveCycleDays() => [
      for (final day in [
        [(60.0, 7, 5, false), (66.0, 7, 4, false), (74.0, 7, 3, true)],
        [(67.5, 5, 4, false), (75.0, 5, 3, false), (82.0, 5, 2, true)],
        [(70.0, 7, 3, false), (80.0, 5, 2, false), (90.0, 3, 1, true)],
        [(65.0, 7, 3, false), (75.0, 5, 2, false), (85.0, 3, 1, true)],
        [(50.0, 7, 6, false), (50.0, 7, 6, false), (50.0, 7, 6, false)],
      ])
        CycleDay([
          for (final (pct, reps, rir, amrap) in day)
            CycleSet(pct: pct, reps: reps, rir: rir, amrap: amrap),
        ]),
    ];

/// Прежняя шестидневная волна для миграции только нетронутых циклов.
List<CycleDay> legacyWaveCycleDays() => [
      for (final day in [
        [(55, 3), (65, 2), (75, 1)],
        [(60, 3), (70, 2), (80, 0)],
        [(65, 2), (75, 1), (85, 0)],
        [(55, 3), (65, 2), (70, 1)],
        [(60, 2), (70, 1), (80, 0)],
        [(65, 2), (75, 1), (85, 0)],
      ])
        CycleDay([
          for (final (pct, rir) in day)
            CycleSet(pct: pct.toDouble(), reps: 5, rir: rir),
        ]),
    ];

bool hasLegacyWaveCycleDays(Cycle c) =>
    cycleDaysEqual(c, legacyWaveCycleDays()) ||
    cycleDaysEqual(c, previousWaveCycleDays());

List<CycleDay> defaultCycleDays(String exerciseName) =>
    mainCycleExercises.contains(exerciseName) ? tmpl531days() : waveCycleDays();

String rirLabel(int code) => switch (code) {
      -1 => '',
      0 => 'отказ',
      5 => 'RIR 5+',
      6 => '10+',
      _ => 'RIR $code',
    };

double epley(double w, int r) => w * (1 + r / 30);
double roundDownToStep(double v, double step) =>
    step <= 0 ? 0 : (v / step).floor() * step;
double calcTM(double w, int r) => (w * (1 + r / 30)).roundToDouble();

/// Обратный расчёт Эпли: сколько повторений останется после выполненных.
/// Целое число повторений включает текущее; поэтому 100×5 при ТМ 130 даёт RIR 5+.
int calculateRir({
  required double trainingMax,
  required double weight,
  required int reps,
  int fallback = 0,
}) {
  if (trainingMax <= 0 || weight <= 0 || reps <= 0) return fallback;
  // Малая погрешность double не должна превращать ровно 10 повторений в 9.
  final estimatedMaxReps = (30 * (trainingMax / weight - 1) + 1e-9).floor() + 1;
  return (estimatedMaxReps - reps).clamp(0, 6);
}

int cycleSetRir(Cycle c, CycleSet s) {
  // Процентный шаблон несёт авторский целевой RIR. Вес, введённый вручную,
  // и нестандартные изменения пересчитываются универсальным калькулятором.
  if (s.pct != null && s.w == null) return s.rir.clamp(0, 6);
  return calculateRir(
    trainingMax: c.tm,
    weight: setWeight(c, s),
    reps: s.rirReps ?? s.reps,
    fallback: s.rir,
  );
}

/// Гантели — 2 кг, тяжёлые базовые движения — 5 кг, остальные — 2,5 кг.
double defaultStep(String name) {
  final n = name.toLowerCase();
  if (n.contains('гантел') || n.contains('гир')) return 2;
  const heavy = [
    'становая тяга',
    'приседания со штангой',
    'приседания зерчера',
    'гакк-приседания со штангой',
    'тяга в силовой раме',
  ];
  if (heavy.any(n.contains) || n == 'приседания' || n == 'ягодичный мостик') {
    return 5;
  }
  return 2.5;
}
