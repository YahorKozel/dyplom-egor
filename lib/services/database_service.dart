import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

import '../core/constants.dart';
import '../models/city_location.dart';
import '../models/task.dart';
import '../models/user_profile.dart';
import 'region_finder.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ───── Cities (regions collection) ─────

  Future<List<CityLocation>> searchCities(String pattern) async {
    if (pattern.length < 2) return [];
    final query = pattern.toLowerCase();
    try {
      final snapshot = await _firestore
          .collection(AppConstants.locationsCollection)
          .where('nameLower', isGreaterThanOrEqualTo: query)
          .where('nameLower', isLessThanOrEqualTo: '$query')
          .limit(15)
          .get();
      return snapshot.docs.map(CityLocation.fromFirestore).toList();
    } catch (e) {
      print('Error searching cities: $e');
      return [];
    }
  }

  Future<List<CityLocation>> getMapMarkers() async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.locationsCollection)
          .get();
      return snapshot.docs.map(CityLocation.fromFirestore).toList();
    } catch (e) {
      print('Error fetching map markers: $e');
      return [];
    }
  }

  /// Convenience wrapper around [RegionFinder.findContaining]. Callers that
  /// already loaded the regions list should call the static finder directly
  /// to avoid a second fetch.
  Future<CityLocation?> findRegionForPoint(LatLng point) async {
    final regions = await getMapMarkers();
    return RegionFinder.findContaining(point, regions);
  }

  // ───── Users ─────

  Future<void> saveUserProfile(UserProfile user) {
    return _firestore
        .collection(AppConstants.usersCollection)
        .doc(user.uid)
        .set(user.toMap());
  }

  /// Partial update — used by the post-registration profile/home editor so we
  /// don't reset createdAt / email / role.
  Future<void> updateUserProfile(UserProfile user) {
    return _firestore
        .collection(AppConstants.usersCollection)
        .doc(user.uid)
        .update(user.toEditMap());
  }

  Future<UserProfile?> getUserProfile(String uid) async {
    final doc = await _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .get();
    if (!doc.exists) return null;
    return UserProfile.fromFirestore(doc);
  }

  Stream<UserProfile?> userProfileStream(String uid) {
    return _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? UserProfile.fromFirestore(doc) : null);
  }

  /// Bulk-load multiple users by id. Firestore `whereIn` is capped at 30,
  /// so we chunk the request.
  Future<Map<String, UserProfile>> getUsersByIds(Iterable<String> ids) async {
    final unique = ids.toSet().toList();
    if (unique.isEmpty) return {};

    final result = <String, UserProfile>{};
    for (var i = 0; i < unique.length; i += 30) {
      final chunk = unique.sublist(i, (i + 30).clamp(0, unique.length));
      final snap = await _firestore
          .collection(AppConstants.usersCollection)
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snap.docs) {
        result[doc.id] = UserProfile.fromFirestore(doc);
      }
    }
    return result;
  }

  // ───── Tasks ─────

  Future<String> createTask(HelpTask task) async {
    final ref = await _firestore
        .collection(AppConstants.tasksCollection)
        .add(task.toCreateMap());
    return ref.id;
  }

  /// Live stream of all tasks created by a given senior (newest first).
  Stream<List<HelpTask>> tasksBySeniorStream(String seniorId) {
    return _firestore
        .collection(AppConstants.tasksCollection)
        .where('senior_id', isEqualTo: seniorId)
        .snapshots()
        .map((snap) {
      final tasks = snap.docs.map(HelpTask.fromFirestore).toList();
      tasks.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
      return tasks;
    });
  }

  /// Live stream of every OPEN task (the volunteer side filters by distance).
  Stream<List<HelpTask>> openTasksStream() {
    return _firestore
        .collection(AppConstants.tasksCollection)
        .where('status', isEqualTo: TaskStatus.open.toWire())
        .snapshots()
        .map((snap) => snap.docs.map(HelpTask.fromFirestore).toList());
  }

  /// Live stream of every task assigned to a given volunteer (newest first).
  /// Used by the "Moje zadania" tab on the volunteer home screen.
  Stream<List<HelpTask>> tasksByVolunteerStream(String volunteerId) {
    return _firestore
        .collection(AppConstants.tasksCollection)
        .where('volunteer_id', isEqualTo: volunteerId)
        .snapshots()
        .map((snap) {
      final tasks = snap.docs.map(HelpTask.fromFirestore).toList();
      tasks.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
      return tasks;
    });
  }

  /// Live stream of a single task document — used by TaskDetailScreen so both
  /// senior and volunteer see status/responder changes immediately.
  Stream<HelpTask?> taskStream(String taskId) {
    return _firestore
        .collection(AppConstants.tasksCollection)
        .doc(taskId)
        .snapshots()
        .map((doc) => doc.exists ? HelpTask.fromFirestore(doc) : null);
  }

  /// All status mutations go through transactions so two volunteers tapping
  /// "Pomagam" at the same moment can't both win — only the first one's
  /// status flip lands, the second one sees [TaskOperationException].
  Future<void> acceptTask(String taskId, String volunteerId) {
    return _firestore.runTransaction((tx) async {
      final ref = _firestore
          .collection(AppConstants.tasksCollection)
          .doc(taskId);
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw const TaskOperationException('Zgłoszenie już nie istnieje');
      }
      final task = HelpTask.fromFirestore(snap);
      if (task.status != TaskStatus.open) {
        throw const TaskOperationException(
          'Ktoś inny już podjął to zgłoszenie lub zostało zamknięte',
        );
      }
      tx.update(ref, {
        'status': TaskStatus.inProgress.toWire(),
        'volunteer_id': volunteerId,
        'acceptedAt': FieldValue.serverTimestamp(),
        // Clear any leftover withdraw metadata from a previous responder so
        // history stays clean.
        'cancelled_by': FieldValue.delete(),
        'cancel_reason': FieldValue.delete(),
        'cancelledAt': FieldValue.delete(),
      });
    });
  }

  Future<void> markTaskDone(String taskId) {
    return _firestore.runTransaction((tx) async {
      final ref = _firestore
          .collection(AppConstants.tasksCollection)
          .doc(taskId);
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw const TaskOperationException('Zgłoszenie już nie istnieje');
      }
      final task = HelpTask.fromFirestore(snap);
      if (task.status != TaskStatus.inProgress) {
        throw const TaskOperationException(
          'Można oznaczyć wykonane tylko zgłoszenie w trakcie realizacji',
        );
      }
      tx.update(ref, {
        'status': TaskStatus.done.toWire(),
        'completedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Senior cancels — the task stays cancelled (terminal state).
  Future<void> cancelTaskBySenior(String taskId, String reason) {
    return _firestore.runTransaction((tx) async {
      final ref = _firestore
          .collection(AppConstants.tasksCollection)
          .doc(taskId);
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw const TaskOperationException('Zgłoszenie już nie istnieje');
      }
      final task = HelpTask.fromFirestore(snap);
      if (task.status == TaskStatus.cancelled ||
          task.status == TaskStatus.done) {
        throw const TaskOperationException(
          'Zgłoszenie zostało już zakończone i nie można go anulować',
        );
      }
      tx.update(ref, {
        'status': TaskStatus.cancelled.toWire(),
        'cancelled_by': CancelledBy.senior.toWire(),
        'cancel_reason': reason,
        'cancelledAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Volunteer backs out — the task returns to OPEN with the responder
  /// cleared, but we keep the reason so the senior can see what happened.
  Future<void> volunteerWithdraw(
    String taskId,
    String reason,
    String volunteerId,
  ) {
    return _firestore.runTransaction((tx) async {
      final ref = _firestore
          .collection(AppConstants.tasksCollection)
          .doc(taskId);
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw const TaskOperationException('Zgłoszenie już nie istnieje');
      }
      final task = HelpTask.fromFirestore(snap);
      if (task.status != TaskStatus.inProgress) {
        throw const TaskOperationException(
          'Można zrezygnować tylko z aktywnego zadania',
        );
      }
      if (task.volunteerId != volunteerId) {
        throw const TaskOperationException(
          'To zadanie nie jest przypisane do Ciebie',
        );
      }
      tx.update(ref, {
        'status': TaskStatus.open.toWire(),
        'volunteer_id': FieldValue.delete(),
        'acceptedAt': FieldValue.delete(),
        'cancelled_by': CancelledBy.volunteer.toWire(),
        'cancel_reason': reason,
        'cancelledAt': FieldValue.serverTimestamp(),
      });
    });
  }
}

/// Thrown by DatabaseService when a status mutation fails its precondition
/// inside a transaction. Carries a Polish, user-facing message.
class TaskOperationException implements Exception {
  final String message;
  const TaskOperationException(this.message);

  @override
  String toString() => message;
}
