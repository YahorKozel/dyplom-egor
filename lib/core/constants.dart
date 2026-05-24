import 'package:latlong2/latlong.dart';

class AppConstants {
  // Firebase Collections
  static const String locationsCollection = 'regions'; // Fallback to 'regions' as it was originally used
  static const String usersCollection = 'users';
  static const String tasksCollection = 'tasks';

  // Defaults
  static const double defaultVolunteerRadiusKm = 5.0;

  // Map Constants
  static const double defaultZoom = 13.0;
  static const LatLng defaultMapCenter = LatLng(54.5189, 18.5305); // Default to Gdynia/Gdansk

  // Map Tile Provider (Modern stylized map)
  static const String mapTileUrl = 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png';
  static const String mapAttribution = '© OpenStreetMap contributors, © CARTO';

  // Layout Constants
  static const double defaultPadding = 20.0;
  static const double defaultBorderRadius = 16.0;
}
