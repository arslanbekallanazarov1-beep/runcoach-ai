import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';
import '../models/run_analysis.dart';
import '../models/run_history_item.dart';
import '../models/shareable_run.dart';
import '../services/coach_speech_service.dart';
import '../services/gear_tracker_service.dart';
import '../services/run_analysis_service.dart';
import '../utils/duration_format.dart';
import '../widgets/app_surface_card.dart';
import '../widgets/race_predictor_card.dart';
import '../widgets/shareable_run_card.dart';

class AnalyzeRunScreen extends StatefulWidget {
  const AnalyzeRunScreen({
    super.key,
    this.service,
    this.onThemeModeChanged,
    this.onLocaleChanged,
    this.gearTracker,
    this.speechService,
    this.tokenProvider,
    this.languageCode = 'en',
  });

  final RunAnalysisService? service;
  final ValueChanged<bool>? onThemeModeChanged;
  final ValueChanged<Locale>? onLocaleChanged;
  final GearTrackerService? gearTracker;
  final CoachSpeechService? speechService;
  final Future<String?> Function()? tokenProvider;
  final String languageCode;

  @override
  State<AnalyzeRunScreen> createState() => _AnalyzeRunScreenState();
}

class _AnalyzeRunScreenState extends State<AnalyzeRunScreen> {
  final _formKey = GlobalKey<FormState>();
  final _distanceController = TextEditingController();
  final _timeController = TextEditingController();
  final _heartRateController = TextEditingController();
  final _sleepController = TextEditingController();
  final _restingHeartRateController = TextEditingController();
  late final RunAnalysisService _service;
  late final CoachSpeechService _speechService;

  int _rpe = 5;
  bool _isLoading = false;
  bool _isSpeaking = false;
  String? _gearErrorMessage;
  RunAnalysisException? _analysisError;
  RunAnalysis? _analysis;
  ShareableRun? _shareableRun;
  List<RunHistoryItem> _recentRuns = const [];
  bool _isLoadingHistory = true;
  RunAnalysisException? _historyError;
  final Set<String> _deletingRunIds = {};

  @override
  void initState() {
    super.initState();
    _service = widget.service ??
        RunAnalysisService(tokenProvider: widget.tokenProvider);
    _speechService = widget.speechService ?? FlutterCoachSpeechService();
    _loadRecentRuns();
  }

