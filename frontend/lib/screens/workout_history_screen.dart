import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/workout_history.dart';
import '../services/workout_history_service.dart';
import '../utils/duration_format.dart';
import '../widgets/app_surface_card.dart';

class WorkoutHistoryScreen extends StatefulWidget {
  const WorkoutHistoryScreen({
    required this.languageCode,
    required this.onLocaleChanged,
    required this.onThemeModeChanged,
    super.key,
    this.service,
  });

  final String languageCode;
  final ValueChanged<Locale> onLocaleChanged;
  final ValueChanged<bool> onThemeModeChanged;
  final WorkoutHistoryService? service;

  @override
  State<WorkoutHistoryScreen> createState() => _WorkoutHistoryScreenState();
}

class _WorkoutHistoryScreenState extends State<WorkoutHistoryScreen> {
  late final WorkoutHistoryService _service;
  late final bool _ownsService;
  final _distanceController = TextEditingController();
  final _timeController = TextEditingController();
  final Set<String> _deletingWorkoutIds = {};
  bool _isAdding = false;

  @override
  void initState() {
    super.initState();
    _ownsService = widget.service == null;
    _service = widget.service ?? WorkoutHistoryService();
    unawaited(_service.load());
  }

  @override
  void dispose() {
    _distanceController.dispose();
    _timeController.dispose();
    if (_ownsService) _service.dispose();
    super.dispose();
  }

  Future<void> _addWorkout() async {
    final distance =
        double.tryParse(_distanceController.text.replaceAll(',', '.'));
    final timeParts = _timeController.text.split(':');
    int timeSeconds = 0;
    if (timeParts.length == 2) {
      final minutes = int.tryParse(timeParts[0]) ?? 0;
      final seconds = int.tryParse(timeParts[1]) ?? 0;
      timeSeconds = minutes * 60 + seconds;
    }

    if (distance == null || distance <= 0 || timeSeconds <= 0) {
      return;
    }

    setState(() => _isAdding = true);
    try {
      await _service.addWorkout(
        distanceKm: distance,
        timeSeconds: timeSeconds,
      );
      if (mounted) {
        Navigator.of(context).pop();
        _distanceController.clear();
        _timeController.clear();
      }
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  void _showAddWorkoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppStrings.of(context).addWorkout),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _distanceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: AppStrings.of(context).distance,
                hintText: 'e.g. 5.5',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _timeController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: AppStrings.of(context).duration,
                hintText: 'MM:SS (e.g. 30:00)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _isAdding ? null : () => Navigator.of(context).pop(),
            child: Text(AppStrings.of(context).cancel),
          ),
          FilledButton(
            onPressed: _isAdding ? null : _addWorkout,
            child: _isAdding
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(AppStrings.of(context).addWorkout),
          ),
        ],
      ),
    );
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
                  _WorkoutHistoryHeader(
                    onLocaleChanged: widget.onLocaleChanged,
                    onThemeModeChanged: widget.onThemeModeChanged,
                  ),
                  const SizedBox(height: 24),
                  if (_service.isLoaded && _service.loadError != null) ...[
                    _ErrorBanner(message: _service.loadError!),
                    const SizedBox(height: 16),
                  ],
                  if (_service.isLoaded) ...[
                    _StatsOverview(service: _service),
                    const SizedBox(height: 24),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          strings.recentRuns,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (_service.isLoaded && !_service.isSyncedWithServer)
                        TextButton.icon(
                          onPressed: _showAddWorkoutDialog,
                          icon: const Icon(Icons.add_rounded, size: 20),
                          label: Text(strings.addWorkout),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (!_service.isLoaded)
                    const Center(child: CircularProgressIndicator())
                  else if (_service.workouts.isEmpty)
                    _EmptyState(
                      message: strings.noRuns,
                      onAdd: _service.isSyncedWithServer
                          ? null
                          : _showAddWorkoutDialog,
                    )
                  else
                    ..._service.workouts.map(
                      (workout) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _WorkoutCard(
                          workout: workout,
                          isDeleting: _deletingWorkoutIds.contains(workout.id),
                          onDelete: () => _confirmDelete(workout),
                        ),
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

  Future<void> _confirmDelete(WorkoutHistory workout) async {
    final strings = AppStrings.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.deleteWorkout),
        content: Text(strings.deleteWorkoutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.error,
            ),
            child: Text(strings.deleteWorkout),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deletingWorkoutIds.add(workout.id));
    try {
      await _service.removeWorkout(workout.id);
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.historyDeleteFailed)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _deletingWorkoutIds.remove(workout.id));
      }
    }
  }
}

class _WorkoutHistoryHeader extends StatelessWidget {
  const _WorkoutHistoryHeader({
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
            strings.recentRuns,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        PopupMenuButton<Locale>(
          key: const ValueKey('workout-history-language-toggle'),
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

class _StatsOverview extends StatelessWidget {
  const _StatsOverview({required this.service});

  final WorkoutHistoryService service;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: strings.totalDistance,
            value:
                '${service.totalDistanceKm.toStringAsFixed(1)} ${strings.kilometersShort}',
            icon: Icons.directions_run_rounded,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            title: strings.totalTime,
            value: formatRunDuration(service.totalTimeSeconds),
            icon: Icons.timer_rounded,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            title: strings.avgPace,
            value: service.averagePaceMinPerKm > 0
                ? formatPace(service.averagePaceMinPerKm)
                : '--',
            icon: Icons.speed_rounded,
            color: Colors.green,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AppSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkoutCard extends StatelessWidget {
  const _WorkoutCard({
    required this.workout,
    required this.isDeleting,
    required this.onDelete,
  });

  final WorkoutHistory workout;
  final bool isDeleting;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return AppSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    MaterialLocalizations.of(context)
                        .formatMediumDate(workout.date),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _WorkoutInfoChip(
                        icon: Icons.directions_run_rounded,
                        label: strings.distance,
                        value:
                            '${workout.distanceKm.toStringAsFixed(2)} ${strings.kilometersShort}',
                        color: colorScheme.primary,
                      ),
                      _WorkoutInfoChip(
                        icon: Icons.timer_rounded,
                        label: strings.duration,
                        value: formatRunDuration(workout.timeSeconds),
                        color: Colors.blue,
                      ),
                      _WorkoutInfoChip(
                        icon: Icons.speed_rounded,
                        label: strings.pace,
                        value: formatPace(workout.paceMinPerKm),
                        color: Colors.green,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: isDeleting
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      Icons.delete_outline_rounded,
                      color: colorScheme.error,
                    ),
              onPressed: isDeleting ? null : onDelete,
              tooltip: strings.deleteWorkout,
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkoutInfoChip extends StatelessWidget {
  const _WorkoutInfoChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.message,
    required this.onAdd,
  });

  final String message;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return AppSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.directions_run_rounded,
              size: 64,
              color: colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (onAdd != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
                label: Text(strings.addWorkout),
              ),
            ],
          ],
        ),
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
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child:
          Text(message, style: TextStyle(color: colorScheme.onErrorContainer)),
    );
  }
}
