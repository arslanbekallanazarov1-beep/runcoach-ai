import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/weather_report.dart';
import '../services/coach_speech_service.dart';
import '../services/morning_briefing_service.dart';
import '../services/weather_location_service.dart';
import '../services/weather_service.dart';
import '../widgets/app_surface_card.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({
    required this.languageCode,
    required this.onLocaleChanged,
    required this.onThemeModeChanged,
    super.key,
    this.isActive = true,
    this.service,
    this.locationProvider,
    this.notifier,
    this.speechService,
  });

  final String languageCode;
  final bool isActive;
  final ValueChanged<Locale> onLocaleChanged;
  final ValueChanged<bool> onThemeModeChanged;
  final WeatherService? service;
  final WeatherLocationProvider? locationProvider;
  final MorningBriefingNotifier? notifier;
  final CoachSpeechService? speechService;

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  static const _deviceLocationId = 'device';
  static const _cities = <String, WeatherCoordinates>{
    'almaty': WeatherCoordinates(latitude: 43.2383, longitude: 76.9455),
    'astana': WeatherCoordinates(latitude: 51.1694, longitude: 71.4491),
    'shymkent': WeatherCoordinates(latitude: 42.3417, longitude: 69.5901),
    'karaganda': WeatherCoordinates(latitude: 49.8047, longitude: 73.1094),
    'aktau': WeatherCoordinates(latitude: 43.6532, longitude: 51.1975),
  };

  final _todayPlanController = TextEditingController();
  late final WeatherService _service;
  late final WeatherLocationProvider _locationProvider;
  late final MorningBriefingNotifier _notifier;
  late final CoachSpeechService _speechService;
  WeatherReport? _report;
  WeatherCoordinates? _deviceCoordinates;
  String _selectedLocationId = 'almaty';
  bool _isLoading = false;
  bool _isLocating = false;
  bool _hasAttemptedLocation = false;
  bool _locationUnavailable = false;
  bool _isSpeaking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? WeatherService();
    _locationProvider =
        widget.locationProvider ?? GeolocatorWeatherLocationProvider();
    _notifier = widget.notifier ?? LocalMorningBriefingNotifier();
    _speechService = widget.speechService ?? FlutterCoachSpeechService();
    if (widget.isActive) {
      unawaited(_locateDevice(fetchWeatherWhenFound: true));
    }
  }

  @override
  void didUpdateWidget(covariant WeatherScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive && !_hasAttemptedLocation) {
      unawaited(_locateDevice(fetchWeatherWhenFound: true));
    }
    if (oldWidget.languageCode != widget.languageCode &&
        _todayPlanController.text.isEmpty) {
      _todayPlanController.text = AppStrings.of(context).defaultTodayPlan;
    }
  }

  @override
  void dispose() {
    _todayPlanController.dispose();
    _service.close();
    super.dispose();
  }

  Future<void> _loadWeather() async {
    final coordinates = _coordinatesForSelection;
    if (coordinates == null) {
      await _locateDevice(fetchWeatherWhenFound: true);
      return;
    }

    await _fetchWeather(coordinates);
  }

  WeatherCoordinates? get _coordinatesForSelection =>
      _selectedLocationId == _deviceLocationId
          ? _deviceCoordinates
          : _cities[_selectedLocationId];

  Future<void> _locateDevice({required bool fetchWeatherWhenFound}) async {
    if (_isLocating) return;
    setState(() {
      _isLocating = true;
      _error = null;
    });
    try {
      final coordinates = await _locationProvider.getCurrentLocation();
      if (!mounted) return;
      if (coordinates == null) {
        setState(() {
          _selectedLocationId = 'almaty';
          _deviceCoordinates = null;
          _locationUnavailable = true;
        });
        return;
      }
      setState(() {
        _deviceCoordinates = coordinates;
        _selectedLocationId = _deviceLocationId;
        _locationUnavailable = false;
      });
      if (fetchWeatherWhenFound) await _fetchWeather(coordinates);
    } on Exception {
      if (mounted) {
        setState(() {
          _selectedLocationId = 'almaty';
          _deviceCoordinates = null;
          _locationUnavailable = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLocating = false;
          _hasAttemptedLocation = true;
        });
      }
    }
  }

  void _selectLocation(String? locationId) {
    if (locationId == null || locationId == _selectedLocationId) return;
    if (locationId == _deviceLocationId) {
      _locateDevice(fetchWeatherWhenFound: true);
      return;
    }
    setState(() {
      _selectedLocationId = locationId;
      _report = null;
      _error = null;
      _locationUnavailable = false;
    });
  }

  Future<void> _fetchWeather(WeatherCoordinates coordinates) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final report = await _service.fetchWeather(
        latitude: coordinates.latitude,
        longitude: coordinates.longitude,
        language: widget.languageCode,
      );
      if (mounted) setState(() => _report = report);
    } on WeatherServiceException {
      if (mounted) {
        setState(() => _error = AppStrings.of(context).weatherLoadFailed);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _temperature(double value, AppStrings strings) =>
      strings.temperatureC(value);

  String _clothingText(WeatherReport report) =>
      report.clothingRecommendation.replaceFirst(RegExp(r'[.!?]+$'), '');

  String _cityName(String id, AppStrings strings) => switch (id) {
        'almaty' => strings.cityAlmaty,
        'astana' => strings.cityAstana,
        'shymkent' => strings.cityShymkent,
        'karaganda' => strings.cityKaraganda,
        'aktau' => strings.cityAktau,
        _ => id,
      };

  String _briefing(WeatherReport report, AppStrings strings) {
    return strings.morningBriefing(
      temperature: _temperature(report.temperatureC, strings),
      description: report.description,
      clothing: _clothingText(report),
      plan: _todayPlanController.text.trim().isEmpty
          ? strings.defaultTodayPlan
          : _todayPlanController.text.trim(),
    );
  }

  Future<void> _sendBriefing() async {
    final report = _report;
    if (report == null) return;
    final strings = AppStrings.of(context);
    try {
      await _notifier.send(
        message: _briefing(report, strings),
        languageCode: widget.languageCode,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.notificationSent)),
        );
      }
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.notificationUnavailable)),
        );
      }
    }
  }

  Future<void> _speakWeather() async {
    final report = _report;
    if (report == null) return;
    final strings = AppStrings.of(context);
    if (_isSpeaking) {
      await _speechService.stop();
      if (mounted) setState(() => _isSpeaking = false);
      return;
    }
    setState(() => _isSpeaking = true);
    try {
      await _speechService.speak(
        text: strings.audioWeatherSummary(
          temperature: _temperature(report.temperatureC, strings),
          description: report.description,
          clothing: report.clothingRecommendation,
          pace: strings.comfortablePace,
          plan: _todayPlanController.text.trim().isEmpty
              ? strings.defaultTodayPlan
              : _todayPlanController.text.trim(),
        ),
        languageCode: widget.languageCode,
      );
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.speechUnavailable)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSpeaking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final report = _report;
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _WeatherHeader(
                    onLocaleChanged: widget.onLocaleChanged,
                    onThemeModeChanged: widget.onThemeModeChanged,
                  ),
                  const SizedBox(height: 18),
                  Text(strings.weatherIntro),
                  const SizedBox(height: 18),
                  AppSurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<String>(
                          key: const ValueKey('weather-location-selector'),
                          initialValue: _selectedLocationId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: strings.weatherLocation,
                            prefixIcon: const Icon(Icons.location_on_outlined),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: _deviceLocationId,
                              child: Text(strings.currentLocation),
                            ),
                            for (final cityId in _cities.keys)
                              DropdownMenuItem(
                                value: cityId,
                                child: Text(_cityName(cityId, strings)),
                              ),
                          ],
                          onChanged: _isLoading || _isLocating
                              ? null
                              : _selectLocation,
                        ),
                        if (_locationUnavailable) ...[
                          const SizedBox(height: 6),
                          Text(
                            strings.locationFallback,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        const SizedBox(height: 14),
                        TextField(
                          controller: _todayPlanController,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            labelText: strings.todayPlan,
                            hintText: strings.todayPlanHint,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed:
                              _isLoading || _isLocating ? null : _loadWeather,
                          icon: _isLoading
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.cloud_outlined),
                          label: Text(
                            _isLocating
                                ? strings.locating
                                : _isLoading
                                    ? strings.loadingWeather
                                    : strings.loadWeather,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _error!,
                      style: TextStyle(color: colorScheme.error),
                    ),
                  ],
                  if (report != null) ...[
                    const SizedBox(height: 18),
                    AppSurfaceCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            strings.currentConditions,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${_temperature(report.temperatureC, strings)} · '
                            '${report.description}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 16,
                            runSpacing: 10,
                            children: [
                              _WeatherMetric(
                                label: strings.feelsLike,
                                value: _temperature(report.feelsLikeC, strings),
                              ),
                              _WeatherMetric(
                                label: strings.windSpeed,
                                value: '${report.windSpeedKmh.round()} km/h',
                              ),
                              _WeatherMetric(
                                label: strings.humidity,
                                value: '${report.humidityPercent}%',
                              ),
                            ],
                          ),
                          const Divider(height: 26),
                          Text(
                            strings.todayForecast,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            '${report.forecastDescription} · '
                            '${_temperature(report.forecastMinimumC, strings)}'
                            ' – ${_temperature(report.forecastMaximumC, strings)}',
                          ),
                          Text(
                            '${strings.precipitationChance}: '
                            '${report.precipitationProbability}%',
                          ),
                          const Divider(height: 26),
                          Text(
                            strings.clothingAdvice,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(report.clothingRecommendation),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: _sendBriefing,
                            icon:
                                const Icon(Icons.notifications_active_outlined),
                            label: Text(strings.sendMorningBriefing),
                          ),
                          TextButton.icon(
                            onPressed: _speakWeather,
                            icon: Icon(
                              _isSpeaking
                                  ? Icons.stop_rounded
                                  : Icons.volume_up,
                            ),
                            label: Text(
                              _isSpeaking
                                  ? strings.stopAudio
                                  : strings.audioCoach,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeatherHeader extends StatelessWidget {
  const _WeatherHeader({
    required this.onLocaleChanged,
    required this.onThemeModeChanged,
  });

  final ValueChanged<Locale> onLocaleChanged;
  final ValueChanged<bool> onThemeModeChanged;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context);
    final isDarkMode = colorScheme.brightness == Brightness.dark;
    return Row(
      children: [
        Expanded(
          child: Text(
            strings.weatherTitle,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        PopupMenuButton<Locale>(
          tooltip: strings.language,
          onSelected: onLocaleChanged,
          itemBuilder: (context) => [
            const PopupMenuItem(value: Locale('en'), child: Text('English')),
            const PopupMenuItem(value: Locale('ru'), child: Text('Русский')),
          ],
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              locale.languageCode.toUpperCase(),
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: isDarkMode ? strings.switchToLight : strings.switchToDark,
          onPressed: () => onThemeModeChanged(!isDarkMode),
          icon: Icon(
            isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          ),
        ),
      ],
    );
  }
}

class _WeatherMetric extends StatelessWidget {
  const _WeatherMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        Text(value, style: Theme.of(context).textTheme.titleSmall),
      ],
    );
  }
}
