import 'account_role.dart';

/// App-neutral representation of an authenticated user.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    this.role = AccountRole.user,
    this.displayName,
    this.photoUrl,
  });

  final String id;
  final String? email;
  final AccountRole role;
  final String? displayName;
  final String? photoUrl;

  bool get isAdmin => role == AccountRole.admin;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthUser &&
          id == other.id &&
          email == other.email &&
          role == other.role &&
          displayName == other.displayName &&
          photoUrl == other.photoUrl;

  @override
  int get hashCode => Object.hash(id, email, role, displayName, photoUrl);
}
