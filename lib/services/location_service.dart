import 'package:geolocator/geolocator.dart';
import 'api_service.dart';

class LocationService {
  final ApiService _apiService = ApiService();

  Future<Position> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied, we cannot request permissions.');
    }

    return await Geolocator.getCurrentPosition();
  }

  Future<void> markAttendance(String action) async {
    Position? position;
    try {
      position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 5),
      );
    } catch (_) {
      position = await Geolocator.getLastKnownPosition();
    }
    
    position ??= Position(
      longitude: 0, 
      latitude: 0, 
      timestamp: DateTime.now(), 
      accuracy: 0, 
      altitude: 0, 
      heading: 0, 
      speed: 0, 
      speedAccuracy: 0, 
      altitudeAccuracy: 0, 
      headingAccuracy: 0
    );

    await _apiService.post('mark_attendance.php', {
      'action': action, // 'login' or 'logout'
      'latitude': position.latitude,
      'longitude': position.longitude,
    });
  }

  Future<void> updateLocation(double lat, double lng) async {
    await _apiService.post('update_location.php', {
      'latitude': lat,
      'longitude': lng,
    });
  }
}
