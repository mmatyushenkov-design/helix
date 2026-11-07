import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker_frontend/main.dart';
import 'package:workout_tracker_frontend/models/models.dart';
import 'package:workout_tracker_frontend/screens/stats_screen.dart';
import 'package:workout_tracker_frontend/state/app_state.dart';
import 'package:workout_tracker_frontend/widgets/set_box.dart';
import 'package:workout_tracker_frontend/widgets/set_sheet.dart';

void main() {
  setUp(() {
    appState
      ..seed()
      ..language = 'ru'
      ..weightUnit = WeightUnit.kg
      ..distanceUnit = DistanceUnit.km
      ..tabIndex = 0;
  });

  testWidgets('Пять разделов: навигация, заглушка шаблонов и статистика',
      (tester) async {
    await tester.pumpWidget(const WorkoutTrackerApp());
    expect(find.text('Приседания'), findsOneWidget);
    for (final label in [
      'Циклы',
      'Шаблоны',
      'Дневник',
      'Статистика',
      'Настройки'
    ]) {
      expect(find.text(label), findsWidgets);
    }
    await tester.tap(find.text('Шаблоны'));
    await tester.pumpAndSettle();
    expect(appState.tabIndex, 1);
    expect(find.text('Раздел шаблонов пока пуст'), findsOneWidget);
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

    await tester.tap(find.byType(DropdownButton<DistanceUnit>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('mi').last);
    await tester.pumpAndSettle();
    expect(appState.distanceUnit, DistanceUnit.mi);
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

  testWidgets('Пять подходов: RIR и отказ остаются однострочными',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 360,
            child: SetFlow(sets: [
              for (var i = 0; i < 5; i++) SetBoxData(w: 100, reps: 10, rir: i),
            ]),
          ),
        ),
      ),
    ));
    expect(find.text('отказ'), findsOneWidget);
    expect(find.text('RIR 2'), findsOneWidget);
    final labels = tester
        .widgetList<Text>(find.descendant(
          of: find.byType(SetFlow),
          matching: find.byType(Text),
        ))
        .where((text) =>
            text.data == 'отказ' || text.data?.startsWith('RIR') == true);
    expect(labels, hasLength(5));
    for (final label in labels) {
      expect(label.maxLines, 1);
      expect(label.softWrap, isFalse);
    }
    expect(
        find.descendant(
            of: find.byType(SetFlow), matching: find.byType(FittedBox)),
        findsNWidgets(10));
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
      expect(set.w, format.usesWeight ? 120.0 : isNull);
      expect(set.reps, format.usesReps ? 4 : 0);
      expect(set.durationSec, format.usesTime ? 60 : 0);
      expect(set.distanceM, format.usesDistance ? 5000.0 : 0);
    }
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
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(appState.exercises.indexOf(exercise), isNot(oldIndex));
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
}
