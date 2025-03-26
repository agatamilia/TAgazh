import 'package:location/location.dart' as loc;
import 'package:geocoding/geocoding.dart';

class LocationService {
  static final loc.Location _location = loc.Location();
  
  // Get current position with timeout handling
  static Future<loc.LocationData?> getCurrentPosition() async {
    try {
      // Check and request location service
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) return null;
      }

      // Check and request permissions
      loc.PermissionStatus permission = await _location.hasPermission();
      if (permission == loc.PermissionStatus.denied) {
        permission = await _location.requestPermission();
        if (permission != loc.PermissionStatus.granted) return null;
      }

      if (permission == loc.PermissionStatus.deniedForever) return null;

      // Get location with timeout
      return await _location.getLocation().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('Location request timed out');
          return getMockPosition();
        },
      );
    } catch (e) {
      print('Location error: $e');
      return getMockPosition();
    }
  }

  // Improved mock position
  static loc.LocationData getMockPosition() {
    return loc.LocationData.fromMap({
      'latitude': -6.1944,  // Bogor coordinates
      'longitude': 106.8249,
      'accuracy': 50.0,
      'altitude': 0.0,
      'speed': 0.0,
      'speed_accuracy': 0.0,
      'heading': 0.0,
      'time': DateTime.now().millisecondsSinceEpoch.toDouble(),
      // Removed isMocked as it's not part of LocationData
    });
  }

static Future<String> getPlaceFromCoordinates(double latitude, double longitude) async {
  try {
    List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
    
    if (placemarks.isEmpty) return 'Bogor';

    final place = placemarks.first;
    
    // Find the most specific available location name
    final locationName = [
      // place.street,
      place.subLocality,    // Kelurahan/Desa
      place.locality,       // Kecamatan
      // place.subAdministrativeArea, // Kabupaten
    ].firstWhere(
      (name) => name != null && name!.isNotEmpty,
      orElse: () => 'Bogor'
    );
    
    return locationName ?? 'Bogor'; // Ensure we always return a String
  } catch (e) {
    print('Geocoding error: $e');
    return 'Bogor';
  }
}
  // New method to get complete location
  static Future<Map<String, dynamic>> getCompleteLocation() async {
    final position = await getCurrentPosition() ?? getMockPosition();
    final placeName = await getPlaceFromCoordinates(
      position.latitude ?? -6.243, 
      position.longitude ?? 105.8593585
    );

    return {
      'coordinates': {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
      },
      'address': placeName,
      'isMocked': position == getMockPosition(), // Manual mock check
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}