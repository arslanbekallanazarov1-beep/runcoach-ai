import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';

class HeartRateZonesDisplay extends StatelessWidget {
  const HeartRateZonesDisplay({
    required this.zones,
    required this.age,
    this.maxHr,
    super.key,
  });

  final Map<String, Map<String, int>> zones;
  final int? age;
  final int? maxHr;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outlineVariant,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.favorite_rounded, color: colorScheme.primary, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    strings.heartRateZones,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Max HR info
              if (maxHr != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        strings.maximumHeartRate,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                      Text(
                        '$maxHr BPM',
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.primary,
                            ),
                      ),
                    ],
                  ),
                ),

              if (age != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        strings.age,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                      Text(
                        '$age ${strings.years}',
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(
                                fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // Zones
              ...zones.entries.map((entry) {
                final zone = entry.key;
                final values = entry.value;
                final min = values['min']!;
                final max = values['max']!;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          zone,
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.primary,
                              ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '${strings.zoneRange} $min-$max ${strings.bpm}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: colorScheme.onSurfaceVariant),
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}