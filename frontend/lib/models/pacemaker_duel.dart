class PacemakerDuel {
  const PacemakerDuel({
    required this.distanceKm,
    required this.targetPaceSecondsPerKm,
  });

  final double distanceKm;
  final int targetPaceSecondsPerKm;

  String get formattedTargetPace {
    final minutes = targetPaceSecondsPerKm ~/ 60;
    final seconds = targetPaceSecondsPerKm % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