  @override
  void didUpdateWidget(covariant AnalyzeRunScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.languageCode != widget.languageCode) {
      _loadRecentRuns();
    }
  }

  @override
  void dispose() {
    _distanceController.dispose();
    _timeController.dispose();
    _heartRateController.dispose();
    _sleepController.dispose();
    _restingHeartRateController.dispose();
    _service.close();
    super.dispose();
  }

  Future<void> _analyzeRun() async {
    if (!_formKey.currentState!.validate()) return;
    final selectedShoeId = widget.gearTracker?.selectedShoeId;

    setState(() {
      _isLoading = true;
      _analysisError = null;
      _gearErrorMessage = null;
      _analysis = null;
      _shareableRun = null;
    });

    try {
      final distanceKm = double.parse(_distanceController.text.trim());
      final durationMinutes = double.parse(_timeController.text.trim());
      final timeSeconds = durationMinutesToSeconds(durationMinutes);
      final result = await _service.analyzeRun(
        distanceKm: distanceKm,
        timeSeconds: timeSeconds,
        averageHeartRate: int.parse(_heartRateController.text.trim()),
        rpe: _rpe,
        language: widget.languageCode,
        sleepHours: double.tryParse(_sleepController.text.trim()),
        restingHeartRate: int.tryParse(_restingHeartRateController.text.trim()),
      );
      if (!mounted) return;
      setState(() {
        _analysis = result;
        _shareableRun = ShareableRun(
          distanceKm: distanceKm,
          pace: result.pace,
          timeSeconds: timeSeconds,
          coachComment: result.coachFeedback,
          date: DateTime.now(),
        );
      });
      final gearTracker = widget.gearTracker;
      if (gearTracker != null && selectedShoeId != null) {
        try {
          await gearTracker.recordRunDistance(
            distanceKm,
            shoeId: selectedShoeId,
          );
        } on Exception {
          if (mounted) {
            setState(() =>
                _gearErrorMessage = AppStrings.of(context).gearStorageFailed);
          }
        }
      }
      await _loadRecentRuns();
    } on RunAnalysisException catch (error) {
      if (!mounted) return;
      setState(() => _analysisError = error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectShoe(String? shoeId) async {
    final gearTracker = widget.gearTracker;
    if (gearTracker == null) return;
    try {
      await gearTracker.selectShoe(shoeId);
    } on Exception {
      if (mounted) {
        setState(
          () => _gearErrorMessage = AppStrings.of(context).gearStorageFailed,
        );
      }
    }
  }

  Future<void> _toggleSpeech() async {
    final analysis = _analysis;
    if (analysis == null) return;
    if (_isSpeaking) {
      try {
        await _speechService.stop();
      } on Exception {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppStrings.of(context).speechUnavailable),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isSpeaking = false);
      }
      return;
    }
    setState(() => _isSpeaking = true);
    final strings = AppStrings.of(context);
    try {
      await _speechService.speak(
        text: strings.audioCoachSummary(
          analysis.pace,
          analysis.recommendation,
          analysis.coachFeedback,
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

  Future<void> _loadRecentRuns() async {
    setState(() {
      _isLoadingHistory = true;
      _historyError = null;
    });

    try {
      final runs =
          await _service.fetchRecentRuns(language: widget.languageCode);
      if (!mounted) return;
      setState(() => _recentRuns = runs);
    } on RunAnalysisException catch (error) {
      if (!mounted) return;
      setState(() => _historyError = error);
    } finally {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  String _localizedError(RunAnalysisException error) {
    final strings = AppStrings.of(context);
    final status = '${error.statusCode ?? ''}';
    return switch (error.code) {
      RunAnalysisError.connection => strings.runCoachServerUnavailable,
      RunAnalysisError.analyzeHttp =>
        strings.serverAnalyzeFailed.replaceAll('{status}', status),
      RunAnalysisError.historyConnection => strings.historyServerUnavailable,
      RunAnalysisError.historyHttp =>
        strings.serverHistoryFailed.replaceAll('{status}', status),
      RunAnalysisError.deleteConnection => strings.runDeleteFailed,
      RunAnalysisError.deleteHttp =>
        strings.serverRunDeleteFailed.replaceAll('{status}', status),
      RunAnalysisError.invalidAnalysisResponse =>
        strings.unexpectedAnalysisResponse,
      RunAnalysisError.invalidHistoryResponse =>
        strings.unexpectedHistoryResponse,
    };
  }

  Future<void> _confirmDeleteRun(RunHistoryItem run) async {
    final strings = AppStrings.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.deleteWorkout),
        content: Text(strings.deleteWorkoutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: Text(strings.deleteWorkout),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deletingRunIds.add(run.id));
    try {
      await _service.deleteRun(run.id);
      if (mounted) {
        setState(() {
          _recentRuns =
              _recentRuns.where((recentRun) => recentRun.id != run.id).toList();
        });
      }
    } on RunAnalysisException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_localizedError(error))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _deletingRunIds.remove(run.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _Header(
                    onThemeModeChanged: widget.onThemeModeChanged,
                    onLocaleChanged: widget.onLocaleChanged,
                  ),
                  const SizedBox(height: 24),
                  _buildRunForm(),
                  if (_analysisError != null) ...[
                    const SizedBox(height: 16),
                    _ErrorBanner(message: _localizedError(_analysisError!)),
                  ],
                  if (_gearErrorMessage != null) ...[
                    const SizedBox(height: 12),
                    _ErrorBanner(message: _gearErrorMessage!),
                  ],
                  if (_analysis != null) ...[
                    const SizedBox(height: 24),
                    _AnalysisResults(
                      analysis: _analysis!,
                      shareableRun: _shareableRun!,
                      isSpeaking: _isSpeaking,
                      onSpeak: _toggleSpeech,
                    ),
                  ],
                  if (_shareableRun != null || _recentRuns.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    RacePredictorCard(
                      distanceKm: _shareableRun?.distanceKm ??
                          _recentRuns.first.distanceKm,
                      timeSeconds: _shareableRun?.timeSeconds ??
                          _recentRuns.first.timeSeconds,
                    ),
                  ],
                  const SizedBox(height: 24),
                  _RecentRuns(
                    runs: _recentRuns,
                    isLoading: _isLoadingHistory,
                    errorMessage: _historyError == null
                        ? null
                        : _localizedError(_historyError!),
                    onRetry: _loadRecentRuns,
                    deletingRunIds: _deletingRunIds,
                    onDelete: _confirmDeleteRun,
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      strings.metricsDisclaimer,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRunForm() {
    final colorScheme = Theme.of(context).colorScheme;
    final strings = AppStrings.of(context);

    return AppSurfaceCard(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.runDetails,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 5),
            Text(
              strings.formIntro,
            ),
            const SizedBox(height: 22),
            _NumberField(
              controller: _distanceController,
              label: strings.distance,
              hint: 'e.g. 5.0',
              suffix: 'km',
              decimal: true,
              validator: (value) {
                final distance = double.tryParse(value?.trim() ?? '');
                if (distance == null || !distance.isFinite || distance <= 0) {
                  return strings.invalidDistance;
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            _NumberField(
              controller: _timeController,
              label: strings.duration,
              hint: 'e.g. 30',
              suffix: strings.minutes,
              decimal: true,
              validator: (value) {
                final minutes = double.tryParse(value?.trim() ?? '');
                if (minutes == null ||
                    !minutes.isFinite ||
                    durationMinutesToSeconds(minutes) <= 0) {
                  return strings.invalidDuration;
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            _NumberField(
              controller: _heartRateController,
              label: strings.averageHeartRate,
              hint: 'e.g. 145',
              suffix: 'bpm',
              validator: (value) {
                final heartRate = int.tryParse(value?.trim() ?? '');
                if (heartRate == null || heartRate <= 0) {
                  return strings.invalidHeartRate;
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            Material(
              type: MaterialType.transparency,
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                maintainState: true,
                title: Text(strings.recoveryMetrics),
                children: [
                  _NumberField(
                    controller: _sleepController,
                    label: strings.sleepHours,
                    hint: 'e.g. 7.5',
                    suffix: strings.hoursUnit,
                    decimal: true,
                    validator: (value) {
                      final sleep = value?.trim() ?? '';
                      if (sleep.isEmpty) return null;
                      final hours = double.tryParse(sleep);
                      return hours == null ||
                              !hours.isFinite ||
                              hours < 0 ||
                              hours > 24
                          ? strings.invalidSleepHours
                          : null;
                    },
                  ),
                  const SizedBox(height: 14),
                  _NumberField(
                    controller: _restingHeartRateController,
                    label: strings.restingHeartRate,
                    hint: 'e.g. 58',
                    suffix: 'bpm',
                    validator: (value) {
                      final restingHeartRate = value?.trim() ?? '';
                      if (restingHeartRate.isEmpty) return null;
                      final parsed = int.tryParse(restingHeartRate);
                      return parsed == null || parsed < 30 || parsed > 240
                          ? strings.invalidRestingHeartRate
                          : null;
                    },
                  ),
                  const SizedBox(height: 14),
                ],
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<int>(
              initialValue: _rpe,
              decoration: InputDecoration(
                labelText: strings.effort,
                helperText: strings.effortHelper,
                prefixIcon: const Icon(Icons.speed_rounded),
              ),
              items: List.generate(
                10,
                (index) => DropdownMenuItem(
                  value: index + 1,
                  child: Text('${index + 1}'),
                ),
              ),
              onChanged: _isLoading
                  ? null
                  : (value) {
                      if (value != null) setState(() => _rpe = value);
                    },
            ),
            if (widget.gearTracker != null) ...[
              const SizedBox(height: 14),
              _ShoeSelection(
                gearTracker: widget.gearTracker!,
                onSelected: _selectShoe,
              ),
            ],
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _analyzeRun,
                icon: _isLoading
                    ? SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.onPrimary,
                        ),
                      )
                    : const Icon(Icons.auto_awesome_rounded),
                label: Text(
                  _isLoading ? strings.analyzingRun : strings.analyzeRun,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentRuns extends StatelessWidget {
  const _RecentRuns({
    required this.runs,
    required this.isLoading,
    required this.errorMessage,
    required this.onRetry,
    required this.deletingRunIds,
    required this.onDelete,
  });

  final List<RunHistoryItem> runs;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onRetry;
  final Set<String> deletingRunIds;
  final ValueChanged<RunHistoryItem> onDelete;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings.recentRuns,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 12),
        if (isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          )
        else if (errorMessage != null)
          _HistoryMessage(
            message: errorMessage!,
            actionLabel: AppStrings.of(context).retry,
            onPressed: onRetry,
          )
        else if (runs.isEmpty)
          _HistoryMessage(
            message: strings.noRuns,
          )
        else
          ...runs.map((run) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _RunHistoryCard(
                  run: run,
                  isDeleting: deletingRunIds.contains(run.id),
                  onDelete: () => onDelete(run),
                ),
              )),
      ],
    );
  }
}

class _RunHistoryCard extends StatelessWidget {
  const _RunHistoryCard({
    required this.run,
    required this.isDeleting,
    required this.onDelete,
  });

  final RunHistoryItem run;
  final bool isDeleting;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final dateLabel = run.date.toLocal().toIso8601String().substring(0, 16);
    final colorScheme = Theme.of(context).colorScheme;
    final strings = AppStrings.of(context);

    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.directions_run_rounded,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  strings.runTitle(run.distanceKm),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              Text(
                run.pace,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              IconButton(
                tooltip: strings.shareRun,
                onPressed: () => _showShareCard(context),
                icon: const Icon(Icons.ios_share_rounded),
              ),
              IconButton(
                tooltip: strings.deleteWorkout,
                onPressed: isDeleting ? null : onDelete,
                icon: isDeleting
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        Icons.delete_outline_rounded,
                        color: colorScheme.error,
                      ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$dateLabel  ·  ${formatRunDuration(run.timeSeconds)}  ·  '
            '${run.averageHeartRate} bpm  ·  RPE ${run.rpe}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (run.sleepHours != null || run.restingHeartRate != null) ...[
            const SizedBox(height: 5),
            Text(
              [
                if (run.sleepHours != null)
                  '${strings.sleepHours}: '
                      '${run.sleepHours!.toStringAsFixed(1)} ${strings.hoursUnit}',
                if (run.restingHeartRate != null)
                  '${strings.restingHeartRate}: ${run.restingHeartRate} bpm',
              ].join('  ·  '),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (run.trainingLoad != null || run.intensityZone != null) ...[
            const SizedBox(height: 6),
            Text(
              [
                if (run.intensityZone != null) run.intensityZone!,
                if (run.trainingLoad != null)
                  '${strings.trainingLoad}: '
                      '${run.trainingLoad!.toStringAsFixed(2)}',
              ].join('  ·  '),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
          if (run.coachFeedback != null) ...[
            const SizedBox(height: 10),
            Text(
              run.coachFeedback!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.4,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showShareCard(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ShareableRunCard(
            run: ShareableRun(
              distanceKm: run.distanceKm,
              pace: run.pace,
              timeSeconds: run.timeSeconds,
              coachComment: run.coachFeedback ??
                  (AppStrings.of(context).isRussian
                      ? 'Каждая пробежка важна. Продолжайте двигаться к цели.'
                      : 'Every run counts. Keep showing up for yourself.'),
              date: run.date,
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryMessage extends StatelessWidget {
  const _HistoryMessage({
    required this.message,
    this.actionLabel,
    this.onPressed,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 8),
            TextButton(onPressed: onPressed, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({this.onThemeModeChanged, this.onLocaleChanged});

  final ValueChanged<bool>? onThemeModeChanged;
  final ValueChanged<Locale>? onLocaleChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDarkMode = colorScheme.brightness == Brightness.dark;
    final strings = AppStrings.of(context);
    final locale = Localizations.localeOf(context);

    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            Icons.directions_run_rounded,
            color: colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.appName,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              Text(
                strings.tagline,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        PopupMenuButton<Locale>(
          key: const ValueKey('language-toggle'),
          tooltip: strings.language,
          onSelected: onLocaleChanged,
          itemBuilder: (context) => [
            CheckedPopupMenuItem(
              value: const Locale('en'),
              checked: locale.languageCode == 'en',
              child: const Text('English'),
            ),
            CheckedPopupMenuItem(
              value: const Locale('ru'),
              checked: locale.languageCode == 'ru',
              child: const Text('Русский'),
            ),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              locale.languageCode.toUpperCase(),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ),
        IconButton(
          key: const ValueKey('theme-toggle'),
          tooltip: isDarkMode ? strings.switchToLight : strings.switchToDark,
          onPressed: onThemeModeChanged == null
              ? null
              : () => onThemeModeChanged!(!isDarkMode),
          icon: Icon(
            isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          ),
        ),
      ],
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.suffix,
    required this.validator,
    this.decimal = false,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final String suffix;
  final String? Function(String?) validator;
  final bool decimal;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          decimal ? RegExp(r'^\d*\.?\d*$') : RegExp(r'\d*'),
        ),
      ],
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: suffix,
        prefixIcon: const Icon(Icons.edit_note_rounded),
      ),
    );
  }
}

class _AnalysisResults extends StatelessWidget {
  const _AnalysisResults({
    required this.analysis,
    required this.shareableRun,
    required this.isSpeaking,
    required this.onSpeak,
  });

  final RunAnalysis analysis;
  final ShareableRun shareableRun;
  final bool isSpeaking;
  final VoidCallback onSpeak;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final strings = AppStrings.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings.runAnalysis,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 12),
        AppSurfaceCard(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _MetricTile(
                      icon: Icons.timer_outlined,
                      label: strings.pace,
                      value: '${analysis.pace} /km',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricTile(
                      icon: Icons.timer_outlined,
                      label: strings.duration,
                      value: formatRunDuration(shareableRun.timeSeconds),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MetricTile(
                      icon: Icons.monitor_heart_outlined,
                      label: strings.intensity,
                      value: analysis.intensityZone,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricTile(
                      icon: Icons.bolt_rounded,
                      label: strings.trainingLoad,
                      value: analysis.trainingLoad.toStringAsFixed(2),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppSurfaceCard(
          color: colorScheme.secondaryContainer,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.flag_outlined,
                color: colorScheme.onSecondaryContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.nextWorkout,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: colorScheme.onSecondaryContainer,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      analysis.recommendation,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSecondaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppSurfaceCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            strings.coachNote,
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                        IconButton(
                          tooltip: isSpeaking
                              ? strings.stopAudio
                              : strings.audioCoach,
                          onPressed: onSpeak,
                          icon: Icon(
                            isSpeaking
                                ? Icons.stop_circle_outlined
                                : Icons.volume_up_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      analysis.coachFeedback,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            height: 1.5,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ShareableRunCard(run: shareableRun),
      ],
    );
  }
}

class _ShoeSelection extends StatelessWidget {
  const _ShoeSelection({
    required this.gearTracker,
    required this.onSelected,
  });

  final GearTrackerService gearTracker;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return ListenableBuilder(
      listenable: gearTracker,
      builder: (context, _) {
        final shoes = gearTracker.shoes;
        if (gearTracker.loadError != null) {
          return Text(
            strings.shoeStorageUnavailable,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          );
        }
        return DropdownButtonFormField<String>(
          initialValue: gearTracker.selectedShoeId ?? '',
          decoration: InputDecoration(
            labelText: strings.selectShoes,
            helperText: shoes.isEmpty ? strings.addShoesToSelect : null,
            prefixIcon: const Icon(Icons.directions_run_rounded),
          ),
          items: [
            DropdownMenuItem(
              value: '',
              child: Text(strings.noShoeSelected),
            ),
            ...shoes.map(
              (shoe) => DropdownMenuItem(
                value: shoe.id,
                child: Text(
                  '${shoe.name} · ${shoe.totalKilometers.toStringAsFixed(1)} km',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
          onChanged: !gearTracker.isLoaded
              ? null
              : (value) =>
                  onSelected(value == null || value.isEmpty ? null : value),
        );
      },
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: colorScheme.primary, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.error),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onErrorContainer,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
