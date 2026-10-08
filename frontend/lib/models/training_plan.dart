class TrainingPlan {
  const TrainingPlan({
    required this.title,
    required this.overview,
    required this.weeks,
  });

  final String title;
  final String overview;
  final List<TrainingPlanWeek> weeks;

  factory TrainingPlan.fromJson(Map<String, dynamic> json) {
    final title = json['title'];
    final overview = json['overview'];
    final weeks = json['weeks'];
    if (title is! String || overview is! String || weeks is! List) {
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
  });

  final String day;
  final String title;
  final String description;
  final int durationMinutes;

  factory TrainingPlanWorkout.fromJson(Map<String, dynamic> json) {
    final day = json['day'];
    final title = json['title'];
    final description = json['description'];
    final durationMinutes = json['duration_minutes'];
    if (day is! String ||
        title is! String ||
        description is! String ||
        durationMinutes is! int) {
      throw const FormatException('Training plan workout has invalid fields.');
    }

    return TrainingPlanWorkout(
      day: day,
      title: title,
      description: description,
      durationMinutes: durationMinutes,
    );
  }
}
