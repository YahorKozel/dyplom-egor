/// Centralized character limits for every persisted text field so we never
/// accidentally write multi-MB blobs into Firestore (a single document is
/// capped at 1 MiB, and dense lists need to stay light to render fast).
class InputLimits {
  // ── Tasks ──
  static const int taskTitle = 80;
  static const int taskDescription = 1000;
  static const int cancelReason = 200;

  // ── Profile ──
  static const int firstName = 50;
  static const int lastName = 50;
  static const int phone = 25;
  static const int photoUrl = 500;
  static const int cityName = 80;

  // ── Cards (display) ──
  /// Description lines on the feed card before truncating with ellipsis —
  /// the full text is reachable by tapping the card to open the detail.
  static const int feedDescriptionLines = 2;
}

/// Validators reused by multiple forms.
class InputValidators {
  /// Accepts an empty string (caller decides if the field is required) and
  /// rejects strings with unusual characters. The phone is stored as the
  /// user typed it (formatting preserved), only validated for safety.
  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final v = value.trim();
    if (v.length > InputLimits.phone) {
      return 'Numer telefonu jest za długi';
    }
    final allowed = RegExp(r'^[+0-9\s\-()]+$');
    if (!allowed.hasMatch(v)) {
      return 'Numer może zawierać tylko cyfry, spacje i znaki +-()';
    }
    final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 9) return 'Numer telefonu jest za krótki';
    return null;
  }

  /// Accepts only http(s) URLs to prevent javascript: / data: shenanigans
  /// when we eventually surface the image somewhere outside `Image.network`.
  static String? photoUrl(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final v = value.trim();
    if (v.length > InputLimits.photoUrl) return 'URL jest za długi';
    final uri = Uri.tryParse(v);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      return 'Wpisz poprawny adres URL';
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return 'URL musi zaczynać się od http:// lub https://';
    }
    return null;
  }
}
