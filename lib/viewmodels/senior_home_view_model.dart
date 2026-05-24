import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/task.dart';
import '../models/user_profile.dart';
import '../services/database_service.dart';

/// Senior's own task list. Caches every volunteer that has accepted one of
/// the senior's tasks so the list can show "Pomaga: Jan K." on the card
/// without an extra request per item.
class SeniorHomeViewModel extends ChangeNotifier {
  final DatabaseService _db;
  final UserProfile senior;

  StreamSubscription<List<HelpTask>>? _sub;

  final Map<String, UserProfile> _volunteerCache = {};
  final Set<String> _missingVolunteerIds = {};

  SeniorHomeViewModel(this._db, this.senior) {
    _start();
  }

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<HelpTask> _tasks = const [];
  List<HelpTask> get tasks => _tasks;

  TaskStatus? _statusFilter; // null = all
  TaskStatus? get statusFilter => _statusFilter;

  List<HelpTask> get filteredTasks => _statusFilter == null
      ? _tasks
      : _tasks.where((t) => t.status == _statusFilter).toList();

  UserProfile? volunteerFor(HelpTask t) =>
      t.volunteerId == null ? null : _volunteerCache[t.volunteerId];

  void setStatusFilter(TaskStatus? status) {
    if (_statusFilter == status) return;
    _statusFilter = status;
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  void _start() {
    _sub?.cancel();
    _sub = _db.tasksBySeniorStream(senior.uid).listen(
      _onTasks,
      onError: (Object e) {
        _errorMessage = e.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<void> _onTasks(List<HelpTask> tasks) async {
    _tasks = tasks;

    final needed = tasks
        .map((t) => t.volunteerId)
        .whereType<String>()
        .where((id) =>
            id.isNotEmpty &&
            !_volunteerCache.containsKey(id) &&
            !_missingVolunteerIds.contains(id))
        .toSet();

    if (needed.isNotEmpty) {
      try {
        final fetched = await _db.getUsersByIds(needed);
        _volunteerCache.addAll(fetched);
        for (final id in needed) {
          if (!fetched.containsKey(id)) _missingVolunteerIds.add(id);
        }
      } catch (e) {
        _errorMessage = e.toString();
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
