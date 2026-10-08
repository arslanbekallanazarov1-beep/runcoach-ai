import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:runcoach_ai/models/auth_user.dart';
import 'package:runcoach_ai/main.dart';
import 'package:runcoach_ai/services/gear_tracker_service.dart';
import 'package:runcoach_ai/services/coach_speech_service.dart';
import 'package:runcoach_ai/services/run_analysis_service.dart';
import 'package:runcoach_ai/services/workout_history_service.dart';

class _MockSpeechService implements CoachSpeechService {
  @override
  Future<void> speak({
    required String text,
    required String languageCode,
  }) async {}

  @override
  Future<void> stop() async {}
}

void main() {
  testWidgets('switches core interface labels between English and Russian', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final client = MockClient((request) async {
      if (request.method == 'GET') {
        return http.Response('{"runs":[]}', 200);
      }
      throw http.ClientException('offline');
    });
    await tester.pumpWidget(
      RunCoachApp(
        service: RunAnalysisService(client: client),
        initialUser: const AuthUser(
          id: 'test-user',
          email: 'runner@example.com',
          firstName: 'Test',
          lastName: 'Runner',
        ),
        gearTracker: GearTrackerService(storage: MemoryGearStorage()),
        workoutHistory: WorkoutHistoryService(
          storage: MemoryWorkoutStorage(),
        ),
        speechService: _MockSpeechService(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '5.0');
    await tester.enterText(fields.at(1), '30');
    await tester.enterText(fields.at(2), '140');
    await tester.ensureVisible(find.text('Analyze Run'));
    await tester.tap(find.text('Analyze Run'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Analyze Run'), findsOneWidget);
    expect(find.text('Recent runs'), findsWidgets);
    expect(
      find.text(
        'Could not reach the RunCoach server. Check that it is running and your device can connect.',
      ),
      findsOneWidget,
    );

    await tester.fling(
        find.byType(Scrollable).first, const Offset(0, 1000), 1000);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('language-toggle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Русский'), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Анализ пробежки'), findsOneWidget);
    expect(find.text('RU'), findsOneWidget);
    await tester.fling(
      find.byType(CustomScrollView).first,
      const Offset(0, -1000),
      1000,
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Недавние пробежки'), findsWidgets);
    expect(find.text('Расстояние'), findsOneWidget);
    expect(
      find.text(
        'Не удалось связаться с сервером RunCoach. Проверьте, что сервер запущен и устройство может к нему подключиться.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('switches between light and dark app themes', (tester) async {
    final client = MockClient((_) async => http.Response('{"runs":[]}', 200));
    await tester.pumpWidget(
      RunCoachApp(
        service: RunAnalysisService(client: client),
        initialUser: const AuthUser(
          id: 'test-user',
          email: 'runner@example.com',
          firstName: 'Test',
          lastName: 'Runner',
        ),
        gearTracker: GearTrackerService(storage: MemoryGearStorage()),
        workoutHistory: WorkoutHistoryService(
          storage: MemoryWorkoutStorage(),
        ),
        speechService: _MockSpeechService(),
      ),
    );

    expect(find.byTooltip('Switch to dark mode'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('theme-toggle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byTooltip('Switch to light mode'), findsOneWidget);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );

    await tester.tap(find.byKey(const ValueKey('theme-toggle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byTooltip('Switch to dark mode'), findsOneWidget);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.light,
    );
  });
}
