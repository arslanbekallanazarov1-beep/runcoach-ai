class LocalChallenge {
  const LocalChallenge({
    required this.id,
    required this.kind,
    required this.target,
  });

  final String id;
  final LocalChallengeKind kind;
  final double target;
}

enum LocalChallengeKind { weeklyConsistency, weeklyDistance }
