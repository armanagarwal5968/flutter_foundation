import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Reusable native crash-reporting wrapper for Flutter applications.
///
/// Crashlytics is intentionally disabled on web, where Firebase Crashlytics is
/// not supported. Consuming apps can safely call every method on every
/// platform.
class FirebaseCrashReporter {
  FirebaseCrashReporter({
    FirebaseCrashlytics? crashlytics,
    bool? supportedOverride,
  }) : _providedCrashlytics = crashlytics,
       _supportedOverride = supportedOverride;

  final FirebaseCrashlytics? _providedCrashlytics;
  final bool? _supportedOverride;
  FirebaseCrashlytics? _crashlytics;

  bool get isSupported =>
      _supportedOverride ??
      (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS));

  Future<void> initialize({bool collectionEnabled = true}) async {
    if (!isSupported) return;
    _crashlytics ??= _providedCrashlytics ?? FirebaseCrashlytics.instance;
    await _crashlytics!.setCrashlyticsCollectionEnabled(collectionEnabled);
  }

  Future<void> identifyUser(
    String? userId, {
    Map<String, Object> attributes = const {},
  }) async {
    final crashlytics = _crashlytics;
    if (crashlytics == null) return;
    await crashlytics.setUserIdentifier(userId ?? 'signed_out');
    for (final entry in attributes.entries) {
      await crashlytics.setCustomKey(entry.key, entry.value);
    }
  }

  Future<void> recordError(
    Object error,
    StackTrace stack, {
    bool fatal = false,
    String reason = 'handled_error',
  }) async {
    await _crashlytics?.recordError(error, stack, fatal: fatal, reason: reason);
  }
}
