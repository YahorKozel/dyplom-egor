import 'dart:convert';

import 'package:latlong2/latlong.dart';

import '../models/city_location.dart';

/// Resolves a map tap to the Polish gmina (region) whose polygon contains it.
///
/// Polygons live in Firestore as JSON-stringified arrays of [lng, lat]
/// vertices (see `import-PL/importer.js`). To avoid keeping all ~3000
/// polygons parsed in memory we:
///   1. Sort all regions by Haversine distance from their pre-computed
///      `center` to the tap point.
///   2. Walk the closest [candidateLimit] of them, parse their polygon JSON,
///      and run a ray-casting point-in-polygon test.
///   3. Return the first region that contains the point, or — if none does
///      (taps in forests / between gminas) — the single nearest center as a
///      fallback.
class RegionFinder {
  static const Distance _distance = Distance();

  /// How many of the closest centers we bother parsing+testing.
  static const int candidateLimit = 10;

  /// Returns the region whose polygon contains [point], or the nearest one
  /// by center if no polygon match is found. Returns `null` only when
  /// [regions] is empty.
  static CityLocation? findContaining(LatLng point, List<CityLocation> regions) {
    if (regions.isEmpty) return null;

    final ranked = [...regions]..sort((a, b) {
        final da = _distance.as(LengthUnit.Meter, point, a.center);
        final db = _distance.as(LengthUnit.Meter, point, b.center);
        return da.compareTo(db);
      });

    final limit = ranked.length < candidateLimit ? ranked.length : candidateLimit;
    for (var i = 0; i < limit; i++) {
      final candidate = ranked[i];
      if (candidate.polygonJson == null) continue;
      if (_pointInRegion(point, candidate.polygonJson!)) {
        return candidate;
      }
    }

    return ranked.first;
  }

  /// Parses the JSON polygon string and runs ray-casting on every ring.
  /// Supports both Polygon ([[[lng,lat], ...]]) and MultiPolygon
  /// ([[[[lng,lat], ...]], ...]) GeoJSON-like shapes.
  static bool _pointInRegion(LatLng point, String polygonJson) {
    try {
      final decoded = jsonDecode(polygonJson);
      if (decoded is! List || decoded.isEmpty) return false;

      // Detect nesting depth — MultiPolygon has one extra level.
      // Polygon: [ ring, ring? ]            ring = [ [lng,lat], ... ]
      // MultiPolygon: [ polygon, polygon ]  polygon = [ ring, ... ]
      final first = decoded[0];
      if (first is! List || first.isEmpty) return false;
      final firstChild = first[0];

      Iterable<List<dynamic>> rings;
      if (firstChild is List && firstChild.isNotEmpty && firstChild[0] is List) {
        // MultiPolygon: flatten all rings across all polygons.
        rings = decoded
            .whereType<List>()
            .expand((poly) => poly.whereType<List>());
      } else {
        // Polygon: rings are the top-level elements.
        rings = decoded.whereType<List>();
      }

      for (final ring in rings) {
        if (_rayCast(point, ring)) return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Standard ray-casting algorithm. [ring] is a list of [lng, lat] pairs.
  static bool _rayCast(LatLng point, List<dynamic> ring) {
    final px = point.longitude;
    final py = point.latitude;
    var inside = false;

    for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
      final vi = ring[i];
      final vj = ring[j];
      if (vi is! List || vj is! List || vi.length < 2 || vj.length < 2) continue;

      final xi = (vi[0] as num).toDouble();
      final yi = (vi[1] as num).toDouble();
      final xj = (vj[0] as num).toDouble();
      final yj = (vj[1] as num).toDouble();

      final intersects = ((yi > py) != (yj > py)) &&
          (px < (xj - xi) * (py - yi) / ((yj - yi) == 0 ? 1e-12 : (yj - yi)) + xi);
      if (intersects) inside = !inside;
    }
    return inside;
  }
}
