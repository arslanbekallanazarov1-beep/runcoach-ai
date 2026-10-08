import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:runcoach_ai/services/weather_service.dart';

void main() {
  test('requests localized weather and parses current and forecast data', () async {
    late http.Request submittedRequest;
    final service = WeatherService(
      client: MockClient((request) async {
        submittedRequest = request;
        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'location': {'latitude': 43.2, 'longitude': 76.9},
            'current': {
              'temperature_c': 12,
              'feels_like_c': 11,
              'relative_humidity': 60,
              'precipitation_mm': 0,
              'wind_speed_kmh': 8,
              'weather_code': 1,
              'description': 'Ясно',
            },
            'forecast': {
              'date': '2026-10-03',
              'temperature_min_c': 8,
              'temperature_max_c': 16,
              'precipitation_probability': 10,
              'weather_code': 1,
              'description': 'Ясно',
            },
            'clothing_recommendation': 'Наденьте лёгкую куртку.',
          })),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
      baseUrl: 'http://localhost:8000/',
    );

    final report = await service.fetchWeather(
      latitude: 43.2,
      longitude: 76.9,
      language: 'ru',
    );

    expect(submittedRequest.url.path, '/api/v1/weather');
    expect(jsonDecode(submittedRequest.body)['language'], 'ru');
    expect(report.temperatureC, 12);
    expect(report.forecastMaximumC, 16);
    expect(report.clothingRecommendation, 'Наденьте лёгкую куртку.');
    service.close();
  });

  test('surfaces weather API errors instead of returning sample data', () async {
    final service = WeatherService(
      client: MockClient((_) async => http.Response('unavailable', 502)),
      baseUrl: 'http://localhost:8000',
    );

    await expectLater(
      service.fetchWeather(
        latitude: 43.2,
        longitude: 76.9,
        language: 'en',
      ),
      throwsA(
        isA<WeatherServiceException>().having(
          (error) => error.statusCode,
          'statusCode',
          502,
        ),
      ),
    );
    service.close();
  });
}
