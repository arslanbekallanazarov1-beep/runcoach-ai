# RunCoach AI local integration test guide

This guide runs the FastAPI backend and Flutter app together on an Android
emulator or iOS simulator, then verifies that a submitted run is displayed in
the app.

## 1. Prepare and start the backend

From the repository root, install the backend dependencies if needed:

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

Set `OPENROUTER_API_KEY` in the ignored `backend/.env` file to enable live AI
feedback. Never commit that file. If the key is absent or OpenRouter cannot be
reached, the backend still returns its deterministic fallback feedback.
Set a stable, strong `SECRET_KEY` in the same ignored file so account tokens
remain valid between backend restarts.

Start FastAPI bound to all local interfaces so emulators can reach it:

```bash
PYTHONPATH=src uvicorn runcoach_ai.main:app --host 0.0.0.0 --port 8000
```

Keep this terminal open. In another terminal, check that the service responds:

```bash
curl http://127.0.0.1:8000/
```

Expected response:

```json
{"message":"RunCoach AI API"}
```

The backend creates the local SQLite database and tables on startup. No
separate PostgreSQL service is required.

## 2. Register and obtain an access token

Create an account (or log in with an existing account):

```bash
curl --fail-with-body \
  --header "Content-Type: application/json" \
  --request POST \
  --data '{"email":"runner@example.com","password":"secure-password-123","first_name":"Alex","last_name":"Runner"}' \
  http://127.0.0.1:8000/api/v1/auth/register
```

The response contains a 30-day `token`. Copy the value for the following
authenticated run requests. Do not store a real token in source control.

## 3. Check the analysis endpoint with cURL

Run this from the development computer:

```bash
curl --fail-with-body \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer <access-token>" \
  --request POST \
  --data '{"distance_km":5.0,"time_seconds":1860,"avg_hr":172,"rpe":7,"sleep_hours":7.5,"resting_hr":58}' \
  http://127.0.0.1:8000/api/v1/analyze_run
```

The response should include `status: "success"`, pace `6:12`, training load
`217.0`, intensity zone `Hard/Anaerobic`, a deterministic recommendation, and
coach feedback. This request is persisted and will appear in recent runs.
AI wording can vary; without a configured provider key, the feedback is the
backend's deterministic fallback.

Fetch saved runs from the development computer with:

```bash
curl --header "Authorization: Bearer <access-token>" \
  "http://127.0.0.1:8000/api/v1/runs?limit=20"
```

## 4. Configure emulator/simulator networking

Flutter Web defaults to `http://localhost:8000`. On mobile, the default is the
development machine's LAN address (`http://192.168.1.3:8000`), so a real phone
is not pointed at `localhost`/`127.0.0.1`/`10.0.2.2` (none of which work from
a physical device). For the Android emulator's host-only network, override with:

```bash
flutter run -d <device> --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

To connect to a specific LAN address (real device), use:

```bash
flutter run -d <device> --dart-define=API_BASE_URL=http://<host-lan-ip>:8000
```

The backend must listen on `0.0.0.0:8000`; verify the development machine's LAN
IP and firewall allow inbound connections on port 8000. The app's main Android
manifest permits cleartext HTTP for this local setup. Local HTTP is intended
only for development; use HTTPS for deployed environments.

The Flutter run form accepts duration in minutes (for example, `31` minutes
is sent to the API as `1860` seconds). API requests and stored history continue
to use the existing `time_seconds` contract.

## 5. Generate platform hosts if necessary

The repository's `frontend/` includes Flutter source, tests, and `pubspec.yaml`.
If Android/iOS native host folders are not present, generate them with Flutter
and keep the existing `lib/`, `test/`, and dependency configuration:

```bash
flutter create --platforms=android,ios --project-name runcoach_ai frontend
```

Then fetch packages:

```bash
cd frontend
flutter pub get
```

## 6. Run the app

List available targets and launch the desired emulator/simulator:

```bash
flutter devices
flutter run
```

Or select an explicit target:

```bash
flutter run -d <emulator-or-simulator-id>
```

Enter a run and tap **Analyze Run**. The screen displays the pace, intensity
zone, training load, deterministic next-workout recommendation, and coach
feedback returned from FastAPI.

## 7. Run automated Flutter tests

From `frontend/`:

```bash
flutter test
```

The form submission widget test uses a mocked HTTP response. It fills distance
`5.0 km`, time `1860 seconds`, average heart rate `172 bpm`, and RPE `7`, taps
**Analyze Run**, verifies the exact request, and asserts the UI displays pace
`6:12 /km`, training load `217.00`, and the returned coach feedback. It does
not require the backend or OpenRouter to be running.

The test is implemented in
[`test/analyze_run_screen_test.dart`](./test/analyze_run_screen_test.dart):

```dart
testWidgets('submits run details and displays the analysis response', (
  tester,
) async {
  late http.Request submittedRequest;
  final client = MockClient((request) async {
    submittedRequest = request;
    return http.Response(
      jsonEncode({
        'status': 'success',
        'metrics': {
          'pace': '6:12',
          'training_load': 217,
          'intensity_zone': 'Hard/Anaerobic',
        },
        'recommendation': 'Recovery Run or Rest Day',
        'coach_feedback':
            'Strong effort today. Make your next session a gentle recovery run.',
      }),
      200,
      headers: {'content-type': 'application/json'},
    );
  });

  await tester.pumpWidget(
    MaterialApp(
      home: AnalyzeRunScreen(
        service: RunAnalysisService(client: client, baseUrl: 'http://localhost:8000'),
      ),
    ),
  );

  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), '5.0');
  await tester.enterText(fields.at(1), '1860');
  await tester.enterText(fields.at(2), '172');
  await tester.tap(find.byType(DropdownButtonFormField<int>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('7').last);
  await tester.pumpAndSettle();

  await tester.ensureVisible(find.text('Analyze Run'));
  await tester.tap(find.text('Analyze Run'));
  await tester.pumpAndSettle();

  expect(submittedRequest.method, 'POST');
  expect(submittedRequest.url.path, '/api/v1/analyze_run');
  expect(jsonDecode(submittedRequest.body), {
    'distance_km': 5.0,
    'time_seconds': 1860,
    'avg_hr': 172,
    'rpe': 7,
  });
  expect(find.text('6:12 /km'), findsOneWidget);
  expect(find.text('217.00'), findsOneWidget);
  expect(
    find.text('Strong effort today. Make your next session a gentle recovery run.'),
    findsOneWidget,
  );
});
```

The test file imports `dart:convert`, `package:flutter/material.dart`,
`package:flutter_test/flutter_test.dart`, `package:http/http.dart`, and
`package:http/testing.dart`, plus the app screen and API service.
