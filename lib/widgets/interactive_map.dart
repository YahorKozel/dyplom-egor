import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants.dart';
import '../models/city_location.dart';

class InteractiveMap extends StatelessWidget {
  final MapController mapController;
  final LatLng? selectedPosition;
  final void Function(LatLng)? onTap;
  final void Function(CityLocation)? onMarkerTap;
  final List<CityLocation> poiMarkers;

  const InteractiveMap({
    super.key,
    required this.mapController,
    required this.selectedPosition,
    this.onTap,
    this.onMarkerTap,
    this.poiMarkers = const [],
  });

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: selectedPosition ?? AppConstants.defaultMapCenter,
        initialZoom: AppConstants.defaultZoom,
        onTap: (tapPosition, point) {
          if (onTap != null) {
            onTap!(point);
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate: AppConstants.mapTileUrl,
          retinaMode: RetinaMode.isHighDensity(context),
          tileProvider: CancellableNetworkTileProvider(),
        ),
        RichAttributionWidget(
          attributions: [
            TextSourceAttribution(
              AppConstants.mapAttribution,
              onTap: () => launchUrl(Uri.parse('https://openstreetmap.org/copyright')),
            ),
          ],
        ),
        MarkerLayer(
          markers: [
            // Database POI markers
            ...poiMarkers.map(
              (city) => Marker(
                point: LatLng(city.lat, city.lng),
                width: 40,
                height: 40,
                child: GestureDetector(
                  onTap: () {
                    if (onMarkerTap != null) {
                      onMarkerTap!(city);
                    }
                  },
                  child: const Icon(
                    Icons.location_city,
                    color: Colors.blue,
                    size: 30,
                  ),
                ),
              ),
            ),
            // User selected position marker
            if (selectedPosition != null)
              Marker(
                point: selectedPosition!,
                width: 60,
                height: 60,
                child: const Icon(
                  Icons.location_pin,
                  color: Colors.red,
                  size: 50,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
