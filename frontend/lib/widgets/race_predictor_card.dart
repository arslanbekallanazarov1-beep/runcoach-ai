import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/race_prediction.dart';
import 'app_surface_card.dart';

class RacePredictorCard extends StatelessWidget {
  const RacePredictorCard({
    required this.distanceKm,
    required this.timeSeconds,
    super.key,
  });

  final double distanceKm;
  final int timeSeconds;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final predictions = RacePrediction.fromRecentRun(
      distanceKm: distanceKm,
      timeSeconds: timeSeconds,
    );
    if (predictions.isEmpty) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.racePredictor,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            strings.predictionBasedOn,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: predictions
                .map(
                  (prediction) => Container(
                    width: 142,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.raceDistance(prediction.distanceKm),
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          RacePrediction.formatTime(prediction.time),
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}
