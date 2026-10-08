class ShareableRun {
  const ShareableRun({
    required this.distanceKm,
    required this.pace,
    required this.timeSeconds,
    required this.coachComment,
    required this.date,
  });

  // Generic estimate only; the app does not collect body weight.
  static const estimatedCaloriesPerKm = 60;

  final double distanceKm;
  final String pace;
  final int timeSeconds;
  final String coachComment;
  final DateTime date;

  int get estimatedCalories => (distanceKm * estimatedCaloriesPerKm).round();
}
