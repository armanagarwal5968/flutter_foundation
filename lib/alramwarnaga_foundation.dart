/// Shared, app-agnostic foundation APIs for Alramwarnaga Flutter projects.
library;

export 'src/auth/auth_user.dart';
export 'src/auth/account_roles.dart';
export 'src/auth/authentication_service.dart';
export 'src/auth/google_authentication_service.dart';
export 'src/auth/role_permission_policy.dart';
export 'src/auth/role_administration_service.dart';
export 'src/forms/dynamic_form_definition.dart';
export 'src/forms/dynamic_form_editor.dart';
export 'src/forms/dynamic_form_file_upload.dart';
export 'src/forms/dynamic_form_preview.dart';
export 'src/forms/dynamic_form_repository.dart';
export 'src/forms/dynamic_form_summary.dart';
export 'src/forms/dynamic_form_view.dart';
export 'src/formatting/friendly_date.dart';
export 'src/media/session_media.dart';
export 'src/media/session_resource_viewer.dart';
export 'src/telemetry/firebase_telemetry.dart';
export 'src/telemetry/firebase_crash_reporter.dart';
export 'src/widgets/blocking_progress_overlay.dart';

/// Metadata for the shared foundation package.
abstract final class AlramwarnagaFoundation {
  /// The package name used by consuming Flutter applications.
  static const packageName = 'alramwarnaga_foundation';
}
