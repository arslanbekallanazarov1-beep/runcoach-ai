import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:runcoach_ai/screens/training_plan_screen.dart';
import 'package:runcoach_ai/services/training_plan_service.dart';

void main() {
  final planJson = {
    'id': 'plan-123',
    'title': 'Almaty Half Marathon plan',
    'overview': 'Build endurance gradually.',
    'weeks': [
      {
        'week': 1,
        'focus': 'Easy foundation',
        'workouts': [
          {
            'id': 'workout-mon',
            'day': 'Monday',
            'title': 'Easy run',
            'description': 'Run at a conversational effort.',
            'duration_minutes': 30,
          },
          {
            'id': 'workout-wed',
            'day': 'Wednesday',
            'title': 'Intervals',
            'description': 'Four short controlled efforts.',
            'duration_minutes': 35,
          },
          {
            'id': 'workout-sat',
            'day': 'Saturday',
            'title': 'Long run',
            'description': 'Keep the pace comfortable.',
            'duration_minutes': 45,
          },
        ],
      },
    ],
  };

  test('posts plan goal, fitness level, timeline and language', () async {
    late http.Request submittedRequest;
    final client = MockClient((request) async {
      submittedRequest = request;
      return http.Response(jsonEncode(planJson), 200);
    });
    final service = TrainingPlanService(
      client: client,
      baseUrl: 'http://localhost:8000/',
      tokenProvider: () async => 'test-token',
    );

    final plan = await service.generatePlan(
      goal: 'Almaty Half Marathon',
      fitnessLevel: 'beginner',
      timelineWeeks: 1,
      language: 'ru',
    );

    expect(submittedRequest.method, 'POST');
    expect(submittedRequest.url.path, '/api/v1/training-plan');
    expect(submittedRequest.headers['authorization'], '******');
    expect(jsonDecode(submittedRequest.body), {
      'goal': 'Almaty Half Marathon',
      'fitness_level': 'beginner',
      'timeline_weeks': 1,
      'language': 'ru',
    });
    expect(plan.id, 'plan-123');
    expect(plan.weeks.single.workouts.first.id, 'workout-mon');
    expect(plan.weeks.single.workouts.length, 3);
    expect(plan.weeks.single.workouts.first.durationMinutes, 30);
    service.close();
  });

  test('loads a saved plan and persists workout completion', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.method == 'GET') {
        return http.Response(jsonEncode(planJson), 200);
      }
      return http.Response(
        jsonEncode({
          'status': 'updated',
          'workout_id': 'workout-mon',
          'completed': true,
          'completed_at': '2026-10-10T12:00:00+00:00',
        }),
        200,
      );
    });
    final service = TrainingPlanService(
      client: client,
      baseUrl: 'http://localhost:8000',
      tokenProvider: () async => 'test-token',
    );

    final plan = await service.fetchPlan();
    expect(plan?.id, 'plan-123');
    expect(plan?.weeks.single.workouts.first.completed, isFalse);
    await service.updateWorkoutCompletion(
      planId: plan!.id!,
      workoutId: 'workout-mon',
      completed: true,
    );

    expect(requests.map((request) => request.method), ['GET', 'PATCH']);
    expect(requests.first.url.path, '/api/v1/training-plan');
    expect(
      requests.last.url.path,
      '/api/v1/training-plan/plan-123/workouts/workout-mon',
    );
    expect(requests.last.headers['authorization'], '******');
    expect(jsonDecode(requests.last.body), {'completed': true});
    service.close();
  });

  testWidgets('submits plan request and renders the weekly schedule', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    late http.Request submittedRequest;
    final client = MockClient((request) async {
      if (request.method == 'GET') {
        return http.Response(
          jsonEncode({'detail': 'No active training plan found.'}),
          404,
        );
      }
      submittedRequest = request;
      return http.Response(jsonEncode(planJson), 200);
    });

    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: const [Locale('en'), Locale('ru')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: TrainingPlanScreen(
          languageCode: 'en',
          onLocaleChanged: (_) {},
          onThemeModeChanged: (_) {},
          service: TrainingPlanService(
            client: client,
            baseUrl: 'http://localhost:8000',
            tokenProvider: () async => 'test-token',
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byType(TextFormField).first,
      'Almaty Half Marathon',
    );
    await tester.enterText(find.byType(TextFormField).last, '1');
    await tester.ensureVisible(find.text('Generate plan'));
    await tester.tap(find.text('Generate plan'));
    await tester.pumpAndSettle();

    expect(jsonDecode(submittedRequest.body)['language'], 'en');
    expect(submittedRequest.url.path, '/api/v1/training-plan');
    expect(find.text('Almaty Half Marathon plan'), findsOneWidget);
    expect(find.text('Week 1'), findsOneWidget);
    expect(
      find.textContaining('Easy foundation'),
      findsOneWidget,
    );
    expect(find.text('Run at a conversational effort.'), findsOneWidget);
    expect(find.text('30 min'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('checks a workout and persists its completion', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.method == 'GET') {
        return http.Response(
          jsonEncode({'detail': 'No active training plan found.'}),
          404,
        );
      }
      if (request.method == 'POST') {
        return http.Response(jsonEncode(planJson), 200);
      }
      return http.Response(
        jsonEncode({
          'status': 'updated',
          'workout_id': 'workout-mon',
          'completed': true,
          'completed_at': '2026-10-10T12:00:00+00:00',
        }),
        200,
      );
    });
    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: const [Locale('en'), Locale('ru')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: TrainingPlanScreen(
          languageCode: 'en',
          onLocaleChanged: (_) {},
          onThemeModeChanged: (_) {},
          service: TrainingPlanService(
            client: client,
            baseUrl: 'http://localhost:8000',
            tokenProvider: () async => 'test-token',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).first,
      'Almaty Half Marathon',
    );
    await tester.enterText(find.byType(TextFormField).last, '1');
    await tester.ensureVisible(find.text('Generate plan'));
    await tester.tap(find.text('Generate plan'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    expect(requests.map((request) => request.method), ['GET', 'POST', 'PATCH']);
    expect(requests.last.url.path,
        '/api/v1/training-plan/plan-123/workouts/workout-mon');
    expect(jsonDecode(requests.last.body), {'completed': true});
    expect(tester.widget<Checkbox>(find.byType(Checkbox).first).value, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('explains when plan generation is not configured on the server', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final client = MockClient(
      (request) async => request.method == 'GET'
          ? http.Response(
              jsonEncode({'detail': 'No active training plan found.'}),
              404,
            )
          : http.Response(
              jsonEncode({'detail': 'plan_ai_not_configured'}),
              503,
            ),
    );
    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: const [Locale('en'), Locale('ru')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: TrainingPlanScreen(
          languageCode: 'en',
          onLocaleChanged: (_) {},
          onThemeModeChanged: (_) {},
          service: TrainingPlanService(
            client: client,
            baseUrl: 'http://localhost:8000',
            tokenProvider: () async => 'test-token',
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byType(TextFormField).first,
      '10K race',
    );
    await tester.ensureVisible(find.text('Generate plan'));
    await tester.tap(find.text('Generate plan'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Plan generation is not configured on the server. Contact the administrator.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
