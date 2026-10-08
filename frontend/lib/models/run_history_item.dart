class RunHistoryItem {
  const RunHistoryItem({
    required this.id,
    required this.date,
    required this.distanceKm,
    required this.timeSeconds,
    required this.pace,
    required this.averageHeartRate,
    required this.rpe,
    required this.sleepHours,
    required this.restingHeartRate,
    required this.trainingLoad,
    required this.intensityZone,
    required this.recommendation,
    required this.coachFeedback,
  });

  final String id;
  final DateTime date;
  final double distanceKm;
  final int timeSeconds;
  final String pace;
  final int averageHeartRate;
  final int rpe;
  final double? sleepHours;
  final int? restingHeartRate;
  final double? trainingLoad;
  final String? intensityZone;
  final String? recommendation;
  final String? coachFeedback;

  factory RunHistoryItem.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final date = json['date'];
    final distanceKm = json['distance_km'];
    final timeSeconds = json['time_seconds'];
    final pace = json['pace'];
    final averageHeartRate = json['avg_hr'];
    final rpe = json['rpe'];
    final sleepHours = json['sleep_hours'];
    final restingHeartRate = json['resting_hr'];
    final trainingLoad = json['training_load'];
    final intensityZone = json['intensity_zone'];
    final recommendation = json['recommendation'];
    final coachFeedback = json['coach_feedback'];

    if (id is! String ||
        date is! String ||
        distanceKm is! num ||
        timeSeconds is! int ||
        pace is! String ||
        averageHeartRate is! int ||
        rpe is! int ||
        (sleepHours != null && sleepHours is! num) ||
        (restingHeartRate != null && restingHeartRate is! int) ||
        (trainingLoad != null && trainingLoad is! num) ||
        (intensityZone != null && intensityZone is! String) ||
        (recommendation != null && recommendation is! String) ||
        (coachFeedback != null && coachFeedback is! String)) {
      throw const FormatException('Run history item has invalid fields.');
    }

    final parsedDate = DateTime.tryParse(date);
    if (parsedDate == null) {
      throw const FormatException('Run history item has an invalid date.');
    }

    return RunHistoryItem(
      id: id,
      date: parsedDate,
      distanceKm: distanceKm.toDouble(),
      timeSeconds: timeSeconds,
      pace: pace,
      averageHeartRate: averageHeartRate,
      rpe: rpe,
      sleepHours: (sleepHours as num?)?.toDouble(),
      restingHeartRate: restingHeartRate as int?,
      trainingLoad: (trainingLoad as num?)?.toDouble(),
      intensityZone: intensityZone as String?,
      recommendation: recommendation as String?,
      coachFeedback: coachFeedback as String?,
    );
  }
}
