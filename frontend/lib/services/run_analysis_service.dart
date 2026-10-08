import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/run_analysis.dart';
import '../models/run_history_item.dart';

enum RunAnalysisError {
  connection,
  analyzeHttp,
  historyConnection,
  historyHttp,
  deleteConnection,
  deleteHttp,
  invalidAnalysisResponse,
  invalidHistoryResponse,
}

class RunAnalysisService {
  RunAnalysisService({
    http.Client? client,
    String? baseUrl,
    Future<String?> Function()? tokenProvider,
  })  : _client = client ?? http.Client(),
        _baseUrl = normalizeBaseUrl(baseUrl ?? RunAnalysisService.baseUrl),
        _tokenProvider = tokenProvider;

  /// The API base URL used by this service.
  ///
  /// Resolution order (highest priority first):
  ///
  /// 1. [RUNCOACH_API_BASE_URL] environment variable (set via
  ///    `--dart-define=RUNCOACH_API_BASE_URL=...` at build/run time).
  /// 2. [API_BASE_URL] environment variable (set via
  ///    `--dart-define=API_BASE_URL=...` at build/run time), including an
  ///    HTTPS URL for a deployed backend.
  /// 3. Platform default: `http://localhost:8000` on Web;
  ///    `http://192.168.1.3:8000` on mobile (the host machine's LAN address so
  ///    a real device does not point at localhost).
  ///
  /// To make the app talk to a backend at a specific address, prefer option 1
  /// or 2 with `--dart-define`. For example, from the repo root:
  ///
  /// ```bash
  /// flutter run -d <device> --dart-define=API_BASE_URL=http://<host-lan-ip>:8000
  /// flutter build apk --dart-define=API_BASE_URL=http://<host-lan-ip>:8000
  /// ```
  static String get baseUrl => resolveBaseUrl(
        configuredUrl: const String.fromEnvironment('RUNCOACH_API_BASE_URL'),
        dartDefineUrl: const String.fromEnvironment('API_BASE_URL'),
      );

  /// Returns the API base URL by applying the resolution order above to the
  /// given environment values. Useful for tests.
  static String resolveBaseUrl({
    required String configuredUrl,
    required String dartDefineUrl,
  }) {
    if (configuredUrl.trim().isNotEmpty) {
      return normalizeBaseUrl(configuredUrl);
    }
    if (dartDefineUrl.trim().isNotEmpty) {
      return normalizeBaseUrl(dartDefineUrl);
    }
    return kIsWeb ? 'http://localhost:8000' : 'http://192.168.1.3:8000';
  }

  static String normalizeBaseUrl(String value) =>
      value.trim().replaceFirst(RegExp(r'/+$'), '');

  static const _endpointPath = '/api/v1/analyze_run';

  final http.Client _client;
  final String _baseUrl;
  final Future<String?> Function()? _tokenProvider;

  void close() => _client.close();

  Future<RunAnalysis> analyzeRun({
    required double distanceKm,
    required int timeSeconds,
    required int averageHeartRate,
    required int rpe,
    required String language,
    double? sleepHours,
    int? restingHeartRate,
  }) async {
    final uri = Uri.parse('$_baseUrl$_endpointPath').replace(
      queryParameters: {'lang': language},
    );

    late final http.Response response;
    try {
      final payload = <String, Object>{
        'distance_km': distanceKm,
        'time_seconds': timeSeconds,
        'avg_hr': averageHeartRate,
        'rpe': rpe,
      };
      if (sleepHours != null) payload['sleep_hours'] = sleepHours;
      if (restingHeartRate != null) {
        payload['resting_hr'] = restingHeartRate;
      }
      response = await _client
          .post(
            uri,
            headers: await _headers(),
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 35));
    } on Exception catch (error) {
      throw RunAnalysisException(
        RunAnalysisError.connection,
        cause: error,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw RunAnalysisException(
        RunAnalysisError.analyzeHttp,
        statusCode: response.statusCode,
      );
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Expected a JSON object.');
      }
      return RunAnalysis.fromJson(decoded);
    } on FormatException catch (error) {
      throw RunAnalysisException(
        RunAnalysisError.invalidAnalysisResponse,
        cause: error,
      );
    }
  }

  Future<List<RunHistoryItem>> fetchRecentRuns({
    int limit = 20,
    required String language,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/v1/runs').replace(
      queryParameters: {'limit': '$limit', 'lang': language},
    );

    late final http.Response response;
    try {
      response = await _client
          .get(uri, headers: await _headers())
          .timeout(const Duration(seconds: 15));
    } on Exception catch (error) {
      throw RunAnalysisException(
        RunAnalysisError.historyConnection,
        cause: error,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw RunAnalysisException(
        RunAnalysisError.historyHttp,
        statusCode: response.statusCode,
      );
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> || decoded['runs'] is! List) {
        throw const FormatException('Expected a runs list.');
      }

      return (decoded['runs'] as List).map((run) {
        if (run is! Map<String, dynamic>) {
          throw const FormatException('Expected a run object.');
        }
        return RunHistoryItem.fromJson(run);
      }).toList(growable: false);
    } on FormatException catch (error) {
      throw RunAnalysisException(
        RunAnalysisError.invalidHistoryResponse,
        cause: error,
      );
    }
  }

  Future<void> deleteRun(String runId) async {
    final uri = Uri.parse('$_baseUrl/api/v1/runs/$runId');

    late final http.Response response;
    try {
      response = await _client
          .delete(uri, headers: await _headers())
          .timeout(const Duration(seconds: 15));
    } on Exception catch (error) {
      throw RunAnalysisException(
        RunAnalysisError.deleteConnection,
        cause: error,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw RunAnalysisException(
        RunAnalysisError.deleteHttp,
        statusCode: response.statusCode,
      );
    }
  }

  Future<Map<String, String>> _headers() async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    final token = await _tokenProvider?.call();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }
}

class RunAnalysisException implements Exception {
  const RunAnalysisException(
    this.code, {
    this.statusCode,
    this.cause,
  });

  final RunAnalysisError code;
  final int? statusCode;
  final Object? cause;

  String get message => switch (code) {
        RunAnalysisError.connection =>
          'Could not reach the RunCoach server. Check that it is running and '
              'your device can connect.',
        RunAnalysisError.analyzeHttp =>
          'The server could not analyze this run (HTTP ${statusCode ?? 0}). '
              'Check the run details and try again.',
        RunAnalysisError.historyConnection =>
          'Could not load recent runs. Check that the RunCoach server is running.',
        RunAnalysisError.historyHttp =>
          'The server could not load run history (HTTP ${statusCode ?? 0}).',
        RunAnalysisError.deleteConnection =>
          'Could not reach the server to delete this run.',
        RunAnalysisError.deleteHttp =>
          'The server could not delete this run (HTTP ${statusCode ?? 0}).',
        RunAnalysisError.invalidAnalysisResponse =>
          'The server returned an unexpected analysis response.',
        RunAnalysisError.invalidHistoryResponse =>
          'The server returned an unexpected run history response.',
      };

  @override
  String toString() => message;
}
