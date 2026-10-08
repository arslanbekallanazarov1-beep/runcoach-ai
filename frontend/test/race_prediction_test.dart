import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:runcoach_ai/models/race_prediction.dart';

void main() {
  test('predicts standard race distances using the Riegel formula', () {
    final predictions = RacePrediction.fromRecentRun(
      distanceKm: 5,
      timeSeconds: 1800,
    );

    expect(predictions.map((prediction) => prediction.distanceKm), [
      5,
      10,
      21.0975,
      42.195,
    ]);
    expect(predictions.first.time, const Duration(minutes: 30));
    expect(
      predictions[1].time.inSeconds,
      (1800 * math.pow(10 / 5, 1.06)).round(),
      reason:
          'The prediction should use the Riegel exponent, not linear scaling.',
    );
  });

  test('formats predicted durations with hours when needed', () {
    expect(
      RacePrediction.formatTime(const Duration(minutes: 30, seconds: 5)),
      '30:05',
    );
    expect(
      RacePrediction.formatTime(
        const Duration(hours: 3, minutes: 45, seconds: 9),
      ),
      '03:45:09',
    );
  });

  test('rejects invalid run inputs', () {
    expect(
      RacePrediction.fromRecentRun(distanceKm: 0, timeSeconds: 1800),
      isEmpty,
    );
    expect(
      RacePrediction.fromRecentRun(distanceKm: 5, timeSeconds: 0),
      isEmpty,
    );
  });
}
