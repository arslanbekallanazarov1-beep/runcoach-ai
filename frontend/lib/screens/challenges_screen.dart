import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/local_challenge.dart';
import '../models/pacemaker_duel.dart';
import '../widgets/app_surface_card.dart';

class ChallengesScreen extends StatelessWidget {
  const ChallengesScreen({
    required this.onLocaleChanged,
    required this.onThemeModeChanged,
    super.key,
  });

  final ValueChanged<Locale> onLocaleChanged;
  final ValueChanged<bool> onThemeModeChanged;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    const challenges = [
      LocalChallenge(
        id: 'weekly-consistency',
        kind: LocalChallengeKind.weeklyConsistency,
        target: 3,
      ),
      LocalChallenge(
        id: 'weekly-distance',
        kind: LocalChallengeKind.weeklyDistance,
        target: 10,
      ),
    ];
    const pacemaker = PacemakerDuel(
      distanceKm: 5,
      targetPaceSecondsPerKm: 360,
    );
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _ChallengesHeader(
                    onLocaleChanged: onLocaleChanged,
                    onThemeModeChanged: onThemeModeChanged,
                  ),
                  const SizedBox(height: 14),
                  Text(strings.challengesIntro),
                  const SizedBox(height: 20),
                  Text(
                    strings.localChallenge,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  for (final challenge in challenges)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AppSurfaceCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.flag_outlined),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    challenge.kind ==
                                            LocalChallengeKind.weeklyConsistency
                                        ? strings.consistencyChallenge
                                        : strings.distanceChallenge,
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                ),
                                Text(
                                  strings.previewOnly,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const LinearProgressIndicator(value: 0),
                            const SizedBox(height: 6),
                            Text(
                              '0 / ${challenge.target.toInt()} '
                              '${challenge.kind == LocalChallengeKind.weeklyConsistency ? strings.challengeRuns : strings.kilometersShort}',
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  AppSurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.speed_rounded),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                strings.virtualPacemakerDuel,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            Text(
                              strings.previewOnly,
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          strings.pacemakerPlaceholder,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${pacemaker.distanceKm.toStringAsFixed(0)} km · '
                          '${pacemaker.formattedTargetPace} /km',
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChallengesHeader extends StatelessWidget {
  const _ChallengesHeader({
    required this.onLocaleChanged,
    required this.onThemeModeChanged,
  });

  final ValueChanged<Locale> onLocaleChanged;
  final ValueChanged<bool> onThemeModeChanged;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context);
    final isDarkMode = colorScheme.brightness == Brightness.dark;
    return Row(
      children: [
        Expanded(
          child: Text(
            strings.challengesTitle,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        PopupMenuButton<Locale>(
          tooltip: strings.language,
          onSelected: onLocaleChanged,
          itemBuilder: (context) => [
            const PopupMenuItem(value: Locale('en'), child: Text('English')),
            const PopupMenuItem(value: Locale('ru'), child: Text('Русский')),
          ],
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              locale.languageCode.toUpperCase(),
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: isDarkMode ? strings.switchToLight : strings.switchToDark,
          onPressed: () => onThemeModeChanged(!isDarkMode),
          icon: Icon(
            isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          ),
        ),
      ],
    );
  }
}
