import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker_frontend/models/models.dart';
import 'package:workout_tracker_frontend/screens/cycles_screen.dart';
import 'package:workout_tracker_frontend/state/app_state.dart';
import 'package:workout_tracker_frontend/widgets/set_box.dart';
import 'package:workout_tracker_frontend/widgets/set_sheet.dart';

void main() {
  test('5/3/1: точные веса, RIR и AMRAP для ТМ 130 кг', () {
    final state = AppState()..initializeDefaults();
    expect(state.exerciseByName('Жим лёжа')!.defaultStepKg, 2.5);
    final bench = state.addCycle('Жим лёжа');
    expect(bench.step, 2.5);
    expect(bench.tm, 0);
    expect(bench.bestW, 0);
    expect(bench.bestR, 0);
    expect(bench.days, hasLength(4));
    expect(bench.days[0].sets.map((s) => (s.pct, s.reps, s.amrap)),
        [(65.0, 5, false), (71.0, 5, false), (79.0, 5, true)]);
    expect(bench.days[1].sets.map((s) => (s.pct, s.reps, s.amrap)),
        [(72.5, 3, false), (80.0, 3, false), (87.0, 3, true)]);
    expect(bench.days[2].sets.map((s) => (s.pct, s.reps, s.amrap)),
        [(75.0, 5, false), (85.0, 3, false), (95.0, 1, true)]);
    expect(bench.days[3].sets.map((s) => (s.pct, s.reps, s.amrap)),
        [(50.0, 5, false), (50.0, 5, false), (50.0, 5, false)]);

    bench.tm = 130;
    final expectedWeights = [
      [85.0, 92.5, 102.5],
      [95.0, 105.0, 112.5],
      [97.5, 110.0, 122.5],
      [65.0, 65.0, 65.0],
    ];
    final expectedRir = [
      [5, 4, 3],
      [4, 3, 2],
      [3, 2, 1],
      [6, 6, 6],
    ];
    for (var i = 0; i < bench.days.length; i++) {
      expect(bench.days[i].sets.map((s) => setWeight(bench, s)),
          expectedWeights[i]);
      expect(
          bench.days[i].sets.map((s) => cycleSetRir(bench, s)), expectedRir[i]);
    }

    bench.curDay = 2;
    state.startCycleDay(bench);
    final entry = state.entriesOf(DateTime.now()).single;
    expect(entry.sets.map((s) => s.w), [97.5, 110.0, 122.5]);
    expect(entry.sets.map((s) => s.reps), [5, 3, 1]);
    expect(entry.sets.map((s) => s.rir), [3, 2, 1]);
    expect(entry.sets.every((s) => s.planned), isTrue);

    final restored = CycleSet.fromJson(bench.days[1].sets.first.toJson());
    expect(restored.pct, 72.5);
    expect(restored.amrap, isFalse);
    final restoredAmrap = CycleSet.fromJson(bench.days[2].sets.last.toJson());
    expect(restoredAmrap.amrap, isTrue);
  });

  test('Волна: пять дней, на два повторения больше и прежние RIR', () {
    final state = AppState()..initializeDefaults();
    final accessory = state.addCycle('Французский жим');
    expect(accessory.days, hasLength(5));
    final expected = [
      [(60.0, 7, 5, false), (66.0, 7, 4, false), (74.0, 7, 3, true)],
      [(67.5, 5, 4, false), (75.0, 5, 3, false), (82.0, 5, 2, true)],
      [(70.0, 7, 3, false), (80.0, 5, 2, false), (90.0, 3, 1, true)],
      [(67.5, 5, 4, false), (75.0, 5, 3, false), (82.0, 5, 2, true)],
      [(50.0, 7, 6, false), (50.0, 7, 6, false), (50.0, 7, 6, false)],
    ];
    for (var i = 0; i < accessory.days.length; i++) {
      expect(accessory.days[i].sets.map((s) => (s.pct, s.reps, s.rir, s.amrap)),
          expected[i]);
    }
  });

  test('Новый подход: прежняя тренировка, затем предыдущий подход дня', () {
    final state = AppState()..initializeDefaults();
    final exercise = state.exerciseByName('Жим лёжа')!;
    final oldDate = DateTime(2026, 1, 10);
    final currentDate = DateTime(2026, 1, 20);
    state.addEntry(oldDate, exercise.nameRu,
        exerciseId: exercise.id,
        presetSets: [
          DiarySet(w: 80, reps: 8, rir: 3),
          DiarySet(w: 90, reps: 5, rir: 2),
        ]);
    final current = state.addEntry(currentDate, exercise.nameRu,
        exerciseId: exercise.id,
        presetSets: [
          DiarySet(w: 80, reps: 8, rir: 3),
          DiarySet(w: 85, reps: 7, rir: 2)
        ]);
    expect(state.suggestedSet(current, 1, currentDate)?.w, 90);
    expect(state.suggestedSet(current, 1, currentDate)?.reps, 5);
    expect(state.suggestedSet(current, 2, currentDate)?.w, 85);
    expect(state.suggestedSet(current, 2, currentDate)?.reps, 7);
  });

  test('Сохранённый подход цикла обновляется без пересчёта максимума', () {
    final state = AppState()..initializeDefaults();
    final cycle = state.addCycle('Жим лёжа')..tm = 130;
    final entry = state.addEntry(DateTime(2026, 1, 20), 'Жим лёжа',
        exerciseId: cycle.exerciseId);

    state.recordSavedSet(entry, DiarySet(w: 97.5, reps: 4, rir: 2));

    expect(cycle.bestW, 97.5);
    expect(cycle.bestR, 4);
    expect(cycle.tm, 130);
    expect(cycle.days[2].sets.map((s) => setWeight(cycle, s)),
        [97.5, 110.0, 122.5]);
  });

  test('RIR рассчитывается из веса, повторений и расчётного максимума', () {
    expect(calculateRir(trainingMax: 130, weight: 100, reps: 5), 5);
    expect(calculateRir(trainingMax: 130, weight: 130, reps: 1), 0);
    final state = AppState()..initializeDefaults();
    final cycle = state.addCycle('Жим лёжа');
    cycle.tm = 130;
    final set = CycleSet(w: 100, reps: 5, rir: 0);
    expect(cycleSetRir(cycle, set), 5);
  });

  test('Старые названия мигрируют без дубликатов и потери связей', () {
    final old = Exercise(nameRu: 'Жим штанги лежа');
    final cycle = Cycle(
        exerciseId: old.id,
        name: old.nameRu,
        bestW: 100,
        bestR: 5,
        tm: 120,
        step: 2.5,
        days: legacyTmpl531days());
    final state = AppState();
    state.loadJson({
      'schemaVersion': 2,
      'exercises': [old.toJson()],
      'cycles': [cycle.toJson()],
      'templates': const [],
      'log': const {},
    });
    expect(state.exerciseByName('Жим штанги лежа'), isNull);
    expect(state.exerciseByName('Жим лёжа'), isNotNull);
    expect(
        state.cycles.single.exerciseId, state.exerciseByName('Жим лёжа')!.id);
    expect(state.cycles.single.name, 'Жим лёжа');
    expect(state.cycles.single.days[1].sets.map((s) => (s.pct, s.reps)),
        [(72.5, 3), (80.0, 3), (87.0, 3)]);
    expect(state.cycles.single.days[2].sets.last.amrap, isTrue);
  });

  test('Мигрируются только целиком сохранённые старые шаблоны', () {
    Cycle cycle(String name, List<CycleDay> days) =>
        Cycle(name: name, bestW: 0, bestR: 0, tm: 130, step: 2.5, days: days);
    final customDays = legacyWaveCycleDays();
    customDays.first.sets.first.reps = 6;
    final state = AppState();
    state.loadJson({
      'schemaVersion': 2,
      'exercises': const [],
      'cycles': [
        cycle('Жим лёжа', previousTmpl531days()).toJson(),
        cycle('Французский жим', legacyWaveCycleDays()).toJson(),
        cycle('Тяга блока к поясу сидя', previousWaveCycleDays()).toJson(),
        cycle('Тяга верхнего блока', customDays).toJson(),
      ],
      'templates': const [],
      'log': const {},
    });

    final main = state.cycleById(state.cycles[0].id)!;
    expect(main.days[0].sets.map((s) => (s.pct, s.reps, s.rir, s.amrap)),
        [(65.0, 5, 5, false), (71.0, 5, 4, false), (79.0, 5, 3, true)]);
    expect(state.cycles[1].days, hasLength(5));
    expect(state.cycles[1].days[2].sets.map((s) => s.reps), [7, 5, 3]);
    expect(state.cycles[2].days[3].sets.map((s) => (s.pct, s.reps, s.rir)),
        [(67.5, 5, 4), (75.0, 5, 3), (82.0, 5, 2)]);
    expect(state.cycles[3].days, hasLength(6));
    expect(state.cycles[3].days.first.sets.first.reps, 6);
  });

  testWidgets('Калькулятор: нули и замена значения первой цифрой',
      (tester) async {
    final state = AppState()..initializeDefaults();
    final cycle = state.addCycle('Жим лёжа');
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) {
          return FilledButton(
            onPressed: () =>
                showSetSheet(context, mode: SetSheetMode.tmCalc, cycle: cycle),
            child: const Text('Открыть'),
          );
        }),
      ),
    ));
    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();
    expect(find.text('Введите свой лучший подход'), findsOneWidget);
    await tester.tap(find.text('7'));
    await tester.pump();
    expect(find.textContaining('7 кг', findRichText: true), findsOneWidget);
    await tester.tap(find.text('2'));
    await tester.pump();
    expect(find.textContaining('72 кг', findRichText: true), findsOneWidget);
  });

  testWidgets('Плашка повторений без плюса, процент — без лишних нулей',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: SetFlow(sets: [
            SetBoxData(w: 122.5, reps: 1, rir: 1, pct: 95, amrap: true),
          ]),
        ),
      ),
    ));
    expect(find.text('122,5×1'), findsOneWidget);
    expect(find.text('122,5×1+'), findsNothing);
    expect(find.text('95%'), findsOneWidget);
    expect(find.text('RIR 1'), findsOneWidget);
  });

  testWidgets('Пустой экран циклов содержит новые рекомендации',
      (tester) async {
    appState.initializeDefaults();
    addTearDown(appState.initializeDefaults);
    await tester.pumpWidget(const MaterialApp(home: CyclesScreen()));
    expect(find.textContaining('ВНИМАНИЕ!'), findsOneWidget);
    expect(find.textContaining('в хорошей технике'), findsOneWidget);
    expect(find.textContaining('два раза в неделю'), findsOneWidget);
    expect(find.textContaining('поддерживающая, с маленькими весами'),
        findsOneWidget);
    expect(find.textContaining('именно на такой режим тренировок'),
        findsOneWidget);
  });

  testWidgets('В полном списке цикла соблюдается заданный приоритет',
      (tester) async {
    tester.view.physicalSize = const Size(500, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    appState.initializeDefaults();
    addTearDown(appState.initializeDefaults);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) {
          return FilledButton(
            onPressed: () => showExercisePicker(context),
            child: const Text('Открыть список'),
          );
        }),
      ),
    ));
    await tester.tap(find.text('Открыть список'));
    await tester.pumpAndSettle();
    expect(find.text('Тяга верхнего блока'), findsNothing);
    await tester.tap(find.text('Все упражнения'));
    await tester.pumpAndSettle();

    const names = [
      'Жим лёжа',
      'Становая тяга',
      'Приседания со штангой',
      'Жим стоя',
      'Тяга верхнего блока',
      'Тяга блока к поясу сидя',
      'Подтягивания',
      'Сгибание рук со штангой',
      'Разгибание рук на блоке',
      'Шраги в тренажере Смита',
    ];
    final positions = <double>[];
    for (final name in names) {
      expect(find.text(name), findsOneWidget);
      positions.add(tester.getTopLeft(find.text(name)).dy);
    }
    final sorted = [...positions]..sort();
    expect(positions, orderedEquals(sorted));
  });
}
