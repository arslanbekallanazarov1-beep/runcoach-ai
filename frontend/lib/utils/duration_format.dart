String formatRunDuration(int totalSeconds) {
  final duration = Duration(seconds: totalSeconds);
  String twoDigits(int value) => value.toString().padLeft(2, '0');

  if (duration.inHours > 0) {
    return '${duration.inHours}:'
        '${twoDigits(duration.inMinutes.remainder(60))}:'
        '${twoDigits(duration.inSeconds.remainder(60))}';
  }
  return '${duration.inMinutes}:'
      '${twoDigits(duration.inSeconds.remainder(60))}';
}

int durationMinutesToSeconds(double durationMinutes) {
  return (durationMinutes * 60).round();
}

String formatPace(double paceMinutesPerKm) {
  if (paceMinutesPerKm <= 0) return '--';

  final minutes = paceMinutesPerKm.floor();
  final seconds = ((paceMinutesPerKm - minutes) * 60).round();

  if (seconds == 0) {
    return '$minutes min/km';
  } else {
    return '$minutes min $seconds sec/km';
  }
}
