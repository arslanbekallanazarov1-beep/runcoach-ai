import 'dart:math' as math;

class RacePrediction {
  const RacePrediction({
    required this.distanceKm,
    required this.time,
  });

  final double distanceKm;
  final Duration time;

  static List<RacePrediction> fromRecentRun({
    required double distanceKm,
    required int timeSeconds,
  }) {
    if (!distanceKm.isFinite || distanceKm <= 0 || timeSeconds <= 0) {
      return const [];
    }
    const raceDistances = [5.0, 10.0, 21.0975, 42.195];
    return raceDistances
        .map(
          (raceDistance) => RacePrediction(
            distanceKm: raceDistance,
            time: Duration(
              seconds: (timeSeconds * math.pow(raceDistance / distanceKm, 1.06))
                  .round(),
            ),
          ),
        )
        .toList(growable: false);
  }

  static String formatTime(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    final minutePart =
        hours > 0 ? minutes.toString().padLeft(2, '0') : '$minutes';
    final secondPart = seconds.toString().padLeft(2, '0');
    return hours > 0
        ? '${hours.toString().padLeft(2, '0')}:$minutePart:$secondPart'
        : '$minutePart:$secondPart';
  }
}
