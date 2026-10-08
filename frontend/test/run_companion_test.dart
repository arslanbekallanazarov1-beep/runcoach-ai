import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:runcoach_ai/screens/analyze_run_screen.dart';
import 'package:runcoach_ai/services/coach_speech_service.dart';
import 'package:runcoach_ai/services/gear_tracker_service.dart';
import 'package:runcoach_ai/services/run_analysis_service.dart';

class _RecordingSpeechService implements CoachSpeechService {
  String? text;
  String? languageCode;

  @override
  Future<void> speak({
    required String text,
    required String languageCode,
  }) async {
    this.text = text;
    this.languageCode = languageCode;
  }

  @override
  Future<void> stop() async {}
}

void main() {
  testWidgets('counts shoe mileage after analysis and reads the tip aloud', (
    tester,
  ) async {
    final gearTracker = GearTrackerService(storage: MemoryGearStorage());
    await gearTracker.load();
    await gearTracker.addShoe(name: 'Daily trainers');
    final speechService = _RecordingSpeechService();
    final client = MockClient((request) async {
      if (request.method == 'GET') {
        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'runs': [
              {
                'id': 'run-1',
                'date': '2026-10-01T08:00:00+00:00',
                'distance_km': 5.0,
                'time_seconds': 1800,
                'pace': '6:00',
                'avg_hr': 140,
                'rpe': 5,
                'training_load': 150,
                'intensity_zone': 'Лёгкая / аэробная',
                'recommendation': 'Базовая аэробная пробежка',
                'coach_feedback': 'Отличная работа. Сохраняйте лёгкий темп.',
              },
            ],
          })),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response.bytes(
        utf8.encode(jsonEncode({
          'status': 'success',
          'metrics': {
            'pace': '6:00',
            'training_load': 150,
            'intensity_zone': 'Лёгкая / аэробная',
          },
          'recommendation': 'Базовая аэробная пробежка',
          'coach_feedback': 'Отличная работа. Сохраняйте лёгкий темп.',
        })),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        supportedLocales: const [Locale('en'), Locale('ru')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: AnalyzeRunScreen(
          service: RunAnalysisService(client: client),
          gearTracker: gearTracker,
          speechService: speechService,
          languageCode: 'ru',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '5');
    await tester.enterText(fields.at(1), '30');
    await tester.enterText(fields.at(2), '140');
    final analyzeButton = find.widgetWithText(FilledButton, 'Анализ пробежки');
    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, -350),
    );
    await tester.pumpAndSettle();
    await tester.tap(analyzeButton);
    await tester.pumpAndSettle();

    expect(gearTracker.shoes.single.totalKilometers, 5);
    await tester.scrollUntilVisible(
      find.text('Прогноз результата'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Прогноз результата'), findsOneWidget);
    expect(find.text('30:00'), findsWidgets);

    await tester.ensureVisible(find.byTooltip('Озвучить совет'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Озвучить совет'));
    await tester.pumpAndSettle();
    expect(speechService.languageCode, 'ru');
    expect(speechService.text, contains('Базовая аэробная пробежка'));
    expect(speechService.text, contains('Отличная работа.'));

    await tester.pumpWidget(const SizedBox.shrink());
    gearTracker.dispose();
  });
}
