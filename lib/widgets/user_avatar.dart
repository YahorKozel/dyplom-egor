import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/user_profile.dart';

/// Avatar that prefers the user's photo URL but gracefully falls back to
/// the colored initials when the URL is empty, malformed, or fails to load.
class UserAvatar extends StatefulWidget {
  final UserProfile profile;
  final double radius;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const UserAvatar({
    super.key,
    required this.profile,
    this.radius = 24,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> {
  bool _imageFailed = false;
  String? _trackedUrl;

  @override
  Widget build(BuildContext context) {
    final url = widget.profile.photoUrl?.trim();
    // Reset failure state if the URL changes (e.g. user edits profile).
    if (url != _trackedUrl) {
      _trackedUrl = url;
      _imageFailed = false;
    }

    final hasUrl = url != null && url.isNotEmpty;
    final showImage = hasUrl && !_imageFailed;
    final bg = widget.backgroundColor ??
        AppTheme.primaryColor.withValues(alpha: 0.2);
    final fg = widget.foregroundColor ?? AppTheme.primaryColor;

    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: bg,
      backgroundImage: showImage ? NetworkImage(url) : null,
      onBackgroundImageError: showImage
          ? (_, __) {
              if (mounted) setState(() => _imageFailed = true);
            }
          : null,
      child: showImage
          ? null
          : Text(
              widget.profile.initials,
              style: TextStyle(
                fontSize: widget.radius * 0.75,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
    );
  }
}
