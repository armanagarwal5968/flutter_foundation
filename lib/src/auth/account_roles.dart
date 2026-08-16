/// Stable built-in role identifiers shared by all applications.
abstract final class BuiltInRole {
  static const user = 'user';
  static const admin = 'admin';
}

/// Parses role identifiers from Firebase custom claims.
///
/// All authenticated accounts implicitly receive [BuiltInRole.user]. The
/// singular `role` claim remains supported while existing tokens migrate to
/// the multi-role `roles` claim.
Set<String> parseAccountRoles(Map<String, dynamic>? claims) {
  final roles = <String>{BuiltInRole.user};
  final multiRoleClaim = claims?['roles'];
  if (multiRoleClaim is List) {
    roles.addAll(multiRoleClaim.whereType<String>().where(_isValidRoleId));
  }

  final legacyRoleClaim = claims?['role'];
  if (legacyRoleClaim is String && _isValidRoleId(legacyRoleClaim)) {
    roles.add(legacyRoleClaim);
  }
  return Set.unmodifiable(roles);
}

bool _isValidRoleId(String value) =>
    RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(value);
