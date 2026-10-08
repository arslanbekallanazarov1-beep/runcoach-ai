class WeatherReport {
  const WeatherReport({
    required this.temperatureC,
    required this.feelsLikeC,
    required this.humidityPercent,
    required this.precipitationMm,
    required this.windSpeedKmh,
    required this.description,
    required this.forecastDate,
    required this.forecastMinimumC,
    required this.forecastMaximumC,
    required this.precipitationProbability,
    required this.forecastDescription,
    required this.clothingRecommendation,
  });

  final double temperatureC;
  final double feelsLikeC;
  final int humidityPercent;
  final double precipitationMm;
  final double windSpeedKmh;
  final String description;
  final String forecastDate;
  final double forecastMinimumC;
  final double forecastMaximumC;
  final int precipitationProbability;
  final String forecastDescription;
  final String clothingRecommendation;

  factory WeatherReport.fromJson(Map<String, dynamic> json) {
    final current = json['current'];
    final forecast = json['forecast'];
    final recommendation = json['clothing_recommendation'];
    if (current is! Map<String, dynamic> ||
        forecast is! Map<String, dynamic> ||
        recommendation is! String) {
      throw const FormatException('Weather response is missing required data.');
    }
    final temperatureC = current['temperature_c'];
    final feelsLikeC = current['feels_like_c'];
    final humidityPercent = current['relative_humidity'];
    final precipitationMm = current['precipitation_mm'];
    final windSpeedKmh = current['wind_speed_kmh'];
    final description = current['description'];
    final forecastDate = forecast['date'];
    final forecastMinimumC = forecast['temperature_min_c'];
    final forecastMaximumC = forecast['temperature_max_c'];
    final precipitationProbability = forecast['precipitation_probability'];
    final forecastDescription = forecast['description'];
    if (temperatureC is! num ||
        feelsLikeC is! num ||
        humidityPercent is! int ||
        precipitationMm is! num ||
        windSpeedKmh is! num ||
        description is! String ||
        forecastDate is! String ||
        forecastMinimumC is! num ||
        forecastMaximumC is! num ||
        precipitationProbability is! int ||
        forecastDescription is! String) {
      throw const FormatException('Weather response has invalid fields.');
    }
    return WeatherReport(
      temperatureC: temperatureC.toDouble(),
      feelsLikeC: feelsLikeC.toDouble(),
      humidityPercent: humidityPercent,
      precipitationMm: precipitationMm.toDouble(),
      windSpeedKmh: windSpeedKmh.toDouble(),
      description: description,
      forecastDate: forecastDate,
      forecastMinimumC: forecastMinimumC.toDouble(),
      forecastMaximumC: forecastMaximumC.toDouble(),
      precipitationProbability: precipitationProbability,
      forecastDescription: forecastDescription,
      clothingRecommendation: recommendation,
    );
  }
}
