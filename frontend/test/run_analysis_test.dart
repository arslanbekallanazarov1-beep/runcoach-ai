import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:runcoach_ai/models/run_analysis.dart';
import 'package:runcoach_ai/models/run_history_item.dart';
import 'package:runcoach_ai/services/run_analysis_service.dart';

void main() {
  group('RunAnalysis.fromJson', () {
    test('parses the backend response', () {
      final result = RunAnalysis.fromJson({
        'status': 'success',
        'metrics': {
          'pace': '6:00',
          'training_load': 150.0,
          'intensity_zone': 'Easy/Aerobic',
        },
        'recommendation': 'Base Aerobic Run',
        'coach_feedback': 'Nice work. Keep the next run comfortable.',
      });

      expect(result.pace, '6:00');
      expect(result.trainingLoad, 150.0);
      expect(result.intensityZone, 'Easy/Aerobic');
      expect(result.recommendation, 'Base Aerobic Run');
      expect(result.coachFeedback, contains('Nice work'));
    });

    test('rejects invalid response shapes', () {
      expect(
        () => RunAnalysis.fromJson({'status': 'failure'}),
        throwsFormatException,
      );
    });

    test('parses a persisted run history item', () {
      final run = RunHistoryItem.fromJson({
        'id': 'run-1',
        'date': '2026-09-30T08:00:00+00:00',
        'distance_km': 5.0,
        'time_seconds': 1860,
        'pace': '6:12',
        'avg_hr': 172,
        'rpe': 7,
        'sleep_hours': 5.5,
        'resting_hr': 61,
        'training_load': 217.0,
        'intensity_zone': 'Hard/Anaerobic',
        'recommendation': 'Recovery Run or Rest Day',
        'coach_feedback': 'Strong effort. Recover before your next workout.',
      });

      expect(run.distanceKm, 5.0);
      expect(run.pace, '6:12');
      expect(run.trainingLoad, 217.0);
      expect(run.coachFeedback, contains('Recover'));
      expect(run.sleepHours, 5.5);
      expect(run.restingHeartRate, 61);
    });
  });

  group('RunAnalysisService', () {
    test('uses the configured API URL or platform-appropriate default', () {
      expect(
        RunAnalysisService.baseUrl,
        RunAnalysisService.resolveBaseUrl(
          configuredUrl: const String.fromEnvironment('RUNCOACH_API_BASE_URL'),
          dartDefineUrl: const String.fromEnvironment('API_BASE_URL'),
        ),
      );
    });

    test('prioritizes RUNCOACH_API_BASE_URL over API_BASE_URL', () {
      expect(
        RunAnalysisService.resolveBaseUrl(
          configuredUrl: 'http://configured:8000',
          dartDefineUrl: 'http://dart-defined:8000',
        ),
        'http://configured:8000',
      );
    });

    test('uses API_BASE_URL when RUNCOACH_API_BASE_URL is empty', () {
      expect(
        RunAnalysisService.resolveBaseUrl(
          configuredUrl: '',
          dartDefineUrl: ' https://runcoach-api.example.com/ ',
        ),
        'https://runcoach-api.example.com',
      );
    });

    test('uses the platform default when URL defines contain only whitespace',
        () {
      expect(
        RunAnalysisService.resolveBaseUrl(
          configuredUrl: ' ',
          dartDefineUrl: '\t',
        ),
        kIsWeb ? 'http://localhost:8000' : 'http://192.168.1.3:8000',
      );
    });

    test('uses the matching analysis endpoint path', () async {
      late http.Request sentRequest;
      final client = MockClient((request) async {
        sentRequest = request;
        return http.Response(
          jsonEncode({
            'status': 'success',
            'metrics': {
              'pace': '6:00',
              'training_load': 150,
              'intensity_zone': 'Easy/Aerobic',
            },
            'recommendation': 'Base Aerobic Run',
            'coach_feedback': 'Good run. Keep building steadily.',
          }),
          200,
        );
      });
      final service = RunAnalysisService(
        client: client,
        baseUrl: 'http://127.0.0.1:8000/',
      );

      await service.analyzeRun(
        distanceKm: 5,
        timeSeconds: 1800,
        averageHeartRate: 140,
        rpe: 5,
        language: 'en',
      );

      expect(sentRequest.url.toString(),
          'http://127.0.0.1:8000/api/v1/analyze_run?lang=en');
      client.close();
    });

    test('fetches recent runs from the history endpoint', () async {
      late http.Request sentRequest;
      final client = MockClient((request) async {
        sentRequest = request;
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
                'training_load': 217.0,
                'intensity_zone': 'Hard/Anaerobic',
                'recommendation': 'Recovery Run or Rest Day',
                'coach_feedback': 'Strong effort. Recover well.',
              },
            ],
          }),
          200,
        );
      });
      final service = RunAnalysisService(
        client: client,
        baseUrl: 'http://127.0.0.1:8000',
      );

      final runs = await service.fetchRecentRuns(language: 'ru');

      expect(sentRequest.method, 'GET');
      expect(sentRequest.url.path, '/api/v1/runs');
      expect(sentRequest.url.queryParameters, {'limit': '20', 'lang': 'ru'});
      expect(runs.single.pace, '6:12');
      client.close();
    });

    test('posts run metrics to the analysis endpoint', () async {
      late http.Request sentRequest;
      final client = MockClient((request) async {
        sentRequest = request;
        return http.Response(
          jsonEncode({
            'status': 'success',
            'metrics': {
              'pace': '6:00',
              'training_load': 150,
              'intensity_zone': 'Easy/Aerobic',
            },
            'recommendation': 'Base Aerobic Run',
            'coach_feedback': 'Good run. Keep building steadily.',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final service = RunAnalysisService(
        client: client,
        baseUrl: 'http://localhost:8000/',
      );

      final result = await service.analyzeRun(
        distanceKm: 5,
        timeSeconds: 1800,
        averageHeartRate: 140,
        rpe: 5,
        language: 'en',
      );

      expect(sentRequest.url.toString(),
          'http://localhost:8000/api/v1/analyze_run?lang=en');
      expect(sentRequest.method, 'POST');
      expect(jsonDecode(sentRequest.body), {
        'distance_km': 5.0,
        'time_seconds': 1800,
        'avg_hr': 140,
        'rpe': 5,
      });
      expect(result.recommendation, 'Base Aerobic Run');
      client.close();
    });

    test('reports unsuccessful HTTP responses', () async {
      final client = MockClient((_) async => http.Response('Bad request', 422));
      final service = RunAnalysisService(
        client: client,
        baseUrl: 'http://localhost:8000',
      );

      await expectLater(
        service.analyzeRun(
          distanceKm: 5,
          timeSeconds: 1800,
          averageHeartRate: 140,
          rpe: 5,
          language: 'en',
        ),
        throwsA(isA<RunAnalysisException>()),
      );
      client.close();
    });
  });
}
