import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:runcoach_ai/main.dart';
import 'package:runcoach_ai/models/auth_user.dart';
import 'package:runcoach_ai/screens/analyze_run_screen.dart';
import 'package:runcoach_ai/screens/gear_tracker_screen.dart';
import 'package:runcoach_ai/screens/profile_screen.dart';
import 'package:runcoach_ai/screens/training_plan_screen.dart';
import 'package:runcoach_ai/screens/weather_screen.dart';
import 'package:runcoach_ai/screens/workout_history_screen.dart';
import 'package:runcoach_ai/services/gear_tracker_service.dart';
import 'package:runcoach_ai/services/run_analysis_service.dart';
import 'package:runcoach_ai/services/workout_history_service.dart';

void main() {
  testWidgets('each navigation tab displays its matching screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      RunCoachApp(
        service: RunAnalysisService(
          client: MockClient((_) async => http.Response('{"runs":[]}', 200)),
        ),
        initialUser: const AuthUser(
          id: 'navigation-test-user',
          email: 'runner@example.com',
          firstName: 'Test',
          lastName: 'Runner',
        ),
        gearTracker: GearTrackerService(storage: MemoryGearStorage()),
        workoutHistory: WorkoutHistoryService(
          storage: MemoryWorkoutStorage(),
        ),
      ),
    );

    final expectedScreens = <String, Type>{
      'tab-training': AnalyzeRunScreen,
      'tab-plan': TrainingPlanScreen,
      'tab-shoes': GearTrackerScreen,
      'tab-weather': WeatherScreen,
      'tab-history': WorkoutHistoryScreen,
      'tab-profile': ProfileScreen,
    };
    for (final entry in expectedScreens.entries) {
      await tester.tap(find.byKey(ValueKey(entry.key)));
      await tester.pump();

      final stack =
          tester.widget<IndexedStack>(find.byType(IndexedStack).first);
      expect(stack.children[stack.index ?? 0].runtimeType, entry.value);
    }

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
