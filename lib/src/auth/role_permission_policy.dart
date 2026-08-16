import 'account_roles.dart';
import 'auth_user.dart';

/// Maps application role identifiers to application-specific permissions.
class RolePermissionPolicy<Permission> {
  const RolePermissionPolicy({
    required this.permissionsByRole,
    this.adminRole = BuiltInRole.admin,
  });

  final Map<String, Set<Permission>> permissionsByRole;
  final String adminRole;

  bool allows(AuthUser? user, Permission permission) {
    if (user == null) return false;
    if (user.hasRole(adminRole)) return true;
    return user.roles.any(
      (role) => permissionsByRole[role]?.contains(permission) ?? false,
    );
  }

  Set<Permission> permissionsFor(AuthUser? user) {
    if (user == null) return const {};
    if (user.hasRole(adminRole)) {
      return Set.unmodifiable(
        permissionsByRole.values.expand((permissions) => permissions),
      );
    }
    return Set.unmodifiable(
      user.roles.expand((role) => permissionsByRole[role] ?? const {}),
    );
  }
}
