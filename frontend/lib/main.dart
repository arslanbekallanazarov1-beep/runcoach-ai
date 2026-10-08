import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'models/auth_user.dart';
import 'screens/auth_screen.dart';
import 'screens/gear_tracker_screen.dart';
import 'screens/analyze_run_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/training_plan_screen.dart';
import 'screens/workout_history_screen.dart';
import 'screens/weather_screen.dart';
import 'services/auth_service.dart';
import 'services/coach_speech_service.dart';
import 'services/gear_tracker_service.dart';
import 'services/run_analysis_service.dart';
import 'services/workout_history_service.dart';
import 'theme/app_theme.dart';
import 'l10n/app_strings.dart';

void main() {
  runApp(const RunCoachApp());
}

class RunCoachApp extends StatefulWidget {
  const RunCoachApp({
    super.key,
    this.service,
    this.gearTracker,
    this.workoutHistory,
    this.authService,
    this.initialUser,
    this.speechService,
  });

  final RunAnalysisService? service;
  final GearTrackerService? gearTracker;
  final WorkoutHistoryService? workoutHistory;
  final AuthService? authService;
  final AuthUser? initialUser;
  final CoachSpeechService? speechService;

  @override
  State<RunCoachApp> createState() => _RunCoachAppState();
}

class _RunCoachAppState extends State<RunCoachApp> {
  ThemeMode _themeMode = ThemeMode.system;
  Locale _locale = const Locale('en');
  late final GearTrackerService _gearTracker;
  late final WorkoutHistoryService _workoutHistory;
  late final AuthService _authService;
  late final CoachSpeechService _speechService;
  AuthUser? _user;
  bool _isRestoringSession = true;
  bool _sessionRestoreFailed = false;

  @override
  void initState() {
    super.initState();
    _gearTracker = widget.gearTracker ?? GearTrackerService();
    _workoutHistory = widget.workoutHistory ?? WorkoutHistoryService();
    _authService = widget.authService ?? AuthService();
    _speechService = widget.speechService ?? FlutterCoachSpeechService();
    _user = widget.initialUser;
    _isRestoringSession = widget.initialUser == null;
    unawaited(_gearTracker.load());
    unawaited(_workoutHistory.load());
    if (_isRestoringSession) unawaited(_restoreSession());
  }

  @override
  void dispose() {
    _gearTracker.dispose();
    _workoutHistory.dispose();
    _authService.close();
    super.dispose();
  }

  Future<void> _restoreSession() async {
    try {
      final user = await _authService.restoreSession();
      if (mounted) {
        setState(() {
          _user = user;
          _isRestoringSession = false;
          _sessionRestoreFailed = false;
        });
      }
    } on Exception {
      if (mounted) {
        setState(() {
          _isRestoringSession = false;
          _sessionRestoreFailed = true;
        });
      }
    }
  }

  Future<void> _discardBrokenSession() async {
    try {
      await _authService.logout();
      if (mounted) {
        setState(() {
          _sessionRestoreFailed = false;
          _user = null;
        });
      }
    } on AuthException {
      if (mounted) {
        setState(() => _sessionRestoreFailed = true);
      }
    }
  }

  void _setUser(AuthUser? user) {
    setState(() {
      _user = user;
      _sessionRestoreFailed = false;
    });
  }

  void _setDarkMode(bool useDarkMode) {
    setState(() {
      _themeMode = useDarkMode ? ThemeMode.dark : ThemeMode.light;
    });
  }

  void _setLocale(Locale locale) {
    setState(() => _locale = locale);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RunCoach AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _themeMode,
      locale: _locale,
      supportedLocales: const [Locale('en'), Locale('ru')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: _isRestoringSession
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _user == null
              ? _sessionRestoreFailed
                  ? _SessionRestoreError(onContinue: _discardBrokenSession)
                  : AuthScreen(
                      service: _authService,
                      languageCode: _locale.languageCode,
                      onLocaleChanged: _setLocale,
                      onAuthenticated: _setUser,
                    )
              : _RunCoachHome(
                  service: widget.service,
                  gearTracker: _gearTracker,
                  workoutHistory: _workoutHistory,
                  authService: _authService,
                  speechService: _speechService,
                  user: _user!,
                  onUserUpdated: _setUser,
                  languageCode: _locale.languageCode,
                  onThemeModeChanged: _setDarkMode,
                  onLocaleChanged: _setLocale,
                  onLogout: () => _setUser(null),
                ),
    );
  }
}

