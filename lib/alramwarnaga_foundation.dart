/// Shared, app-agnostic foundation APIs for Alramwarnaga Flutter projects.
library;

export 'src/auth/auth_user.dart';
export 'src/auth/account_role.dart';
export 'src/auth/authentication_service.dart';
export 'src/auth/google_authentication_service.dart';

/// Metadata for the shared foundation package.
abstract final class AlramwarnagaFoundation {
  /// The package name used by consuming Flutter applications.
  static const packageName = 'alramwarnaga_foundation';
}
