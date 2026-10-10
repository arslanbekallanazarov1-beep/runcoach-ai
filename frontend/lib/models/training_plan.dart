class TrainingPlan {
  const TrainingPlan({
    required this.title,
    required this.overview,
    required this.weeks,
    this.id,
  });

  final String? id;
  final String title;
  final String overview;
  final List<TrainingPlanWeek> weeks;

  factory TrainingPlan.fromJson(Map<String, dynamic> json) {
    final title = json['title'];
    final overview = json['overview'];
    final weeks = json['weeks'];
    final id = json['id'];
    if (title is! String ||
        overview is! String ||
        weeks is! List ||
        (id != null && id is! String)) {
      throw const FormatException('Training plan response has invalid fields.');
    }

    final parsedWeeks = weeks.map((week) {
      if (week is! Map<String, dynamic>) {
        throw const FormatException('Training plan week is invalid.');
      }
      return TrainingPlanWeek.fromJson(week);
    }).toList(growable: false);
    if (parsedWeeks.isEmpty ||
        parsedWeeks.indexed.any((entry) => entry.$1 + 1 != entry.$2.week) ||
        parsedWeeks.any((week) => week.workouts.length < 3)) {
      throw const FormatException(
        'Training plan must contain consecutive weeks with three workouts each.',
      );
    }

    return TrainingPlan(
      id: id as String?,
      title: title,
      overview: overview,
      weeks: parsedWeeks,
    );
  }
}

class TrainingPlanWeek {
  const TrainingPlanWeek({
    required this.week,
    required this.focus,
    required this.workouts,
  });

  final int week;
  final String focus;
  final List<TrainingPlanWorkout> workouts;

  factory TrainingPlanWeek.fromJson(Map<String, dynamic> json) {
    final week = json['week'];
    final focus = json['focus'];
    final workouts = json['workouts'];
    if (week is! int || focus is! String || workouts is! List) {
      throw const FormatException('Training plan week has invalid fields.');
    }

    return TrainingPlanWeek(
      week: week,
      focus: focus,
      workouts: workouts.map((workout) {
        if (workout is! Map<String, dynamic>) {
          throw const FormatException('Training plan workout is invalid.');
        }
        return TrainingPlanWorkout.fromJson(workout);
      }).toList(growable: false),
    );
  }
}

class TrainingPlanWorkout {
  const TrainingPlanWorkout({
    required this.day,
    required this.title,
    required this.description,
    required this.durationMinutes,
    this.id,
    this.completed = false,
    this.completedAt,
  });

  final String? id;
  final String day;
  final String title;
  final String description;
  final int durationMinutes;
  final bool completed;
  final DateTime? completedAt;

  factory TrainingPlanWorkout.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final day = json['day'];
    final title = json['title'];
    final description = json['description'];
    final durationMinutes = json['duration_minutes'];
    final completed = json['completed'];
    final completedAt = json['completed_at'];
    final parsedCompletedAt =
        completedAt is String ? DateTime.tryParse(completedAt) : null;
    if ((id != null && id is! String) ||
        day is! String ||
        title is! String ||
        description is! String ||
        durationMinutes is! int ||
        (completed != null && completed is! bool) ||
        (completedAt != null &&
            (completedAt is! String || parsedCompletedAt == null))) {
      throw const FormatException('Training plan workout has invalid fields.');
    }

    return TrainingPlanWorkout(
      id: id as String?,
      day: day,
      title: title,
      description: description,
      durationMinutes: durationMinutes,
      completed: completed as bool? ?? false,
      completedAt: parsedCompletedAt,
    );
  }
}
