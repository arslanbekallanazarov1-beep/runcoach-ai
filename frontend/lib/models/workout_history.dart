class WorkoutHistory {
  const WorkoutHistory({
    required this.id,
    required this.date,
    required this.distanceKm,
    required this.timeSeconds,
    required this.paceMinPerKm,
  });

  final String id;
  final DateTime date;
  final double distanceKm;
  final int timeSeconds;
  final double paceMinPerKm;

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'distance_km': distanceKm,
        'time_seconds': timeSeconds,
        'pace_min_per_km': paceMinPerKm,
      };

  factory WorkoutHistory.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final date = json['date'];
    final distanceKm = json['distance_km'];
    final timeSeconds = json['time_seconds'];
    final paceMinPerKm = json['pace_min_per_km'];

    if (id is! String ||
        date is! String ||
        distanceKm is! num ||
        timeSeconds is! int ||
        paceMinPerKm is! num) {
      throw const FormatException('Workout history entry has invalid fields.');
    }

    final parsedDate = DateTime.tryParse(date);
    if (parsedDate == null) {
      throw const FormatException('Workout history entry has an invalid date.');
    }

    return WorkoutHistory(
      id: id,
      date: parsedDate,
      distanceKm: distanceKm.toDouble(),
      timeSeconds: timeSeconds,
      paceMinPerKm: paceMinPerKm.toDouble(),
    );
  }
}