class _SessionRestoreError extends StatelessWidget {
  const _SessionRestoreError({required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(strings.authSessionLoadFailed),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: onContinue,
                child: Text(strings.authContinueToLogin),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RunCoachHome extends StatefulWidget {
  const _RunCoachHome({
    required this.languageCode,
    required this.onThemeModeChanged,
    required this.onLocaleChanged,
    required this.gearTracker,
    required this.workoutHistory,
    required this.authService,
    required this.speechService,
    required this.user,
    required this.onUserUpdated,
    required this.onLogout,
    this.service,
  });

  final String languageCode;
  final ValueChanged<bool> onThemeModeChanged;
  final ValueChanged<Locale> onLocaleChanged;
  final RunAnalysisService? service;
  final GearTrackerService gearTracker;
  final WorkoutHistoryService workoutHistory;
  final AuthService authService;
  final CoachSpeechService speechService;
  final AuthUser user;
  final ValueChanged<AuthUser> onUserUpdated;
  final VoidCallback onLogout;

  @override
  State<_RunCoachHome> createState() => _RunCoachHomeState();
}

class _RunCoachHomeState extends State<_RunCoachHome> {
  int _selectedIndex = 0;
  late final RunAnalysisService _historyRunService;
  late final bool _ownsHistoryRunService;

  @override
  void initState() {
    super.initState();
    _ownsHistoryRunService = widget.service == null;
    _historyRunService = widget.service ??
        RunAnalysisService(
          tokenProvider: () async => widget.authService.accessToken,
        );
    _configureRemoteHistory();
    unawaited(widget.workoutHistory.load());
  }

  @override
  void didUpdateWidget(covariant _RunCoachHome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.languageCode != widget.languageCode) {
      _configureRemoteHistory();
      unawaited(widget.workoutHistory.load());
    }
  }

  @override
  void dispose() {
    if (_ownsHistoryRunService) _historyRunService.close();
    super.dispose();
  }

  void _configureRemoteHistory() {
    widget.workoutHistory.configureRemote(
      historyApi: _historyRunService,
      language: widget.languageCode,
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          AnalyzeRunScreen(
            service: widget.service,
            tokenProvider: () async => widget.authService.accessToken,
            gearTracker: widget.gearTracker,
            speechService: widget.speechService,
            languageCode: widget.languageCode,
            onThemeModeChanged: widget.onThemeModeChanged,
            onLocaleChanged: widget.onLocaleChanged,
          ),
          TrainingPlanScreen(
            languageCode: widget.languageCode,
            onLocaleChanged: widget.onLocaleChanged,
            onThemeModeChanged: widget.onThemeModeChanged,
          ),
          GearTrackerScreen(gearTracker: widget.gearTracker),
          WeatherScreen(
            languageCode: widget.languageCode,
            onLocaleChanged: widget.onLocaleChanged,
            onThemeModeChanged: widget.onThemeModeChanged,
            isActive: _selectedIndex == 3,
          ),
          WorkoutHistoryScreen(
            languageCode: widget.languageCode,
            onLocaleChanged: widget.onLocaleChanged,
            onThemeModeChanged: widget.onThemeModeChanged,
            service: widget.workoutHistory,
          ),
          ProfileScreen(
            user: widget.user,
            authService: widget.authService,
            onUserUpdated: widget.onUserUpdated,
            languageCode: widget.languageCode,
            onLocaleChanged: widget.onLocaleChanged,
            onThemeModeChanged: widget.onThemeModeChanged,
            onLogout: () => _showLogoutConfirmation(context),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: NavigationBar(
                selectedIndex: _selectedIndex,
                onDestinationSelected: (index) {
                  setState(() => _selectedIndex = index);
                },
                destinations: [
                  NavigationDestination(
                    key: const ValueKey('tab-training'),
                    icon: const Icon(Icons.directions_run_rounded),
                    label: strings.trainingNav,
                  ),
                  NavigationDestination(
                    key: const ValueKey('tab-plan'),
                    icon: const Icon(Icons.calendar_month_rounded),
                    label: strings.planNav,
                  ),
                  NavigationDestination(
                    key: const ValueKey('tab-shoes'),
                    icon: const Icon(Icons.directions_run_rounded),
                    label: strings.shoesNav,
                  ),
                  NavigationDestination(
                    key: const ValueKey('tab-weather'),
                    icon: const Icon(Icons.cloud_outlined),
                    label: strings.weatherNav,
                  ),
                  NavigationDestination(
                    key: const ValueKey('tab-history'),
                    icon: const Icon(Icons.history_rounded),
                    label: strings.recentRuns,
                  ),
                  NavigationDestination(
                    key: const ValueKey('tab-profile'),
                    icon: const Icon(Icons.people_outlined),
                    label: strings.profile,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLogoutConfirmation(BuildContext context) async {
    final strings = AppStrings.of(context);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(strings.authLogout),
          content: Text(strings.authLogoutConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(strings.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(strings.authLogout),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      await _performLogout();
    }
  }

  Future<void> _performLogout() async {
    try {
      await widget.authService.logout();
      widget.onLogout();
    } on AuthException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.of(context).authLogoutFailed)),
        );
      }
    }
  }
}
