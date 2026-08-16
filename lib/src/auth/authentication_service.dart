import 'auth_user.dart';

/// App-neutral contract for authentication providers.
abstract interface class AuthenticationService {
  AuthUser? get currentUser;

  Stream<AuthUser?> get authStateChanges;

  Future<void> initialize();

  /// Starts Google authentication, returning `null` when the user cancels.
  Future<AuthUser?> signInWithGoogle();

  Future<void> signOut();
}
