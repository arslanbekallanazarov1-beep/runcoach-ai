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
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? RunAnalysisService.baseUrl;

  final http.Client _client;
  final String _baseUrl;

  void close() => _client.close();

  Future<TrainingPlan> generatePlan({
    required String goal,
    required String fitnessLevel,
    required int timelineWeeks,
    required String language,
  }) async {
    final root = _baseUrl.endsWith('/')
        ? _baseUrl.substring(0, _baseUrl.length - 1)
        : _baseUrl;
    late final http.Response response;
    try {
      final uri = Uri.parse('$root/api/v1/generate-plan').replace(
        queryParameters: {'lang': language},
      );
      response = await _client
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'goal': goal,
              'fitness_level': fitnessLevel,
              'timeline_weeks': timelineWeeks,
              'language': language,
            }),
          )
          .timeout(_trainingPlanTimeout);
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

    if (response.statusCode < 200 || response.statusCode >= 300) {
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
      throw TrainingPlanException(
        detail ?? 'The plan service could not generate a plan.',
        cause: response.statusCode,
        failure: failure,
      );
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Expected a JSON object.');
      }
      final plan = TrainingPlan.fromJson(decoded);
      if (plan.weeks.length != timelineWeeks) {
        throw const FormatException(
          'Training plan does not contain the requested number of weeks.',
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
