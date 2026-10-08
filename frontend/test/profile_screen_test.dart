import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:runcoach_ai/models/auth_user.dart';
import 'package:runcoach_ai/screens/profile_screen.dart';
import 'package:runcoach_ai/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('edits max HR and age and displays calculated zones', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final requests = <http.Request>[];
    final service = AuthService(
      client: MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'max_hr': 190,
              'age': 36,
              'zones': [
                {'zone': 'Z1 Very Light', 'min_bpm': 95, 'max_bpm': 114},
                {'zone': 'Z2 Light', 'min_bpm': 114, 'max_bpm': 133},
                {'zone': 'Z3 Moderate', 'min_bpm': 133, 'max_bpm': 152},
                {'zone': 'Z4 Hard', 'min_bpm': 152, 'max_bpm': 171},
                {'zone': 'Z5 Maximum', 'min_bpm': 171, 'max_bpm': 190},
              ],
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'user': {
              'id': 'runner-1',
              'email': 'runner@example.com',
              'first_name': 'Alex',
              'last_name': 'Runner',
              'max_hr': 190,
              'age': 36,
            },
          }),
          200,
        );
      }),
      baseUrl: 'http://localhost:8000',
    );
    AuthUser? updatedUser;
    var profileUser = const AuthUser(
      id: 'runner-1',
      email: 'runner@example.com',
      firstName: 'Alex',
      lastName: 'Runner',
      maxHr: 180,
      age: 35,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => ProfileScreen(
            user: profileUser,
            authService: service,
            onUserUpdated: (user) {
              updatedUser = user;
              setState(() => profileUser = user);
            },
            languageCode: 'en',
            onLocaleChanged: (_) {},
            onThemeModeChanged: (_) {},
            onLogout: () async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Heart rate zones'), findsOneWidget);
    expect(find.text('Z5 Maximum'), findsOneWidget);
    expect(find.text('Range 171-190 bpm'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('profile-max-hr')), '190');
    await tester.enterText(find.byKey(const ValueKey('profile-age')), '36');
    await tester.tap(find.text('Save profile'));
    await tester.pumpAndSettle();

    final profileUpdate = requests.singleWhere(
      (request) => request.method == 'PATCH',
    );
    expect(profileUpdate.url.path, '/api/v1/profile');
    expect(jsonDecode(profileUpdate.body), {'max_hr': 190, 'age': 36});
    expect(updatedUser?.maxHr, 190);
    expect(updatedUser?.age, 36);
    await tester.pumpAndSettle();
    expect(find.text('190 BPM'), findsOneWidget);
    expect(find.text('Range 171-190 bpm'), findsOneWidget);
    expect(tester.takeException(), isNull);
    service.close();
  });
}
