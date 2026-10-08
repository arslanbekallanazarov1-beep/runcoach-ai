class RunAnalysis {
  const RunAnalysis({
    required this.pace,
    required this.trainingLoad,
    required this.intensityZone,
    required this.recommendation,
    required this.coachFeedback,
  });

  final String pace;
  final double trainingLoad;
  final String intensityZone;
  final String recommendation;
  final String coachFeedback;

  factory RunAnalysis.fromJson(Map<String, dynamic> json) {
    if (json['status'] != 'success') {
      throw const FormatException('The analysis response was not successful.');
    }

    final metrics = json['metrics'];
    if (metrics is! Map<String, dynamic>) {
      throw const FormatException('The analysis response is missing metrics.');
    }

    final pace = metrics['pace'];
    final trainingLoad = metrics['training_load'];
    final intensityZone = metrics['intensity_zone'];
    final recommendation = json['recommendation'];
    final coachFeedback = json['coach_feedback'];

    if (pace is! String ||
        trainingLoad is! num ||
        intensityZone is! String ||
        recommendation is! String ||
        coachFeedback is! String) {
      throw const FormatException('The analysis response has invalid fields.');
    }

    return RunAnalysis(
      pace: pace,
      trainingLoad: trainingLoad.toDouble(),
      intensityZone: intensityZone,
      recommendation: recommendation,
      coachFeedback: coachFeedback,
    );
  }
}
