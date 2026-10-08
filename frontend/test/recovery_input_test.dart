import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:runcoach_ai/screens/analyze_run_screen.dart';
import 'package:runcoach_ai/services/run_analysis_service.dart';

void main() {
  testWidgets('submits optional sleep and resting heart rate with auth', (
    tester,
  ) async {
    late http.Request analysisRequest;
    final service = RunAnalysisService(
      client: MockClient((request) async {
        if (request.method == 'GET') return http.Response('{"runs":[]}', 200);
        analysisRequest = request;
        return http.Response(
          jsonEncode({
            'status': 'success',
            'metrics': {
              'pace': '6:00',
              'training_load': 150,
              'intensity_zone': 'Easy/Aerobic',
            },
            'recommendation': 'Recovery Run or Rest Day',
            'coach_feedback': 'Rest and recover before your next run.',
          }),
          200,
        );
      }),
      baseUrl: 'http://localhost:8000',
      tokenProvider: () async => 'signed.jwt.token',
    );
    await tester.pumpWidget(MaterialApp(home: AnalyzeRunScreen(service: service)));

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '5');
    await tester.enterText(fields.at(1), '30');
    await tester.enterText(fields.at(2), '140');
    await tester.tap(find.text('Recovery metrics (optional)'));
    await tester.pumpAndSettle();
    final expandedFields = find.byType(TextFormField);
    await tester.enterText(expandedFields.at(3), '4.5');
    await tester.enterText(expandedFields.at(4), '100');
    await tester.drag(
      find.byType(CustomScrollView),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Analyze Run'));
    await tester.pumpAndSettle();

    expect(analysisRequest.headers['authorization'], 'Bearer signed.jwt.token');
    expect(jsonDecode(analysisRequest.body), {
      'distance_km': 5.0,
      'time_seconds': 1800,
      'avg_hr': 140,
      'rpe': 5,
      'sleep_hours': 4.5,
      'resting_hr': 100,
    });
    expect(find.text('Recovery Run or Rest Day'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
