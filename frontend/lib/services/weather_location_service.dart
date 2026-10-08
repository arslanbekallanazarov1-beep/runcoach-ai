import 'package:geolocator/geolocator.dart';

class WeatherCoordinates {
  const WeatherCoordinates({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;
}

abstract interface class WeatherLocationProvider {
  Future<WeatherCoordinates?> getCurrentLocation();
}

class GeolocatorWeatherLocationProvider implements WeatherLocationProvider {
  @override
  Future<WeatherCoordinates?> getCurrentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever ||
        permission == LocationPermission.unableToDetermine) {
      return null;
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 15),
      ),
    );
    return WeatherCoordinates(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }
}
