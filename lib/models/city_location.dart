import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

class CityLocation {
  final String id;
  final String name;
  final String country;
  final double lat;
  final double lng;

  /// Raw polygon JSON string from `regions/{id}.coordinates`, if present.
  /// Shape after decode: [[[lng, lat], [lng, lat], ...]] (outer = polygon
  /// list / MultiPolygon, middle = ring, inner = [lng, lat] vertex).
  ///
  /// Kept as a string so we don't pay parse cost for every region — only the
  /// candidates near the user tap are parsed (see RegionFinder).
  final String? polygonJson;

  CityLocation({
    required this.id,
    required this.name,
    required this.country,
    required this.lat,
    required this.lng,
    this.polygonJson,
  });

  LatLng get center => LatLng(lat, lng);

  factory CityLocation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    double parsedLat = 0.0;
    double parsedLng = 0.0;

    // Prioritize reading the 'center' GeoPoint if it exists (new schema)
    if (data.containsKey('center') && data['center'] is GeoPoint) {
      final geoPoint = data['center'] as GeoPoint;
      parsedLat = geoPoint.latitude;
      parsedLng = geoPoint.longitude;
    }
    // Fallback 1: Direct lat/lng numbers
    else if (data.containsKey('lat') && data.containsKey('lng')) {
      parsedLat = (data['lat'] as num).toDouble();
      parsedLng = (data['lng'] as num).toDouble();
    }
    // Fallback 2: The old 'regions' collection format (Polygon coordinates string)
    else if (data.containsKey('coordinates')) {
      try {
        final coordsString = data['coordinates'] as String;
        final parsed = jsonDecode(coordsString) as List<dynamic>;
        if (parsed.isNotEmpty) {
          List<dynamic> points = [];
          if (parsed[0] is List && parsed[0].isNotEmpty && parsed[0][0] is List) {
            points = parsed[0];
          } else {
            points = parsed;
          }
          if (points.isNotEmpty && points[0] is List && points[0].length >= 2) {
            parsedLng = (points[0][0] as num).toDouble();
            parsedLat = (points[0][1] as num).toDouble();
          }
        }
      } catch (e) {
        // Ignore parse errors
      }
    }

    final polygonJson = data['coordinates'] is String
        ? data['coordinates'] as String
        : null;

    return CityLocation(
      id: doc.id,
      name: data['name'] ?? '',
      country: data['country'] ?? '',
      lat: parsedLat,
      lng: parsedLng,
      polygonJson: polygonJson,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'country': country,
      'lat': lat,
      'lng': lng,
    };
  }
}
