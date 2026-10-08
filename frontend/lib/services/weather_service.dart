import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/weather_report.dart';
import 'run_analysis_service.dart';

class WeatherService {
  WeatherService({
    http.Client? client,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? RunAnalysisService.baseUrl;

  final http.Client _client;
  final String _baseUrl;

  void close() => _client.close();

  Future<WeatherReport> fetchWeather({
    required double latitude,
    required double longitude,
    required String language,
  }) async {
    final root = _baseUrl.endsWith('/')
        ? _baseUrl.substring(0, _baseUrl.length - 1)
        : _baseUrl;
    late final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$root/api/v1/weather'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'latitude': latitude,
              'longitude': longitude,
              'language': language,
            }),
          )
          .timeout(const Duration(seconds: 15));
    } on Exception catch (error) {
      throw WeatherServiceException(cause: error);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw WeatherServiceException(statusCode: response.statusCode);
    }
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Expected a weather object.');
      }
      return WeatherReport.fromJson(decoded);
    } on FormatException catch (error) {
      throw WeatherServiceException(cause: error);
    }
  }
}

class WeatherServiceException implements Exception {
  const WeatherServiceException({this.statusCode, this.cause});

  final int? statusCode;
  final Object? cause;

  @override
  String toString() => 'Weather request failed '
      '(HTTP ${statusCode ?? 'connection/response error'}).';
}
