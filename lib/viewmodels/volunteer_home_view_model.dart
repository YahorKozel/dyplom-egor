import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../core/constants.dart';
import '../models/task.dart';
import '../models/user_profile.dart';
import '../services/database_service.dart';

/// Task augmented with the senior who created it and the distance from the
/// volunteer. Distance is computed via Haversine (latlong2 `Distance`).
class NearbyTask {
  final HelpTask task;
  final UserProfile senior;
  final double distanceKm;

  NearbyTask({
    required this.task,
    required this.senior,
    required this.distanceKm,
  });
}

class VolunteerHomeViewModel extends ChangeNotifier {
  final DatabaseService _db;
  final UserProfile volunteer;

  /// Bounds for the in-app radius slider.
  static const double minRadiusKm = 1;
  static const double maxRadiusKm = 100;

  static const Distance _distance = Distance(); // Haversine

  StreamSubscription<List<HelpTask>>? _openSub;
  StreamSubscription<List<HelpTask>>? _mineSub;

  /// Cached snapshot of every OPEN task from Firestore.
  List<HelpTask> _allOpenTasks = const [];

  /// Tasks where this volunteer is the responder (any status).
  List<HelpTask> _myTasks = const [];

  /// Cached senior profiles by uid. Reused across both streams so the same
  /// fetch covers both lists.
  final Map<String, UserProfile> _seniorCache = {};
  final Set<String> _missingSeniorIds = {};

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  late double _currentRadiusKm = (volunteer.radiusKm ??
          AppConstants.defaultVolunteerRadiusKm)
      .clamp(minRadiusKm, maxRadiusKm);

  double get currentRadiusKm => _currentRadiusKm;

  /// When the slider is dragged to its maximum the filter is disabled and
  /// every open task is shown (still sorted by distance).
  bool get isUnlimited => _currentRadiusKm >= maxRadiusKm;

  List<NearbyTask> _nearby = const [];
  List<NearbyTask> get nearby => _nearby;

  List<NearbyTask> _mine = const [];
  List<NearbyTask> get mine => _mine;

  UserProfile? seniorFor(HelpTask t) => _seniorCache[t.seniorId];

  VolunteerHomeViewModel(this._db, this.volunteer) {
    _start();
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  /// Update the in-memory filter radius. Re-runs the filter against cached
  /// tasks/seniors immediately — no Firestore round-trip required.
  void setRadiusKm(double km) {
    final clamped = km.clamp(minRadiusKm, maxRadiusKm);
    if (clamped == _currentRadiusKm) return;
    _currentRadiusKm = clamped;
    _recomputeNearby();
    notifyListeners();
  }

  void _start() {
    _openSub?.cancel();
    _openSub = _db.openTasksStream().listen(
      _onOpenTasks,
      onError: (Object e) {
        _errorMessage = e.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
    _mineSub?.cancel();
    _mineSub = _db.tasksByVolunteerStream(volunteer.uid).listen(
      _onMyTasks,
      onError: (Object e) {
        _errorMessage = e.toString();
        notifyListeners();
      },
    );
  }

  Future<void> _onOpenTasks(List<HelpTask> tasks) async {
    _allOpenTasks = tasks;
    await _ensureSeniors(tasks.map((t) => t.seniorId));
    _recomputeNearby();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _onMyTasks(List<HelpTask> tasks) async {
    _myTasks = tasks;
    await _ensureSeniors(tasks.map((t) => t.seniorId));
    _recomputeMine();
    notifyListeners();
  }

  Future<void> _ensureSeniors(Iterable<String> ids) async {
    final needed = ids
        .where((id) =>
            id.isNotEmpty &&
            !_seniorCache.containsKey(id) &&
            !_missingSeniorIds.contains(id))
        .toSet();
    if (needed.isEmpty) return;
    try {
      final fetched = await _db.getUsersByIds(needed);
      _seniorCache.addAll(fetched);
      for (final id in needed) {
        if (!fetched.containsKey(id)) _missingSeniorIds.add(id);
      }
    } catch (e) {
      _errorMessage = e.toString();
    }
  }

  void _recomputeNearby() {
    final volunteerPos = volunteer.homeLocation;
    final radiusM = _currentRadiusKm * 1000;
    final unlimited = isUnlimited;

    final out = <NearbyTask>[];
    for (final task in _allOpenTasks) {
      final senior = _seniorCache[task.seniorId];
      if (senior == null) continue;
      if (senior.homeLocation.latitude == 0 &&
          senior.homeLocation.longitude == 0) {
        continue;
      }
      final meters = _distance.as(
          LengthUnit.Meter, volunteerPos, senior.homeLocation);
      if (!unlimited && meters > radiusM) continue;
      out.add(NearbyTask(
        task: task,
        senior: senior,
        distanceKm: meters / 1000,
      ));
    }
    out.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    _nearby = out;
  }

  void _recomputeMine() {
    final volunteerPos = volunteer.homeLocation;
    final out = <NearbyTask>[];
    for (final task in _myTasks) {
      final senior = _seniorCache[task.seniorId];
      if (senior == null) continue;
      final hasGeo = senior.homeLocation.latitude != 0 ||
          senior.homeLocation.longitude != 0;
      final meters = hasGeo
          ? _distance.as(LengthUnit.Meter, volunteerPos, senior.homeLocation)
          : 0.0;
      out.add(NearbyTask(
        task: task,
        senior: senior,
        distanceKm: meters / 1000,
      ));
    }
    out.sort((a, b) {
      final aTime = a.task.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.task.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    _mine = out;
  }

  @override
  void dispose() {
    _openSub?.cancel();
    _mineSub?.cancel();
    super.dispose();
  }
}
