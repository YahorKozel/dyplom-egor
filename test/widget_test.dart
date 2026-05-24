import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:window_register/models/task.dart';
import 'package:window_register/models/task_category.dart';
import 'package:window_register/models/user_profile.dart';
import 'package:window_register/models/user_role.dart';

/// Pure copy of the volunteer-side filter so we can test the algorithm without
/// hitting Firestore. Mirrors VolunteerHomeViewModel.refresh().
List<HelpTask> filterByRadius({
  required UserProfile volunteer,
  required List<HelpTask> openTasks,
  required Map<String, UserProfile> seniorsById,
}) {
  const distance = Distance();
  final radiusM = (volunteer.radiusKm ?? 0) * 1000;
  final out = <HelpTask>[];
  for (final t in openTasks) {
    final s = seniorsById[t.seniorId];
    if (s == null) continue;
    final m = distance.as(LengthUnit.Meter, volunteer.homeLocation, s.homeLocation);
    if (m <= radiusM) out.add(t);
  }
  return out;
}

UserProfile _user(String uid, UserRole role, LatLng pos, {double? radius}) =>
    UserProfile(
      uid: uid,
      firstName: uid,
      lastName: '',
      email: '$uid@test.io',
      city: 'Słupsk',
      homeLocation: pos,
      role: role,
      radiusKm: radius,
    );

HelpTask _task(String id, String seniorId) => HelpTask(
      id: id,
      seniorId: seniorId,
      title: 't',
      description: '',
      category: TaskCategory.other,
      status: TaskStatus.open,
    );

void main() {
  group('Volunteer Haversine filter', () {
    // Słupsk centre.
    final volunteerHome = const LatLng(54.4641, 17.0285);
    // ~3 km away.
    final near = const LatLng(54.4900, 17.0450);
    // ~80 km away (Gdańsk).
    final far = const LatLng(54.3520, 18.6466);

    test('keeps tasks whose senior is inside radius_km', () {
      final volunteer = _user('v', UserRole.volunteer, volunteerHome, radius: 10);
      final senior = _user('s', UserRole.senior, near);
      final result = filterByRadius(
        volunteer: volunteer,
        openTasks: [_task('t1', 's')],
        seniorsById: {'s': senior},
      );
      expect(result, hasLength(1));
    });

    test('drops tasks whose senior is outside radius_km', () {
      final volunteer = _user('v', UserRole.volunteer, volunteerHome, radius: 10);
      final senior = _user('s', UserRole.senior, far);
      final result = filterByRadius(
        volunteer: volunteer,
        openTasks: [_task('t1', 's')],
        seniorsById: {'s': senior},
      );
      expect(result, isEmpty);
    });

    test('mixes near and far seniors correctly', () {
      final volunteer = _user('v', UserRole.volunteer, volunteerHome, radius: 10);
      final n = _user('n', UserRole.senior, near);
      final f = _user('f', UserRole.senior, far);
      final result = filterByRadius(
        volunteer: volunteer,
        openTasks: [_task('t-near', 'n'), _task('t-far', 'f')],
        seniorsById: {'n': n, 'f': f},
      );
      expect(result.map((t) => t.id), ['t-near']);
    });
  });

  group('Enum serialization', () {
    test('UserRole round-trips through wire format', () {
      for (final role in UserRole.values) {
        expect(UserRole.fromWire(role.toWire()), role);
      }
    });

    test('TaskStatus round-trips through wire format', () {
      for (final s in TaskStatus.values) {
        expect(TaskStatus.fromWire(s.toWire()), s);
      }
    });

    test('UserRole defaults to senior on unknown input', () {
      expect(UserRole.fromWire(null), UserRole.senior);
      expect(UserRole.fromWire('???'), UserRole.senior);
    });
  });
}
