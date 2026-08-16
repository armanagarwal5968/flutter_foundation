/// Roles recognized by consuming applications.
enum AccountRole {
  /// Standard role assigned when no privileged claim is present.
  user,

  /// Privileged application administrator.
  admin;

  /// Parses the Firebase custom claim value, defaulting safely to [user].
  static AccountRole fromClaim(Object? claim) {
    if (claim is String) {
      for (final role in values) {
        if (role.name == claim) return role;
      }
    }
    return user;
  }
}
