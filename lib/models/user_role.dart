enum UserRole {
  senior,
  volunteer;

  String toWire() => switch (this) {
        UserRole.senior => 'SENIOR',
        UserRole.volunteer => 'VOLUNTEER',
      };

  static UserRole fromWire(String? value) => switch (value) {
        'VOLUNTEER' => UserRole.volunteer,
        _ => UserRole.senior,
      };
}
