import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/city_location.dart';
import '../models/user_profile.dart';
import '../models/user_role.dart';
import '../services/database_service.dart';
import '../services/region_finder.dart';

class EditHomeViewModel extends ChangeNotifier {
  final DatabaseService _db;
  final MapController mapController;
  UserProfile profile;

  static const double minRadiusKm = 1;
  static const double maxRadiusKm = 100;

  EditHomeViewModel(this._db, this.profile)
      : mapController = MapController(),
        _selectedPosition = profile.homeLocation,
        _city = profile.city,
        _cityId = profile.cityId,
        _radiusKm = profile.radiusKm {
    _loadRegions();
  }

  LatLng _selectedPosition;
  LatLng get selectedPosition => _selectedPosition;

  String _city;
  String get city => _city;

  String? _cityId;
  String? get cityId => _cityId;

  double? _radiusKm;
  double? get radiusKm => _radiusKm;

  List<CityLocation> _poiMarkers = [];
  List<CityLocation> get poiMarkers => _poiMarkers;

  CityLocation? _matchedRegion;
  CityLocation? get matchedRegion => _matchedRegion;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _dirty = false;
  bool get dirty => _dirty;

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  Future<void> _loadRegions() async {
    _isLoading = true;
    notifyListeners();
    try {
      _poiMarkers = await _db.getMapMarkers();
      // Resolve the saved home so we show the right city name even if the
      // profile was created before city_id existed.
      _matchedRegion =
          RegionFinder.findContaining(_selectedPosition, _poiMarkers);
    } catch (e) {
      _errorMessage = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  void focusOnCity(CityLocation city) {
    mapController.move(city.center, 12.0);
  }

  CityLocation? selectPositionOnMap(LatLng pos) {
    _selectedPosition = pos;
    _matchedRegion = _poiMarkers.isEmpty
        ? null
        : RegionFinder.findContaining(pos, _poiMarkers);
    if (_matchedRegion != null) {
      _city = _matchedRegion!.name;
      _cityId = _matchedRegion!.id;
    }
    _dirty = true;
    notifyListeners();
    return _matchedRegion;
  }

  void setCityManually(CityLocation city) {
    _city = city.name;
    _cityId = city.id;
    _dirty = true;
    notifyListeners();
  }

  void setRadiusKm(double km) {
    if (profile.role != UserRole.volunteer) return;
    final clamped = km.clamp(minRadiusKm, maxRadiusKm);
    if (clamped == _radiusKm) return;
    _radiusKm = clamped;
    _dirty = true;
    notifyListeners();
  }

  Future<List<CityLocation>> searchCities(String pattern) {
    return _db.searchCities(pattern);
  }

  Future<UserProfile?> save() async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final updated = profile.copyWith(
        homeLocation: _selectedPosition,
        city: _city,
        cityId: _cityId,
        radiusKm: _radiusKm,
      );
      await _db.updateUserProfile(updated);
      profile = updated;
      _dirty = false;
      _isSaving = false;
      notifyListeners();
      return updated;
    } catch (e) {
      _errorMessage = e.toString();
      _isSaving = false;
      notifyListeners();
      return null;
    }
  }
}
