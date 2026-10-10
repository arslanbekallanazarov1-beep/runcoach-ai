# RunCoach AI Flutter app

## Prerequisites

- Flutter SDK (stable channel)
- Android Studio with an Android emulator, or Xcode with an iOS simulator
- The FastAPI backend running on port 8000

## Setup

From this directory:

```bash
flutter pub get
flutter test
```

### API base URL

The app resolves the backend address from the highest-priority source that is
set at build/run time:

1. `--dart-define=RUNCOACH_API_BASE_URL=http://<host>:8000`
2. `--dart-define=API_BASE_URL=http://<host>:8000`
3. Platform default: `http://localhost:8000` on Web, `http://192.168.1.3:8000`
   on mobile.

For a deployed backend, use its HTTPS origin (the same shared configuration is
used by authentication and the other API services):

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://your-cloud-url.com
```

The mobile default is the development machine's LAN address, so a real phone
does not point at `localhost`/`127.0.0.1`/`10.0.2.2` (none of which are
reachable from a physical device). Override it for a specific device or
emulator:

```bash
# Real phone on the same LAN as the dev machine
flutter run -d <device> --dart-define=API_BASE_URL=http://192.168.1.3:8000

# Android emulator (host-only network)
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8000

# Release APK
flutter build apk --dart-define=API_BASE_URL=http://192.168.1.3:8000
```

Ensure the backend binds to `0.0.0.0:8000` and the device can reach its
address.

Run duration is entered in minutes and converted to integer seconds for the
existing API contract. Durations in analysis, history, and share cards display
as `mm:ss` or `h:mm:ss`.

Sign up or log in to store a 30-day JWT session in cross-platform preferences.
Run analysis, history, and profile calls include the bearer token and are
scoped to that account. The Profile tab lets runners edit age and maximum heart
rate; the backend calculates and displays Z1–Z5 training ranges from max HR.

The app calls `POST /api/v1/analyze_run` with the run details and displays the
deterministic metrics, recovery-adjusted recommendation, and coach feedback
returned by the backend. Sleep below five hours or a resting heart rate of 100
bpm or higher recommends recovery/rest. Sleep and resting heart rate are
optional inputs in the run form. It also loads `GET /api/v1/runs` on startup and refreshes recent
workouts after each successful analysis. History rows include run date,
distance, pace, duration, heart rate, RPE, training load, and saved coach
feedback. Analysis and training-plan requests include the active `lang`
(`en` or `ru`) so backend AI output uses the selected language.

The Plans tab uses the authenticated training-plan endpoints to generate and
save a structured week-by-week schedule, reload the active plan, and persist
workout checkbox changes. Plan generation allows up to 90 seconds for the AI
provider to respond. The Shoes tab stores shoe names and mileage locally
using cross-platform preferences; select a pair in the run form and its
mileage increases after successful analysis. A deterministic wear alert
appears once a pair exceeds 700 km. The dashboard uses the Riegel formula
with the most recent run to estimate 5K, 10K, half-marathon, and marathon
times. Tap the speaker control on a coaching result to read the pace and
recommendation aloud; Flutter TTS uses the browser speech engine on Web and
native text-to-speech on supported mobile platforms.

The Weather tab requests device location permission and loads current
conditions and today's forecast from the backend's Open-Meteo integration.
When device location is unavailable or denied, choose a city from the built-in
city selector. Android location permissions are declared in the app manifest;
browser location requires a secure context and user permission. The screen
uses coordinates only to request weather and does not track or save routes.
It also displays localized AI/deterministic clothing tips. Its local notification
action sends the exact dynamic morning briefing after the user grants
permission. Web notifications require a secure browser context and user
permission; browsers do not support scheduled/repeating notifications. The
same screen can speak weather advice and comfortable pace guidance.

The Challenges tab contains local challenge and virtual pacemaker duel UI
prototypes only. They do not track activities, sync data, or run competitions.

The Android debug manifest enables Internet access and local cleartext HTTP
in debug builds; the main manifest also enables Internet access and cleartext
HTTP to support the configured LAN URL in release builds. Use HTTPS for
production deployments.

The custom Android launcher icon is generated from `icon.png`. This repository
does not currently contain an iOS Runner project, so iOS icon generation is
disabled until that platform host is added. Regenerate the Android icon with:

```bash
dart run flutter_launcher_icons
```

## App structure

- `lib/theme/` contains the light/dark Material 3 theme definitions.
- `lib/screens/` contains the analysis dashboard, training-plan generator, and
  shoe-management, authentication, weather, and challenge screens.
- `lib/widgets/` contains shared presentation components and the race predictor.
- `lib/models/` and `lib/services/` contain API models, account/session
  management, local gear/notification services, and backend integration.

The dashboard theme button switches between light and dark mode; the system
theme is used until the user makes a choice during the current app session.
The header language menu switches the core interface between English and
Russian for the current app session.
Add future workflows as focused screens and reusable widgets while keeping API
access in services and response parsing in models.

## Run card sharing

Successful analyses and saved history entries can be turned into a branded
share card. Workout duration is displayed in `mm:ss` (or `h:mm:ss`) format.
The route illustration is decorative (the app does not record GPS), and
calories are marked as an estimate because the app does not collect runner
weight. Mobile platforms use the native share sheet; Flutter Web downloads a
PNG directly in the browser.

Run the web app locally with:

```bash
flutter run -d chrome
```

For backend setup, emulator networking, cURL verification, and the form
submission widget test, see [the local integration test guide](./integration_test_guide.md).

## Platform configuration

This repository contains the Flutter app source, tests, package configuration,
Android app configuration (`com.runcoach.ai`), the `RunCoach AI` launcher name,
and the Internet permission are set in the Android app Gradle file and main
manifest. The `pubspec.yaml` name `runcoach_ai` is the valid Dart package name,
not the Android application ID.

Native Android/iOS root host files must be generated with the Flutter SDK
before the app can be launched. Preserve this directory's `lib/`, `test/`,
`pubspec.yaml`, and Android app configuration when generating those hosts.
For iOS, configure local HTTP access in the development `Info.plist` if App
Transport Security blocks the simulator request. Use HTTPS for deployed
backends.
