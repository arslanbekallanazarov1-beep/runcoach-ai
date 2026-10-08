import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runcoach_ai/screens/workout_history_screen.dart';
import 'package:runcoach_ai/services/workout_history_service.dart';

class _ToggleFailingStorage extends MemoryWorkoutStorage {
  bool failWrites = false;

  @override
  Future<void> write(String value) async {
    if (failWrites) throw Exception('Storage is unavailable.');
    await super.write(value);
  }
}

Widget _historyApp(WorkoutHistoryService service) {
  return MaterialApp(
    supportedLocales: const [Locale('en'), Locale('ru')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: WorkoutHistoryScreen(
      languageCode: 'en',
      onLocaleChanged: (_) {},
      onThemeModeChanged: (_) {},
      service: service,
    ),
  );
}

void main() {
  testWidgets('confirms and persists deletion of an individual run', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final storage = MemoryWorkoutStorage();
    final service = WorkoutHistoryService(storage: storage);
    await service.load();
    await service.addWorkout(distanceKm: 5, timeSeconds: 1800);

    await tester.pumpWidget(_historyApp(service));
    await tester.pumpAndSettle();
    expect(service.workouts, hasLength(1));

    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this workout?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(service.workouts, hasLength(1));

    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(service.workouts, isEmpty);
    expect(storage.value, '[]');
    expect(
        find.text('Your analyzed workouts will show up here.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    service.dispose();
  });

  testWidgets('shows an error and retains the run when deletion fails', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final storage = _ToggleFailingStorage();
    final service = WorkoutHistoryService(storage: storage);
    await service.load();
    await service.addWorkout(distanceKm: 5, timeSeconds: 1800);
    storage.failWrites = true;

    await tester.pumpWidget(_historyApp(service));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(service.workouts, hasLength(1));
    expect(find.text('Could not delete the run. Please try again.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    service.dispose();
  });
}
