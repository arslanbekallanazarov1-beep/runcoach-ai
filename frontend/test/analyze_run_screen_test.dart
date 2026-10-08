import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:runcoach_ai/screens/analyze_run_screen.dart';
import 'package:runcoach_ai/services/run_analysis_service.dart';

void main() {
  testWidgets('shows progress and disables analysis while submitting', (
    tester,
  ) async {
    final pendingResponse = Completer<http.Response>();
    final client = MockClient((request) async {
      if (request.method == 'GET') {
        return http.Response('{"runs":[]}', 200);
      }
      return pendingResponse.future;
    });

    await tester.pumpWidget(
      MaterialApp(
        home: AnalyzeRunScreen(
          service: RunAnalysisService(client: client),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '5.0');
    await tester.enterText(fields.at(1), '31');
    await tester.enterText(fields.at(2), '172');
    expect(find.text('min'), findsOneWidget);
    await tester.ensureVisible(find.text('Analyze Run'));
    await tester.tap(find.text('Analyze Run'));
    await tester.pump();

    expect(find.text('Analyzing run…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    pendingResponse.complete(
      http.Response(
        jsonEncode({
          'status': 'success',
          'metrics': {
            'pace': '6:12',
            'training_load': 217,
            'intensity_zone': 'Hard/Anaerobic',
          },
          'recommendation': 'Recovery Run or Rest Day',
          'coach_feedback': 'Take time to recover before the next run.',
        }),
        200,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Analyze Run'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('submits run details and displays the analysis response', (
    tester,
  ) async {
    late http.Request submittedRequest;
    final client = MockClient((request) async {
      if (request.method == 'GET') {
        return http.Response(
          jsonEncode({
            'runs': [
              {
                'id': 'run-1',
                'date': '2026-09-30T08:00:00+00:00',
                'distance_km': 5.0,
                'time_seconds': 1860,
                'pace': '6:12',
                'avg_hr': 172,
                'rpe': 7,
                'training_load': 217,
                'intensity_zone': 'Hard/Anaerobic',
                'recommendation': 'Recovery Run or Rest Day',
                'coach_feedback':
                    'Strong effort today. Make your next session a gentle recovery run.',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      submittedRequest = request;
      return http.Response(
        jsonEncode({
          'status': 'success',
          'metrics': {
            'pace': '6:12',
            'training_load': 217,
            'intensity_zone': 'Hard/Anaerobic',
          },
          'recommendation': 'Recovery Run or Rest Day',
          'coach_feedback':
              'Strong effort today. Make your next session a gentle recovery run.',
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        home: AnalyzeRunScreen(
          service: RunAnalysisService(
            client: client,
            baseUrl: 'http://localhost:8000',
          ),
        ),
      ),
    );

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '5.0');
    await tester.enterText(fields.at(1), '31');
    await tester.enterText(fields.at(2), '172');

    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('7').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Analyze Run'));
    await tester.tap(find.text('Analyze Run'));
    await tester.pumpAndSettle();

    expect(submittedRequest.method, 'POST');
    expect(submittedRequest.url.path, '/api/v1/analyze_run');
    expect(jsonDecode(submittedRequest.body), {
      'distance_km': 5.0,
      'time_seconds': 1860,
      'avg_hr': 172,
      'rpe': 7,
    });
    expect(find.text('6:12 /km'), findsWidgets);
    expect(find.text('217.00'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Recent runs'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
          'Strong effort today. Make your next session a gentle recovery run.'),
      findsWidgets,
    );
    expect(find.text('Share run card'), findsOneWidget);
    expect(find.text('Recent runs'), findsOneWidget);
    expect(find.text('5.0 km run'), findsOneWidget);
    expect(find.textContaining('31:00'), findsWidgets);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('confirms and deletes an individual saved recent run', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    late http.Request deleteRequest;
    final client = MockClient((request) async {
      if (request.method == 'GET') {
        return http.Response(
          jsonEncode({
            'runs': [
              {
                'id': 'saved-run-1',
                'date': '2026-09-30T08:00:00+00:00',
                'distance_km': 5.0,
                'time_seconds': 1860,
                'pace': '6:12',
                'avg_hr': 172,
                'rpe': 7,
                'training_load': 217,
                'intensity_zone': 'Hard/Anaerobic',
                'recommendation': 'Recovery Run or Rest Day',
                'coach_feedback': 'Recover before your next run.',
              },
            ],
          }),
          200,
        );
      }
      deleteRequest = request;
      return http.Response('{"status":"deleted"}', 200);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: AnalyzeRunScreen(
          service: RunAnalysisService(
            client: client,
            baseUrl: 'http://localhost:8000',
            tokenProvider: () async => 'test-token',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byTooltip('Delete'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Delete this workout?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(deleteRequest.method, 'DELETE');
    expect(deleteRequest.url.path, '/api/v1/runs/saved-run-1');
    expect(deleteRequest.headers['Authorization'], 'Bearer test-token');
    expect(
        find.text('Your analyzed workouts will show up here.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
