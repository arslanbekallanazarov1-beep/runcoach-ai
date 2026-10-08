import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:runcoach_ai/models/auth_user.dart';
import 'package:runcoach_ai/screens/auth_screen.dart';
import 'package:runcoach_ai/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('switches to registration and completes a localized sign-up', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    late http.Request submittedRequest;
    AuthUser? authenticatedUser;
    final service = AuthService(
      client: MockClient((request) async {
        submittedRequest = request;
        return http.Response(
          jsonEncode({
            'user': {
              'id': 'runner-1',
              'email': 'runner@example.com',
              'first_name': 'Alex',
              'last_name': 'Runner',
            },
            'token': 'signed.jwt.token',
            'token_type': 'bearer',
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
        home: AuthScreen(
          service: service,
          languageCode: 'en',
          onLocaleChanged: (_) {},
          onAuthenticated: (user) => authenticatedUser = user,
        ),
      ),
    );

    await tester.tap(find.text('New here? Create an account'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Alex');
    await tester.enterText(fields.at(1), 'Runner');
    await tester.enterText(fields.at(2), 'runner@example.com');
    await tester.enterText(fields.at(3), 'secure-password');
    await tester.tap(find.text('Sign up'));
    await tester.pumpAndSettle();

    expect(submittedRequest.url.path, '/api/v1/auth/register');
    expect(jsonDecode(submittedRequest.body)['last_name'], 'Runner');
    expect(authenticatedUser?.id, 'runner-1');
    expect(service.accessToken, 'signed.jwt.token');
    service.close();
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
