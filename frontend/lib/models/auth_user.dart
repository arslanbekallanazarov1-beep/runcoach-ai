class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.goal,
    this.experienceLevel,
    this.weeklyMileageKm,
    this.maxHr,
    this.age,
    this.availableTrainingDays,
  });

  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String? goal;
  final String? experienceLevel;
  final double? weeklyMileageKm;
  final int? maxHr;
  final int? age;
  final List<String>? availableTrainingDays;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final email = json['email'];
    final firstName = json['first_name'];
    final lastName = json['last_name'];
    if (id is! String ||
        email is! String ||
        firstName is! String ||
        lastName is! String) {
      throw const FormatException('The account response has invalid fields.');
    }
    final rawTrainingDays = json['available_training_days'];
    final trainingDays = switch (rawTrainingDays) {
      null => null,
      String value => value.split(',').where((day) => day.isNotEmpty).toList(),
      List<dynamic> values when values.every((day) => day is String) =>
        values.cast<String>(),
      _ => throw const FormatException(
          'The account response has invalid training days.',
        ),
    };
    return AuthUser(
      id: id,
      email: email,
      firstName: firstName,
      lastName: lastName,
      goal: json['goal'] as String?,
      experienceLevel: json['experience_level'] as String?,
      weeklyMileageKm: (json['weekly_mileage_km'] as num?)?.toDouble(),
      maxHr: json['max_hr'] as int?,
      age: json['age'] as int?,
      availableTrainingDays: trainingDays,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
        'goal': goal,
        'experience_level': experienceLevel,
        'weekly_mileage_km': weeklyMileageKm,
        'max_hr': maxHr,
        'age': age,
        'available_training_days': availableTrainingDays,
      };
}
