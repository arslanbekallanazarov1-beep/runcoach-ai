import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/training_plan.dart';
import 'run_analysis_service.dart';

const _trainingPlanTimeout = Duration(seconds: 90);

class TrainingPlanService {
  TrainingPlanService({
    http.Client? client,
    String? baseUrl,
    Future<String?> Function()? tokenProvider,
  })  : _client = client ?? http.Client(),
        _baseUrl = RunAnalysisService.normalizeBaseUrl(
          baseUrl ?? RunAnalysisService.baseUrl,
        ),
        _tokenProvider = tokenProvider;

  final http.Client _client;
  final String _baseUrl;
  final Future<String?> Function()? _tokenProvider;

  void close() => _client.close();

  Future<TrainingPlan> generatePlan({
    required String goal,
    required String fitnessLevel,
    required int timelineWeeks,
    required String language,
  }) async {
    final response = await _sendRequest(
      () async => _client
          .post(
            Uri.parse('$_baseUrl/api/v1/training-plan'),
            headers: await _headers(),
            body: jsonEncode({
              'goal': goal,
              'fitness_level': fitnessLevel,
              'timeline_weeks': timelineWeeks,
              'language': language,
            }),
          )
          .timeout(_trainingPlanTimeout),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _httpException(response);
    }

    final plan = _parsePlan(response.body);
    if (plan.weeks.length != timelineWeeks) {
      throw const TrainingPlanException(
        'The plan service returned an invalid plan.',
        failure: TrainingPlanFailure.invalidResponse,
      );
    }
    return plan;
  }

  Future<TrainingPlan?> fetchPlan() async {
    final response = await _sendRequest(
      () async => _client
          .get(
            Uri.parse('$_baseUrl/api/v1/training-plan'),
            headers: await _headers(),
          )
          .timeout(const Duration(seconds: 15)),
    );
    if (response.statusCode == 404) return null;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _httpException(response);
    }
    return _parsePlan(response.body);
  }

  Future<void> updateWorkoutCompletion({
    required String planId,
    required String workoutId,
    required bool completed,
  }) async {
    final response = await _sendRequest(
      () async => _client
          .patch(
            Uri.parse(
              '$_baseUrl/api/v1/training-plan/$planId/workouts/$workoutId',
            ),
            headers: await _headers(),
            body: jsonEncode({'completed': completed}),
          )
          .timeout(const Duration(seconds: 15)),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _httpException(response);
    }
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> ||
          decoded['workout_id'] != workoutId ||
          decoded['completed'] != completed ||
          decoded['status'] != 'updated') {
        throw const FormatException('Expected an updated workout response.');
      }
    } on FormatException catch (error) {
      throw TrainingPlanException(
        'The plan service returned an invalid workout status.',
        cause: error,
        failure: TrainingPlanFailure.invalidResponse,
      );
    }
  }

  Future<http.Response> _sendRequest(
    Future<http.Response> Function() request,
  ) async {
    try {
      return await request();
    } on TimeoutException {
      throw const TrainingPlanException(
        'The plan provider timed out.',
        failure: TrainingPlanFailure.providerTimeout,
      );
    } on Exception catch (error) {
      throw TrainingPlanException(
        'Could not connect to the training plan service.',
        cause: error,
        failure: TrainingPlanFailure.connection,
      );
    }
  }

  Future<Map<String, String>> _headers() async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    final token = await _tokenProvider?.call();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = '******';
    }
    return headers;
  }

  TrainingPlan _parsePlan(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Expected a JSON object.');
      }
      final plan = TrainingPlan.fromJson(decoded);
      if (plan.id == null ||
          plan.weeks.any(
            (week) => week.workouts.any((workout) => workout.id == null),
          )) {
        throw const FormatException(
          'Saved plans must include plan and workout IDs.',
        );
      }
      return plan;
    } on FormatException catch (error) {
      throw TrainingPlanException(
        'The plan service returned an invalid plan.',
        cause: error,
        failure: TrainingPlanFailure.invalidResponse,
      );
    }
  }

  TrainingPlanException _httpException(http.Response response) {
    final detail = _responseDetail(response.body);
    final failure = switch (detail) {
      'plan_ai_not_configured' => TrainingPlanFailure.notConfigured,
      'plan_ai_timeout' => TrainingPlanFailure.providerTimeout,
      'plan_ai_provider_error' ||
      'plan_generation_unavailable' =>
        TrainingPlanFailure.providerUnavailable,
      'plan_invalid_response' => TrainingPlanFailure.invalidResponse,
      _ => TrainingPlanFailure.http,
    };
    return TrainingPlanException(
      detail ?? 'The plan service could not complete the request.',
      cause: response.statusCode,
      failure: failure,
    );
  }

  String? _responseDetail(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic> && decoded['detail'] is String) {
        return decoded['detail'] as String;
      }
    } on FormatException {
      return null;
    }
    return null;
  }
}

enum TrainingPlanFailure {
  connection,
  notConfigured,
  providerTimeout,
  providerUnavailable,
  invalidResponse,
  http,
}

class TrainingPlanException implements Exception {
  const TrainingPlanException(
    this.message, {
    this.cause,
    this.failure = TrainingPlanFailure.http,
  });

  final String message;
  final Object? cause;
  final TrainingPlanFailure failure;

  @override
  String toString() => message;
}
