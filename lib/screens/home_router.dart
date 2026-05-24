import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../models/user_role.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'senior_home_screen.dart';
import 'volunteer_home_screen.dart';

/// Picks the role-appropriate home screen and holds the active profile so
/// child screens (EditHomeScreen, EditProfileScreen) can hand back an
/// updated copy and the relevant home rebuilds with fresh data.
class HomeRouter extends StatefulWidget {
  final UserProfile profile;
  const HomeRouter({super.key, required this.profile});

  @override
  State<HomeRouter> createState() => _HomeRouterState();
}

class _HomeRouterState extends State<HomeRouter> {
  late UserProfile _profile = widget.profile;

  void _replaceProfile(UserProfile next) {
    if (!mounted) return;
    setState(() => _profile = next);
  }

  Future<void> _signOut() async {
    await AuthService().signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return _profile.role == UserRole.volunteer
        ? VolunteerHomeScreen(
            key: ValueKey('volunteer-${_profile.uid}-${_profile.homeLocation.latitude}-${_profile.homeLocation.longitude}-${_profile.radiusKm}'),
            profile: _profile,
            onSignOut: _signOut,
            onProfileUpdated: _replaceProfile,
          )
        : SeniorHomeScreen(
            key: ValueKey('senior-${_profile.uid}'),
            profile: _profile,
            onSignOut: _signOut,
            onProfileUpdated: _replaceProfile,
          );
  }
}
