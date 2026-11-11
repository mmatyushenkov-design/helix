import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:workout_tracker_frontend/main.dart';
import 'package:workout_tracker_frontend/models/models.dart';
import 'package:workout_tracker_frontend/screens/diary_screen.dart';
import 'package:workout_tracker_frontend/screens/stats_screen.dart';
import 'package:workout_tracker_frontend/state/app_state.dart';
import 'package:workout_tracker_frontend/widgets/set_box.dart';
import 'package:workout_tracker_frontend/widgets/set_sheet.dart';

void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'workout_tracker_frontend',
      packageName: 'com.example.workout_tracker_frontend',
      version: '1.1.0',
      buildNumber: '6',
      buildSignature: '',
    );
    appState
      ..seed()
      ..language = 'ru'
      ..weightUnit = WeightUnit.kg
      ..distanceUnit = DistanceUnit.km
      ..tabIndex = 0;
  });

  testWidgets('Пять разделов: навигация, заглушка программы и статистика',
      (tester) async {
    await tester.pumpWidget(const WorkoutTrackerApp());
    expect(find.text('Приседания'), findsOneWidget);
    for (final label in [
      'Циклы',
      'Программа',
      'Дневник',
      'Статистика',
      'Настройки'
    ]) {
      expect(find.text(label), findsWidgets);
    }
    await tester.tap(find.text('Программа'));
    await tester.pumpAndSettle();
    expect(appState.tabIndex, 1);
    expect(find.text('Раздел программы пока пуст'), findsOneWidget);
    await tester.tap(find.text('Статистика'));
    await tester.pumpAndSettle();
    expect(appState.tabIndex, 3);
    expect(find.text('Жим лёжа'), findsWidgets);
    await tester.tap(find.text('Дневник'));
    await tester.pumpAndSettle();
    expect(appState.tabIndex, 2);
    expect(find.text('+ Добавить упражнение'), findsOneWidget);
  });

  testWidgets('Настройки переключают язык и единицы измерения', (tester) async {
    await tester.pumpWidget(const WorkoutTrackerApp());
    await tester.tap(find.text('Настройки'));
    await tester.pumpAndSettle();
    expect(find.text('Управление упражнениями'), findsNothing);
    expect(find.text('release-1.1.0'), findsOneWidget);

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();
    expect(appState.language, 'en');
    expect(find.text('Settings'), findsWidgets);

    await tester.tap(find.byType(DropdownButton<WeightUnit>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('lb').last);
    await tester.pumpAndSettle();
    expect(appState.weightUnit, WeightUnit.lb);

    // Мили отключены: в списке единиц дистанции только километры.
    await tester.tap(find.byType(DropdownButton<DistanceUnit>));
    await tester.pumpAndSettle();
    expect(find.text('ml'), findsNothing);
    expect(find.text('mi'), findsNothing);
    await tester.tap(find.text('km').last);
    await tester.pumpAndSettle();
    expect(appState.distanceUnit, DistanceUnit.km);
  });

  testWidgets('Выбор упражнения: группы, поиск и создание через плюс',
      (tester) async {
    await tester.pumpWidget(const WorkoutTrackerApp());
    await tester.tap(find.text('Дневник'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+ Добавить упражнение'));
    await tester.pumpAndSettle();

    final search =
        tester.widget<TextField>(find.byKey(const Key('exercise-search')));
    expect(search.autofocus, isFalse);
    expect(find.byKey(const Key('muscle-group-chest')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('exercise-search')), 'Бицепс');
    await tester.pumpAndSettle();
    expect(find.text('Бицепс со штангой'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('exercise-search')), '');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('muscle-group-chest')));
    await tester.pumpAndSettle();
    expect(find.text('Жим лёжа'), findsWidgets);
    expect(find.text('Приседания'), findsNothing);

    await tester.enterText(
        find.byKey(const Key('exercise-search')), 'Приседания');
    await tester.pumpAndSettle();
    expect(find.text('Упражнения не найдены'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('exercise-search')), '');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('create-exercise')));
    await tester.pumpAndSettle();
    expect(find.text('Новое упражнение'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('exercise-name')), 'Велосипед');
    await tester.tap(find.byKey(const Key('exercise-favorite')));
    await tester.tap(find.byType(DropdownButton<RecordFormat>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Время + дистанция').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    final exercise = appState.exerciseByName('Велосипед');
    expect(exercise, isNotNull);
    expect(exercise!.nameEn, 'Велосипед');
    expect(exercise.format, RecordFormat.timeDistance);
    expect(exercise.isCustom, isTrue);
    expect(exercise.favorite, isTrue);
    expect(find.byKey(const Key('exercise-search')), findsOneWidget);
  });

  testWidgets('Неделя перемещается в месяц без дублирования даты',
      (tester) async {
    await tester.pumpWidget(const WorkoutTrackerApp());
    await tester.tap(find.text('Дневник'));
    await tester.pumpAndSettle();
    final today = DateTime.now().day.toString();
    final date = find.descendant(
        of: find.byKey(const Key('calendar')), matching: find.text(today));
    expect(date, findsOneWidget);
    final collapsedY = tester.getTopLeft(date).dy;

    await tester.tap(find.byKey(const Key('calendar-handle')));
    await tester.pumpAndSettle();
    expect(date, findsOneWidget);
    expect(tester.getTopLeft(date).dy, greaterThan(collapsedY));
    expect(find.text('Ноябрь ${DateTime.now().year}'), findsOneWidget);
  });

  testWidgets('Шесть подходов: RIR 5+ и отказ остаются однострочными',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 360,
            child: SetFlow(sets: [
              for (var i = 0; i < 6; i++) SetBoxData(w: 100, reps: 10, rir: i),
            ]),
          ),
        ),
      ),
    ));
    expect(find.text('отказ'), findsOneWidget);
    expect(find.text('RIR 2'), findsOneWidget);
    expect(find.text('RIR 5+'), findsOneWidget);
    final labels = tester
        .widgetList<Text>(find.descendant(
          of: find.byType(SetFlow),
          matching: find.byType(Text),
        ))
        .where((text) =>
            text.data == 'отказ' || text.data?.startsWith('RIR') == true);
    expect(labels, hasLength(6));
    for (final label in labels) {
      expect(label.maxLines, 1);
      expect(label.softWrap, isFalse);
    }
    expect(
        find.descendant(
            of: find.byType(SetFlow), matching: find.byType(FittedBox)),
        findsNWidgets(12));
  });

  testWidgets('Редактор подхода сохраняет все четыре формата', (tester) async {
    for (final format in RecordFormat.values) {
      SetSheetResult? result;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () async {
                  result = await showSetSheet(context,
                      mode: SetSheetMode.newSet, format: format);
                },
                child: const Text('Открыть'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Открыть'));
      await tester.pumpAndSettle();
      expect(find.text('Новый подход'), findsOneWidget);
      await tester.tap(find.text('Сохранить подход'));
      await tester.pumpAndSettle();

      final set = result!.set!;
      expect(set.w, format.usesWeight ? 0.0 : isNull);
      expect(set.reps, format.usesReps ? 4 : 0);
      expect(set.durationSec, format.usesTime ? 60 : 0);
      expect(set.distanceM, format.usesDistance ? 5000.0 : 0);
    }
  });

  testWidgets('Клавиши сначала сворачиваются, затем сохраняется подход',
      (tester) async {
    SetSheetResult? result;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await showSetSheet(context, mode: SetSheetMode.newSet);
            },
            child: const Text('Открыть'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('0 кг', findRichText: true));
    await tester.pumpAndSettle();
    expect(find.text('Сохранить'), findsOneWidget);
    expect(find.text('Сохранить подход'), findsNothing);

    await tester.tap(find.text('7'));
    await tester.pump();
    await tester.ensureVisible(find.text('Сохранить'));
    await tester.pump();
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(find.text('Новый подход'), findsOneWidget);
    expect(find.textContaining('7 кг', findRichText: true), findsOneWidget);
    expect(find.text('Сохранить подход'), findsOneWidget);

    await tester.tap(find.text('Сохранить подход'));
    await tester.pumpAndSettle();
    expect(result?.set?.w, 7);
  });

  testWidgets('Упражнение перетаскивается долгим нажатием', (tester) async {
    await tester.pumpWidget(const WorkoutTrackerApp());
    await tester.tap(find.text('Дневник'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+ Добавить упражнение'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('muscle-group-chest')));
    await tester.pumpAndSettle();

    final exercise = appState.exerciseByName('Жим лёжа')!;
    final oldIndex = appState.exercises.indexOf(exercise);
    final gesture =
        await tester.startGesture(tester.getCenter(find.text('Жим лёжа').last));
    await tester.pump(const Duration(milliseconds: 700));
    await gesture.moveBy(const Offset(0, 180));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(appState.exercises.indexOf(exercise), isNot(oldIndex));
  });

  testWidgets('Поиск статистики фильтрует упражнения', (tester) async {
    await tester.pumpWidget(const WorkoutTrackerApp());
    await tester.tap(find.text('Статистика'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('stats-search')), 'Жим');
    await tester.pumpAndSettle();
    expect(find.text('Жим лёжа'), findsOneWidget);
    expect(find.text('Приседания'), findsNothing);
  });

  testWidgets('Другой день цикла начинается только после подтверждения',
      (tester) async {
    await tester.pumpWidget(const WorkoutTrackerApp());
    final cycle = appState.cycles.first;
    final oldDay = cycle.curDay;
    final nextDay = oldDay + 1;
    final oldTm = cycle.tm;
    final chip = find.text(dayChipLabel(cycle, nextDay)).first;
    // Выбор чипа — только просмотр, диалога нет, день цикла не меняется.
    await tester.tap(chip);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Вы уверены, что хотите начать день ${nextDay + 1}?'),
        findsNothing);
    expect(cycle.curDay, oldDay);
    // «Начать» при выбранном другом дне — предупреждение.
    await tester.tap(find.text('Начать').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Вы уверены, что хотите начать день ${nextDay + 1}?'),
        findsOneWidget);
    await tester.tap(find.byKey(const Key('future-day-no')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(cycle.curDay, oldDay);
    await tester.tap(find.text('Начать').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('future-day-yes')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(cycle.curDay, nextDay);
    expect(cycle.tm, oldTm);
  });

  testWidgets('Калькулятор учитывает запас по числу повторений',
      (tester) async {
    final cycle = appState.cycles.first..step = 2.5;
    SetSheetResult? result;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await showSetSheet(context,
                  mode: SetSheetMode.tmCalc, cycle: cycle);
            },
            child: const Text('Открыть'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Применить'));
    await tester.pump();
    await tester.tap(find.text('Применить'));
    await tester.pumpAndSettle();
    final reps = cycle.bestR.clamp(0, 25);
    final expected = roundDownToStep(
        epley(cycle.bestW, reps) * (1 - reps / 100), cycle.step);
    expect(result!.tm, expected);
  });

  testWidgets('Редактор цикла помещается на экране телефона', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const WorkoutTrackerApp());
    await tester.tap(find.text('Изменить').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Расчётный разовый максимум'), findsOneWidget);
    expect(find.byIcon(Icons.help_outline), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Карточки статистики не переполняются на экране телефона',
      (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final exercise = appState.exerciseByName('Приседания')!;
    await tester.pumpWidget(MaterialApp(
      home: StatsDetailScreen(exerciseId: exercise.id, name: exercise.nameRu),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('за всё время'), findsWidgets);
  });

  testWidgets('Анимация конца цикла: дробный вес, огонёк и единицы',
      (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 260,
            child: CelebrateAnim(oldTm: 120, step: 2.5, onReady: () {}),
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    // 120 → 122,5 кг: все символы на месте, включая запятую и дробную часть.
    expect(find.text(','), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text(' кг'), findsOneWidget);
    expect(find.text('🔥 '), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Анимация заранее дополняет целый вес дробным нулём',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body:
            Center(child: CelebrateAnim(oldTm: 125, step: 2.5, onReady: () {})),
      ),
    ));
    await tester.pump();
    // 125 → 127,5: старое значение сразу занимает те же разряды — 125,0.
    expect(find.text('0'), findsOneWidget);
    expect(find.text(','), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('5'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Свайп недели не меняет выбранный день', (tester) async {
    await tester.pumpWidget(const WorkoutTrackerApp());
    await tester.tap(find.text('Дневник'));
    await tester.pumpAndSettle();
    final title = find.text('Тренировка — сегодня');
    expect(title, findsOneWidget);
    await tester.drag(find.byKey(const Key('calendar')), const Offset(-320, 0));
    await tester.pumpAndSettle();
    expect(title, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
