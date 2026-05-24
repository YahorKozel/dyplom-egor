import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationService {
  Future<LatLng?> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Usługa lokalizacji jest wyłączona. Włącz GPS.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Odmówiono dostępu do lokalizacji.');
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Dostęp do lokalizacji został zablokowany na stałe.');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      // Re-throw exceptions so the ViewModel can catch and display them
      rethrow;
    }
  }
}
