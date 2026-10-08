import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:runcoach_ai/screens/weather_screen.dart';
import 'package:runcoach_ai/services/coach_speech_service.dart';
import 'package:runcoach_ai/services/morning_briefing_service.dart';
import 'package:runcoach_ai/services/weather_location_service.dart';
import 'package:runcoach_ai/services/weather_service.dart';

class _FixedLocationProvider implements WeatherLocationProvider {
  _FixedLocationProvider(this.coordinates);

  final WeatherCoordinates? coordinates;

  @override
  Future<WeatherCoordinates?> getCurrentLocation() async => coordinates;
}

class _RecordingNotifier implements MorningBriefingNotifier {
  String? message;

  @override
  Future<void> send({
    required String message,
    required String languageCode,
  }) async {
    this.message = message;
  }
}

class _RecordingSpeech implements CoachSpeechService {
  String? message;

  @override
  Future<void> speak({
    required String text,
    required String languageCode,
  }) async {
    message = text;
  }

  @override
  Future<void> stop() async {}
}

void main() {
  testWidgets(
      'shows localized weather, shares the morning template, and speaks tips', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final notifier = _RecordingNotifier();
    final speech = _RecordingSpeech();
    late Map<String, dynamic> submittedWeatherPayload;
    final weatherService = WeatherService(
      client: MockClient((request) async {
        submittedWeatherPayload =
            jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'location': {'latitude': 43.2, 'longitude': 76.9},
            'current': {
              'temperature_c': 12,
              'feels_like_c': 11,
              'relative_humidity': 60,
              'precipitation_mm': 0,
              'wind_speed_kmh': 8,
              'weather_code': 1,
              'description': 'Partly cloudy',
            },
            'forecast': {
              'date': '2026-10-03',
              'temperature_min_c': 8,
              'temperature_max_c': 16,
              'precipitation_probability': 10,
              'weather_code': 1,
              'description': 'Partly cloudy',
            },
            'clothing_recommendation': 'Wear breathable layers.',
          }),
          200,
        );
      }),
      baseUrl: 'http://localhost:8000',
    );

    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: const [Locale('en'), Locale('ru')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: WeatherScreen(
          languageCode: 'en',
          onLocaleChanged: (_) {},
          onThemeModeChanged: (_) {},
          service: weatherService,
          notifier: notifier,
          speechService: speech,
          locationProvider: _FixedLocationProvider(null),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Latitude'), findsNothing);
    expect(find.text('Longitude'), findsNothing);
    expect(
        find.text('Location is unavailable. Choose a city.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('weather-location-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Astana').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Recovery jog');
    await tester.tap(find.text('Get weather'));
    await tester.pumpAndSettle();

    expect(submittedWeatherPayload, {
      'latitude': 51.1694,
      'longitude': 71.4491,
      'language': 'en',
    });
    expect(find.text('12°C · Partly cloudy'), findsOneWidget);
    expect(find.text('Wear breathable layers.'), findsOneWidget);
    await tester.drag(
      find.byType(CustomScrollView),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send morning briefing'));
    await tester.pumpAndSettle();
    expect(
      notifier.message,
      'Good morning! Outside today it is 12°C, Partly cloudy. '
      'We recommend choosing Wear breathable layers for maximum freedom of movement. '
      'Do not forget to bring some water to stay hydrated on your run. '
      'Today’s plan: Recovery jog. We wish you a productive run and a great mood '
      'all day long.',
    );

    await tester.tap(find.text('Read coach tip'));
    await tester.pumpAndSettle();
    expect(
        speech.message, contains('Pace guidance: Comfortable per kilometer.'));
    expect(speech.message, contains('Wear breathable layers.'));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('loads weather automatically using detected device coordinates', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    late Map<String, dynamic> submittedWeatherPayload;
    final service = WeatherService(
      client: MockClient((request) async {
        submittedWeatherPayload =
            jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'location': {'latitude': 40.7, 'longitude': -74.0},
            'current': {
              'temperature_c': 18,
              'feels_like_c': 18,
              'relative_humidity': 50,
              'precipitation_mm': 0,
              'wind_speed_kmh': 5,
              'weather_code': 1,
              'description': 'Clear',
            },
            'forecast': {
              'date': '2026-10-03',
              'temperature_min_c': 12,
              'temperature_max_c': 20,
              'precipitation_probability': 0,
              'weather_code': 1,
              'description': 'Clear',
            },
            'clothing_recommendation': 'Light layers.',
          }),
          200,
        );
      }),
      baseUrl: 'http://localhost:8000',
    );

    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: const [Locale('en'), Locale('ru')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: WeatherScreen(
          languageCode: 'en',
          onLocaleChanged: (_) {},
          onThemeModeChanged: (_) {},
          service: service,
          locationProvider: _FixedLocationProvider(
            const WeatherCoordinates(latitude: 40.7, longitude: -74.0),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(submittedWeatherPayload, {
      'latitude': 40.7,
      'longitude': -74.0,
      'language': 'en',
    });
    expect(find.text('18°C · Clear'), findsOneWidget);
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const ValueKey('weather-location-selector')),
          )
          .initialValue,
      'device',
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
