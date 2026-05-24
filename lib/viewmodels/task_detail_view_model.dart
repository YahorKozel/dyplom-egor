import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/task.dart';
import '../models/user_profile.dart';
import '../services/database_service.dart';

/// Owns the realtime state of a single task detail screen:
///   - `.snapshots()` on the task doc → both sides see status flips instantly.
///   - Lazy-loaded senior + volunteer profiles (re-fetched when the
///     volunteer_id field changes).
///   - Action methods that wrap DatabaseService calls and report errors.
class TaskDetailViewModel extends ChangeNotifier {
  final DatabaseService _db;
  final String taskId;
  final UserProfile viewer;

  static const Distance _distance = Distance();

  StreamSubscription<HelpTask?>? _sub;

  HelpTask? _task;
  HelpTask? get task => _task;

  UserProfile? _senior;
  UserProfile? get senior => _senior;

  UserProfile? _volunteer;
  UserProfile? get volunteer => _volunteer;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _isBusy = false;
  bool get isBusy => _isBusy;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _lastLoadedSeniorId;
  String? _lastLoadedVolunteerId;

  TaskDetailViewModel(this._db, this.taskId, this.viewer) {
    _sub = _db.taskStream(taskId).listen(_onTask, onError: (Object e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    });
  }

  bool get isSenior => viewer.uid == _task?.seniorId;
  bool get isResponder => viewer.uid == _task?.volunteerId;
  bool get isParticipant => isSenior || isResponder;

  /// True only when the viewer is a participant (or task is OPEN) — used to
  /// decide whether to reveal the senior's exact home coordinates.
  bool get canSeeExactAddress {
    if (_task == null) return false;
    if (_task!.status == TaskStatus.cancelled) return isParticipant;
    if (_task!.status == TaskStatus.done) return isParticipant;
    return isParticipant;
  }

  double? get distanceKm {
    final s = _senior;
    if (s == null) return null;
    if (s.homeLocation.latitude == 0 && s.homeLocation.longitude == 0) return null;
    if (viewer.homeLocation.latitude == 0 && viewer.homeLocation.longitude == 0) {
      return null;
    }
    return _distance.as(LengthUnit.Meter, viewer.homeLocation, s.homeLocation) /
        1000;
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  Future<void> _onTask(HelpTask? task) async {
    _task = task;
    _isLoading = false;
    if (task == null) {
      notifyListeners();
      return;
    }

    if (task.seniorId.isNotEmpty && task.seniorId != _lastLoadedSeniorId) {
      _lastLoadedSeniorId = task.seniorId;
      try {
        _senior = await _db.getUserProfile(task.seniorId);
      } catch (e) {
        _errorMessage = e.toString();
      }
    }

    final vid = task.volunteerId;
    if (vid != null && vid.isNotEmpty && vid != _lastLoadedVolunteerId) {
      _lastLoadedVolunteerId = vid;
      try {
        _volunteer = await _db.getUserProfile(vid);
      } catch (e) {
        _errorMessage = e.toString();
      }
    } else if (vid == null) {
      _volunteer = null;
      _lastLoadedVolunteerId = null;
    }

    notifyListeners();
  }

  Future<bool> accept() async {
    if (_task == null) return false;
    return _run(() => _db.acceptTask(_task!.id, viewer.uid));
  }

  Future<bool> markDone() async {
    if (_task == null) return false;
    return _run(() => _db.markTaskDone(_task!.id));
  }

  Future<bool> cancelBySenior(String reason) async {
    if (_task == null) return false;
    return _run(() => _db.cancelTaskBySenior(_task!.id, reason));
  }

  Future<bool> withdrawAsVolunteer(String reason) async {
    if (_task == null) return false;
    return _run(() => _db.volunteerWithdraw(_task!.id, reason, viewer.uid));
  }

  Future<bool> _run(Future<void> Function() op) async {
    _isBusy = true;
    notifyListeners();
    try {
      await op();
      return true;
    } catch (e) {
      _errorMessage = _humanize(e);
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  /// Strips noisy prefixes ("Exception: ", "[cloud_firestore/...]") so the
  /// user sees a clean message in the SnackBar.
  static String _humanize(Object e) {
    final raw = e.toString();
    return raw
        .replaceFirst(RegExp(r'^Exception:\s*'), '')
        .replaceFirst(RegExp(r'^\[[^\]]+\]\s*'), '');
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
