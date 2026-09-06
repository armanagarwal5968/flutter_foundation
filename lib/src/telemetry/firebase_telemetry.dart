import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Shared Firebase Analytics and crash/error reporting for Flutter apps.
///
/// Analytics never receives exception messages or stack traces. Native
/// Crashlytics receives full diagnostics on Android and iOS only.
class FirebaseTelemetry {
  FirebaseTelemetry._();

  static final FirebaseTelemetry instance = FirebaseTelemetry._();

  FirebaseAnalytics? _analytics;
  FirebaseCrashlytics? _crashlytics;
  bool _initialized = false;
  bool _handlersInstalled = false;

  bool get _supportsCrashlytics =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  NavigatorObserver? get navigatorObserver =>
      _analytics == null
          ? null
          : FirebaseAnalyticsObserver(analytics: _analytics!);

  Future<void> initialize({bool collectionEnabled = true}) async {
    if (_initialized) return;

    try {
      _analytics = FirebaseAnalytics.instance;
      await _analytics!.setAnalyticsCollectionEnabled(collectionEnabled);
    } on Object catch (error) {
      debugPrint('Analytics initialization deferred: $error');
    }

    if (_supportsCrashlytics) {
      try {
        _crashlytics = FirebaseCrashlytics.instance;
        await _crashlytics!.setCrashlyticsCollectionEnabled(collectionEnabled);
      } on Object catch (error) {
        debugPrint('Crashlytics initialization deferred: $error');
      }
    }
    _initialized = true;
  }

  void installGlobalErrorHandlers() {
    if (_handlersInstalled) return;
    _handlersInstalled = true;

    final previousFlutterHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      if (previousFlutterHandler != null) {
        previousFlutterHandler(details);
      } else {
        FlutterError.presentError(details);
      }
      unawaited(recordFlutterError(details, fatal: true));
    };

    final previousPlatformHandler = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      unawaited(
        recordError(error, stack, fatal: true, context: 'uncaught_async_error'),
      );
      return previousPlatformHandler?.call(error, stack) ?? true;
    };
  }

  Future<void> identifyUser({
    required String? userId,
    Iterable<String> roles = const [],
  }) async {
    final roleValue = (roles.toList()..sort()).join(',');
    try {
      await _analytics?.setUserId(id: userId);
      await _analytics?.setUserProperty(
        name: 'account_roles',
        value: roleValue.isEmpty ? null : roleValue,
      );
    } on Object catch (error) {
      debugPrint('Analytics user update deferred: $error');
    }
    try {
      await _crashlytics?.setUserIdentifier(userId ?? 'signed_out');
      await _crashlytics?.setCustomKey('account_roles', roleValue);
    } on Object catch (error) {
      debugPrint('Crashlytics user update deferred: $error');
    }
  }

  Future<void> logLogin(String method) async {
    try {
      await _analytics?.logLogin(loginMethod: method);
    } on Object catch (error) {
      debugPrint('Analytics login event deferred: $error');
    }
  }

  Future<void> logEvent(String name, {Map<String, Object>? parameters}) async {
    try {
      await _analytics?.logEvent(name: name, parameters: parameters);
    } on Object catch (error) {
      debugPrint('Analytics event deferred: $error');
    }
  }

  Future<void> recordFlutterError(
    FlutterErrorDetails details, {
    bool fatal = false,
  }) => recordError(
    details.exception,
    details.stack ?? StackTrace.current,
    fatal: fatal,
    context: details.context?.toDescription() ?? 'flutter_framework',
  );

  Future<void> recordError(
    Object error,
    StackTrace stack, {
    bool fatal = false,
    String context = 'handled_error',
  }) async {
    debugPrint('[$context] $error\n$stack');

    try {
      await _crashlytics?.recordError(
        error,
        stack,
        fatal: fatal,
        reason: context,
      );
    } on Object catch (reportingError) {
      debugPrint('Crashlytics reporting deferred: $reportingError');
    }

    // Keep web error analytics free of exception text and stack traces, which
    // could accidentally contain personal or health information.
    try {
      await _analytics?.logEvent(
        name: 'app_error',
        parameters: {
          'error_type': error.runtimeType.toString(),
          'error_context': _safeValue(context),
          'fatal': fatal ? 1 : 0,
        },
      );
    } on Object catch (reportingError) {
      debugPrint('Analytics error reporting deferred: $reportingError');
    }
  }

  static String _safeValue(String value) {
    final sanitized = value.replaceAll(RegExp('[^a-zA-Z0-9_]'), '_');
    return sanitized.length <= 80 ? sanitized : sanitized.substring(0, 80);
  }
}
