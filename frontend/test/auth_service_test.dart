import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:runcoach_ai/services/auth_service.dart';
import 'package:runcoach_ai/services/run_analysis_service.dart';
import 'package:runcoach_ai/models/auth_user.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('registers, persists, restores, and clears the account session',
      () async {
    late http.Request request;
    final service = AuthService(
      client: MockClient((submitted) async {
        request = submitted;
        return http.Response(
          jsonEncode({
            'user': {
              'id': 'runner-1',
              'email': 'runner@example.com',
              'first_name': 'Alex',
              'last_name': 'Runner',
              'available_training_days': [],
            },
            'token': 'signed.jwt.token',
            'token_type': 'bearer',
          }),
          200,
        );
      }),
      baseUrl: 'http://localhost:8000',
    );

    final user = await service.register(
      email: 'runner@example.com',
      password: 'secure-password',
      firstName: 'Alex',
      lastName: 'Runner',
    );

    expect(request.url.path, '/api/v1/auth/register');
    expect(jsonDecode(request.body)['first_name'], 'Alex');
    expect(user.email, 'runner@example.com');
    expect(service.accessToken, 'signed.jwt.token');

    final restored = AuthService(
      client: MockClient((_) async => http.Response('', 500)),
    );
    final restoredUser = await restored.restoreSession();
    expect(restoredUser?.id, 'runner-1');
    expect(restored.accessToken, 'signed.jwt.token');

    await restored.logout();
    expect(restored.currentUser, isNull);
    expect(restored.accessToken, isNull);
    service.close();
    restored.close();
  });

  test('surfaces non-successful authentication responses', () async {
    final service = AuthService(
      client:
          MockClient((_) async => http.Response('{"detail":"invalid"}', 401)),
      baseUrl: 'http://localhost:8000',
    );
    await expectLater(
      service.login(email: 'runner@example.com', password: 'wrong'),
      throwsA(
        isA<AuthException>().having(
          (error) => error.statusCode,
          'statusCode',
          401,
        ),
      ),
    );
    service.close();
  });

  test('uses the shared configured API URL for authentication', () async {
    late http.Request request;
    final service = AuthService(
      client: MockClient((submitted) async {
        request = submitted;
        return http.Response(
          jsonEncode({
            'user': {
              'id': 'runner-1',
              'email': 'runner@example.com',
              'first_name': 'Alex',
              'last_name': 'Runner',
              'available_training_days': [],
            },
            'token': 'signed.jwt.token',
            'token_type': 'bearer',
          }),
          200,
        );
      }),
    );

    await service.login(
      email: 'runner@example.com',
      password: 'secure-password',
    );

    expect(request.url.origin, Uri.parse(RunAnalysisService.baseUrl).origin);
    expect(request.url.path, '/api/v1/auth/login');
    service.close();
  });

  test('updates max HR and age and parses authenticated heart rate zones',
      () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.method == 'POST') {
        return http.Response(
          jsonEncode({
            'user': {
              'id': 'runner-1',
              'email': 'runner@example.com',
              'first_name': 'Alex',
              'last_name': 'Runner',
            },
            'token': 'signed.jwt.token',
          }),
          200,
        );
      }
      if (request.method == 'PATCH') {
        return http.Response(
          jsonEncode({
            'user': {
              'id': 'runner-1',
              'email': 'runner@example.com',
              'first_name': 'Alex',
              'last_name': 'Runner',
              'max_hr': 188,
              'age': 34,
              'available_training_days': [],
            },
          }),
          200,
        );
      }
      return http.Response(
        jsonEncode({
          'max_hr': 188,
          'age': 34,
          'zones': [
            {'zone': 'Z1 Very Light', 'min_bpm': 94, 'max_bpm': 112},
            {'zone': 'Z5 Maximum', 'min_bpm': 169, 'max_bpm': 188},
          ],
        }),
        200,
      );
    });
    final service = AuthService(
      client: client,
      baseUrl: 'http://localhost:8000/',
    );
    await service.register(
      email: 'runner@example.com',
      password: 'secure-password',
      firstName: 'Alex',
      lastName: 'Runner',
    );

    final updated = await service.updateProfile(maxHr: 188, age: 34);
    final zones = await service.fetchHeartRateZones();

    expect(requests[1].url.path, '/api/v1/profile');
    expect(requests[1].method, 'PATCH');
    expect(jsonDecode(requests[1].body), {'max_hr': 188, 'age': 34});
    expect(
      requests[1].headers['Authorization'],
      startsWith('Bearer '),
    );
    expect(updated.maxHr, 188);
    expect(updated.age, 34);
    expect(requests[2].url.path, '/api/v1/heart-rate-zones');
    expect(
      requests[2].headers['Authorization'],
      startsWith('Bearer '),
    );
    expect(zones, {
      'Z1 Very Light': {'min': 94, 'max': 112},
      'Z5 Maximum': {'min': 169, 'max': 188},
    });
    expect(
      AuthUser.fromJson({
        'id': 'runner-1',
        'email': 'runner@example.com',
        'first_name': 'Alex',
        'last_name': 'Runner',
        'available_training_days': ['mon', 'wed'],
      }).availableTrainingDays,
      ['mon', 'wed'],
    );
    await service.updateProfile(clearMaxHr: true, clearAge: true);
    expect(jsonDecode(requests.last.body), {'max_hr': null, 'age': null});
    service.close();
  });
}
