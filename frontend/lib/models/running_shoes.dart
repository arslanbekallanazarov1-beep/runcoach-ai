class RunningShoes {
  const RunningShoes({
    required this.id,
    required this.name,
    required this.totalKilometers,
  });

  final String id;
  final String name;
  final double totalKilometers;

  RunningShoes addKilometers(double kilometers) => RunningShoes(
        id: id,
        name: name,
        totalKilometers: totalKilometers + kilometers,
      );

  factory RunningShoes.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final totalKilometers = json['total_kilometers'];
    if (id is! String ||
        name is! String ||
        (totalKilometers is! num) ||
        !totalKilometers.isFinite ||
        totalKilometers < 0) {
      throw const FormatException('Stored shoe data is invalid.');
    }
    return RunningShoes(
      id: id,
      name: name,
      totalKilometers: totalKilometers.toDouble(),
    );
  }

  Map<String, Object> toJson() => {
        'id': id,
        'name': name,
        'total_kilometers': totalKilometers,
      };
}
