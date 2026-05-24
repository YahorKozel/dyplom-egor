import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/constants.dart';
import '../models/city_location.dart';
import '../models/user_profile.dart';
import '../models/user_role.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';
import '../services/region_finder.dart';

class RegistrationViewModel extends ChangeNotifier {
  final AuthService _authService;
  final DatabaseService _dbService;
  final LocationService _locationService;
  final MapController mapController;

  RegistrationViewModel(this._authService, this._dbService, this._locationService)
      : mapController = MapController();

  LatLng? _selectedPosition;
  LatLng? get selectedPosition => _selectedPosition;

  CityLocation? _matchedRegion;
  CityLocation? get matchedRegion => _matchedRegion;

  List<CityLocation> _poiMarkers = [];
  List<CityLocation> get poiMarkers => _poiMarkers;

  UserRole _role = UserRole.senior;
  UserRole get role => _role;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  UserProfile? _registeredProfile;
  UserProfile? get registeredProfile => _registeredProfile;

  void setRole(UserRole role) {
    if (_role == role) return;
    _role = role;
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  Future<void> initLocationAndMarkers() async {
    _isLoading = true;
    notifyListeners();

    try {
      final pos = await _locationService.getCurrentLocation();
      if (pos != null) {
        _selectedPosition = pos;
        mapController.move(pos, AppConstants.defaultZoom);
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    }

    try {
      _poiMarkers = await _dbService.getMapMarkers();
    } catch (e) {
      print('Error loading POIs: $e');
    }

    // If we already have a GPS pin and regions loaded, resolve the matching
    // gmina so the city field can be filled in automatically.
    if (_selectedPosition != null && _poiMarkers.isNotEmpty) {
      _matchedRegion = RegionFinder.findContaining(_selectedPosition!, _poiMarkers);
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Centers the map on a city picked from the search field — without
  /// changing the user's "home" pin. The pin only moves when the user taps
  /// the map themselves.
  void focusOnCity(CityLocation city) {
    mapController.move(city.center, 12.0);
  }

  /// Records a map tap as the user's home location. Does NOT snap to the
  /// nearest city — keeps the pin exactly where the user tapped — but does
  /// resolve which gmina contains it so the city field can be filled in.
  CityLocation? selectPositionOnMap(LatLng pos) {
    _selectedPosition = pos;
    _matchedRegion = _poiMarkers.isEmpty
        ? null
        : RegionFinder.findContaining(pos, _poiMarkers);
    notifyListeners();
    return _matchedRegion;
  }

  Future<bool> registerUser({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String city,
    double? radiusKm,
  }) async {
    if (_selectedPosition == null) {
      _errorMessage = 'Wybierz miejsce na mapie.';
      notifyListeners();
      return false;
    }
    if (_role == UserRole.volunteer && (radiusKm == null || radiusKm <= 0)) {
      _errorMessage = 'Podaj poprawny promień działania (km).';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final userCredential = await _authService.registerWithEmailAndPassword(
        email,
        password,
      );

      final userProfile = UserProfile(
        uid: userCredential.user!.uid,
        firstName: firstName,
        lastName: lastName,
        email: email,
        city: city.isNotEmpty ? city : (_matchedRegion?.name ?? 'Nie podano'),
        cityId: _matchedRegion?.id,
        homeLocation: _selectedPosition!,
        role: _role,
        radiusKm: _role == UserRole.volunteer ? radiusKm : null,
      );

      await _dbService.saveUserProfile(userProfile);
      _registeredProfile = userProfile;

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      String message;
      final errStr = e.toString();
      if (errStr.contains('email-already-in-use')) {
        message = 'Ten adres e-mail jest już zajęty';
      } else if (errStr.contains('weak-password')) {
        message = 'Hasło musi mieć co najmniej 6 znaków';
      } else if (errStr.contains('invalid-email')) {
        message = 'Nieprawidłowy format e-mail';
      } else {
        message = errStr;
      }

      _errorMessage = message;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<List<CityLocation>> searchCities(String pattern) {
    return _dbService.searchCities(pattern);
  }
}
