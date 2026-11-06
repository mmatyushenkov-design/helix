import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker_frontend/main.dart';
import 'package:workout_tracker_frontend/models/models.dart';
import 'package:workout_tracker_frontend/state/app_state.dart';
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

  testWidgets('Каталог создаёт упражнение с форматом время + дистанция',
      (tester) async {
    await tester.pumpWidget(const WorkoutTrackerApp());
    await tester.tap(find.text('Настройки'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Управление упражнениями'));
    await tester.pumpAndSettle();
    expect(find.text('Поиск упражнения'), findsOneWidget);

    await tester.tap(find.text('+ Упражнение'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Велосипед');
    await tester.enterText(find.byType(TextField).at(1), 'Cycling');
    await tester.tap(find.byType(DropdownButton<RecordFormat>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Время + дистанция').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    final exercise = appState.exerciseByName('Велосипед');
    expect(exercise, isNotNull);
    expect(exercise!.nameEn, 'Cycling');
    expect(exercise.format, RecordFormat.timeDistance);
    expect(exercise.isCustom, isTrue);
    expect(find.text('Поиск упражнения'), findsOneWidget);
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
                  )),
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
}
