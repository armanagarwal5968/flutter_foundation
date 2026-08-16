import 'package:flutter/foundation.dart';

import 'account_roles.dart';

/// App-neutral representation of an authenticated user.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    this.roles = const {BuiltInRole.user},
    this.displayName,
    this.photoUrl,
  });

  final String id;
  final String? email;
  final Set<String> roles;
  final String? displayName;
  final String? photoUrl;

  bool hasRole(String role) => roles.contains(role);

  bool get isAdmin => hasRole(BuiltInRole.admin);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthUser &&
          id == other.id &&
          email == other.email &&
          setEquals(roles, other.roles) &&
          displayName == other.displayName &&
          photoUrl == other.photoUrl;

  @override
  int get hashCode => Object.hash(
    id,
    email,
    Object.hashAllUnordered(roles),
    displayName,
    photoUrl,
  );
}
