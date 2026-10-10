import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';
import '../models/training_plan.dart';
import '../services/training_plan_service.dart';
import '../widgets/app_surface_card.dart';

class TrainingPlanScreen extends StatefulWidget {
  const TrainingPlanScreen({
    required this.languageCode,
    required this.onLocaleChanged,
    required this.onThemeModeChanged,
    super.key,
    this.service,
    this.tokenProvider,
  });

  final String languageCode;
  final ValueChanged<Locale> onLocaleChanged;
  final ValueChanged<bool> onThemeModeChanged;
  final TrainingPlanService? service;
  final Future<String?> Function()? tokenProvider;

  @override
  State<TrainingPlanScreen> createState() => _TrainingPlanScreenState();
}

class _TrainingPlanScreenState extends State<TrainingPlanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _goalController = TextEditingController();
  final _weeksController = TextEditingController(text: '12');
  late final TrainingPlanService _service;
  String _fitnessLevel = 'beginner';
  TrainingPlan? _plan;
  bool _isLoading = false;
  bool _isLoadingSavedPlan = true;
  final Set<String> _updatingWorkoutIds = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = widget.service ??
        TrainingPlanService(tokenProvider: widget.tokenProvider);
    _loadSavedPlan();
  }

  @override
  void dispose() {
    _goalController.dispose();
    _weeksController.dispose();
    _service.close();
    super.dispose();
  }

  Future<void> _generatePlan() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final plan = await _service.generatePlan(
        goal: _goalController.text.trim(),
        fitnessLevel: _fitnessLevel,
        timelineWeeks: int.parse(_weeksController.text.trim()),
        language: widget.languageCode,
      );
      if (mounted) setState(() => _plan = plan);
    } on TrainingPlanException catch (error) {
      if (mounted) {
        setState(() => _error = _errorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSavedPlan() async {
    try {
      final plan = await _service.fetchPlan();
      if (mounted) {
        setState(() {
          _plan = plan;
          _isLoadingSavedPlan = false;
        });
      }
    } on TrainingPlanException catch (error) {
      if (mounted) {
        setState(() {
          _error = _errorMessage(error);
          _isLoadingSavedPlan = false;
        });
      }
    }
  }

  Future<void> _setWorkoutCompleted(
    TrainingPlanWorkout workout,
    bool completed,
  ) async {
    final plan = _plan;
    final workoutId = workout.id;
    final planId = plan?.id;
    if (planId == null || workoutId == null) return;

    setState(() => _updatingWorkoutIds.add(workoutId));
    try {
      await _service.updateWorkoutCompletion(
        planId: planId,
        workoutId: workoutId,
        completed: completed,
      );
      if (mounted) {
        setState(() {
          if (_plan?.id == planId) {
            _plan = _replaceWorkoutCompletion(_plan!, workoutId, completed);
          }
        });
      }
    } on TrainingPlanException catch (error) {
      if (mounted) {
        setState(() => _error = _errorMessage(error));
      }
    } finally {
      if (mounted) {
        setState(() => _updatingWorkoutIds.remove(workoutId));
      }
    }
  }

  TrainingPlan _replaceWorkoutCompletion(
    TrainingPlan plan,
    String workoutId,
    bool completed,
  ) {
    return TrainingPlan(
      id: plan.id,
      title: plan.title,
      overview: plan.overview,
      weeks: plan.weeks
          .map(
            (week) => TrainingPlanWeek(
              week: week.week,
              focus: week.focus,
              workouts: week.workouts
                  .map(
                    (workout) => workout.id == workoutId
                        ? TrainingPlanWorkout(
                            id: workout.id,
                            day: workout.day,
                            title: workout.title,
                            description: workout.description,
                            durationMinutes: workout.durationMinutes,
                            completed: completed,
                            completedAt:
                                completed ? DateTime.now().toUtc() : null,
                          )
                        : workout,
                  )
                  .toList(growable: false),
            ),
          )
          .toList(growable: false),
    );
  }

  String _errorMessage(TrainingPlanException error) {
    final strings = AppStrings.of(context);
    return switch (error.failure) {
      TrainingPlanFailure.connection => strings.planGenerationFailed,
      TrainingPlanFailure.notConfigured => strings.planProviderNotConfigured,
      TrainingPlanFailure.providerTimeout => strings.planProviderTimeout,
      TrainingPlanFailure.providerUnavailable =>
        strings.planProviderUnavailable,
      TrainingPlanFailure.invalidResponse => strings.planInvalidResponse,
      TrainingPlanFailure.http => strings.planServerRequestFailed
          .replaceAll('{status}', '${error.cause ?? ''}'),
    };
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _PlanHeader(
                    onLocaleChanged: widget.onLocaleChanged,
                    onThemeModeChanged: widget.onThemeModeChanged,
                  ),
                  const SizedBox(height: 24),
                  if (_isLoadingSavedPlan) ...[
                    const LinearProgressIndicator(),
                    const SizedBox(height: 16),
                  ],
                  AppSurfaceCard(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            strings.planIntro,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _goalController,
                            textCapitalization: TextCapitalization.sentences,
                            validator: (value) =>
                                value == null || value.trim().length < 2
                                    ? strings.enterGoal
                                    : null,
                            decoration: InputDecoration(
                              labelText: strings.planGoal,
                              hintText: strings.goalHint,
                              prefixIcon: const Icon(Icons.flag_outlined),
                            ),
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            initialValue: _fitnessLevel,
                            decoration: InputDecoration(
                              labelText: strings.fitnessLevel,
                              prefixIcon:
                                  const Icon(Icons.directions_run_rounded),
                            ),
                            items: [
                              DropdownMenuItem(
                                value: 'beginner',
                                child: Text(strings.beginner),
                              ),
                              DropdownMenuItem(
                                value: 'intermediate',
                                child: Text(strings.intermediate),
                              ),
                              DropdownMenuItem(
                                value: 'advanced',
                                child: Text(strings.advanced),
                              ),
                            ],
                            onChanged: _isLoading
                                ? null
                                : (value) {
                                    if (value != null) {
                                      setState(() => _fitnessLevel = value);
                                    }
                                  },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _weeksController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            validator: (value) {
                              final weeks = int.tryParse(value ?? '');
                              return weeks == null || weeks < 1 || weeks > 52
                                  ? strings.invalidWeeks
                                  : null;
                            },
                            decoration: InputDecoration(
                              labelText: strings.timeline,
                              prefixIcon:
                                  const Icon(Icons.calendar_month_rounded),
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _isLoading || _isLoadingSavedPlan
                                  ? null
                                  : _generatePlan,
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
                                _isLoading
                                    ? strings.generatingPlan
                                    : strings.generatePlan,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    _PlanError(message: _error!),
                  ],
                  if (_plan case final plan?) ...[
                    const SizedBox(height: 24),
                    Text(
                      plan.title,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    AppSurfaceCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            strings.planOverview,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Text(plan.overview),
                          const SizedBox(height: 10),
                          Text(
                            strings.recoverySafety,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    ...plan.weeks.map(
                      (week) => _PlanWeekCard(
                        week: week,
                        updatingWorkoutIds: _updatingWorkoutIds,
                        onWorkoutChanged: _setWorkoutCompleted,
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

class _PlanHeader extends StatelessWidget {
  const _PlanHeader({
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
            strings.trainingPlan,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        PopupMenuButton<Locale>(
          key: const ValueKey('plan-language-toggle'),
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

class _PlanWeekCard extends StatelessWidget {
  const _PlanWeekCard({
    required this.week,
    required this.updatingWorkoutIds,
    required this.onWorkoutChanged,
  });

  final TrainingPlanWeek week;
  final Set<String> updatingWorkoutIds;
  final void Function(TrainingPlanWorkout workout, bool completed)
      onWorkoutChanged;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.week(week.week),
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 5),
            Text(
              '${strings.weekFocus}: ${week.focus}',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: colorScheme.primary),
            ),
            const SizedBox(height: 12),
            ...week.workouts.map(
              (workout) {
                final workoutId = workout.id;
                return Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: workout.completed,
                          onChanged: workoutId == null ||
                                  updatingWorkoutIds.contains(workoutId)
                              ? null
                              : (completed) {
                                  if (completed != null) {
                                    onWorkoutChanged(workout, completed);
                                  }
                                },
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${workout.day} · ${workout.title}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            decoration: workout.completed
                                                ? TextDecoration.lineThrough
                                                : null,
                                          ),
                                    ),
                                  ),
                                  Text(
                                    '${workout.durationMinutes} ${strings.minutesUnit}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(color: colorScheme.primary),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(workout.description),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanError extends StatelessWidget {
  const _PlanError({required this.message});

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
