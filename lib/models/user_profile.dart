import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

import 'user_role.dart';

class UserProfile {
  final String uid;
  final String firstName;
  final String lastName;
  final String email;
  final String city;
  final String? cityId;
  final LatLng homeLocation;
  final UserRole role;
  final double? radiusKm; // only for VOLUNTEER
  final String? phone;
  final String? photoUrl;
  final DateTime? createdAt;

  UserProfile({
    required this.uid,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.city,
    this.cityId,
    required this.homeLocation,
    required this.role,
    this.radiusKm,
    this.phone,
    this.photoUrl,
    this.createdAt,
  });

  String get fullName => '$firstName $lastName'.trim();

  String get initials {
    final f = firstName.isNotEmpty ? firstName[0] : '';
    final l = lastName.isNotEmpty ? lastName[0] : '';
    final out = '$f$l'.toUpperCase();
    return out.isEmpty ? '?' : out;
  }

  UserProfile copyWith({
    String? firstName,
    String? lastName,
    String? city,
    String? cityId,
    LatLng? homeLocation,
    double? radiusKm,
    String? phone,
    String? photoUrl,
  }) {
    return UserProfile(
      uid: uid,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email,
      city: city ?? this.city,
      cityId: cityId ?? this.cityId,
      homeLocation: homeLocation ?? this.homeLocation,
      role: role,
      radiusKm: radiusKm ?? this.radiusKm,
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'city': city,
      if (cityId != null) 'city_id': cityId,
      'home_location': GeoPoint(homeLocation.latitude, homeLocation.longitude),
      'role': role.toWire(),
      if (role == UserRole.volunteer) 'radius_km': radiusKm,
      if (phone != null) 'phone': phone,
      if (photoUrl != null) 'photo_url': photoUrl,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  /// Partial update — only the fields the user can change post-registration.
  /// Also explicitly deletes the legacy `location` / `coordinates` fields so
  /// any pre-rework document gets cleaned up the next time the user saves.
  Map<String, dynamic> toEditMap() {
    return {
      'first_name': firstName,
      'last_name': lastName,
      'city': city,
      'city_id': cityId,
      'home_location': GeoPoint(homeLocation.latitude, homeLocation.longitude),
      'location': FieldValue.delete(),
      'coordinates': FieldValue.delete(),
      if (role == UserRole.volunteer) 'radius_km': radiusKm,
      'phone': phone,
      'photo_url': photoUrl,
    };
  }

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Prefer the canonical home_location. Old documents written by previous
    // app versions may still have only `location` or `coordinates`; we read
    // those so existing users don't end up at (0, 0) on first launch — the
    // legacy fields get deleted from the doc the next time the user saves
    // through `toEditMap`.
    final geoPoint = (data['home_location'] ??
        data['location'] ??
        data['coordinates']) as GeoPoint?;

    // Legacy single-field 'name' fallback (older docs created before the split).
    final firstName = (data['first_name'] as String?) ??
        ((data['name'] as String?)?.split(' ').first ?? '');
    final lastName = (data['last_name'] as String?) ??
        ((data['name'] as String?)?.split(' ').skip(1).join(' ') ?? '');

    final radiusRaw = data['radius_km'];
    final radius = radiusRaw is num ? radiusRaw.toDouble() : null;

    return UserProfile(
      uid: doc.id,
      firstName: firstName,
      lastName: lastName,
      email: (data['email'] as String?) ?? '',
      city: (data['city'] as String?) ?? '',
      cityId: data['city_id'] as String?,
      homeLocation: geoPoint != null
          ? LatLng(geoPoint.latitude, geoPoint.longitude)
          : const LatLng(0, 0),
      role: UserRole.fromWire(data['role'] as String?),
      radiusKm: radius,
      phone: data['phone'] as String?,
      photoUrl: data['photo_url'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
