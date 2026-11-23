import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';

/// One finished timed operation, as written to every timing sink.
@immutable
class TimingRecord {
  const TimingRecord({
    required this.name,
    required this.total,
    required this.steps,
    required this.outcome,
    required this.attributes,
  });

  /// Operation name, e.g. `sign_in_google` or `fn_bookAppointment`.
  final String name;
  final Duration total;

  /// Step durations in the order they were recorded.
  final Map<String, Duration> steps;

  /// `success`, `error` or `cancelled`.
  final String outcome;
  final Map<String, String> attributes;

  MapEntry<String, Duration>? get slowestStep {
    MapEntry<String, Duration>? slowest;
    for (final entry in steps.entries) {
      if (slowest == null || entry.value > slowest.value) slowest = entry;
    }
    return slowest;
  }

  @override
  String toString() {
    final stepText =
        steps.isEmpty
            ? ''
            : ' (${steps.entries.map((e) => '${e.key} ${e.value.inMilliseconds}ms').join(', ')})';
    final attributeText =
        attributes.isEmpty
            ? ''
            : ' ${attributes.entries.map((e) => '${e.key}=${e.value}').join(' ')}';
    return '[perf] $name ${total.inMilliseconds}ms$stepText $outcome$attributeText';
  }
}

/// A running timed operation. Call [step] after each phase and [stop] once.
class TimedOperation {
  TimedOperation._(this._timing, this.name, Map<String, String> attributes)
    : _attributes = {...attributes} {
    _stopwatch.start();
    _trace = _timing._startTrace(name);
  }

  final PerformanceTiming _timing;
  final String name;
  final Map<String, String> _attributes;
  final Map<String, Duration> _steps = {};
  final Stopwatch _stopwatch = Stopwatch();
  Duration _lastStepAt = Duration.zero;
  Trace? _trace;
  bool _stopped = false;

  Duration get elapsed => _stopwatch.elapsed;
  bool get isStopped => _stopped;

  /// Records the time since the previous step (or since start) as [step].
  /// Use for phases that run one after another.
  void step(String step) {
    if (_stopped) return;
    final now = _stopwatch.elapsed;
    _steps[step] = now - _lastStepAt;
    _lastStepAt = now;
  }

  /// Records the time since start as [mark], without moving the step cursor.
  /// Use for things that load in parallel, e.g. several documents.
  void mark(String mark) {
    if (_stopped || _steps.containsKey(mark)) return;
    _steps[mark] = _stopwatch.elapsed;
  }

  void setAttribute(String key, String value) {
    if (!_stopped) _attributes[key] = value;
  }

  /// Finishes the operation and reports it. Later calls are ignored.
  void stop({String outcome = 'success'}) {
    if (_stopped) return;
    _stopped = true;
    _stopwatch.stop();
    _timing._finish(
      this,
      TimingRecord(
        name: name,
        total: _stopwatch.elapsed,
        steps: Map.unmodifiable(_steps),
        outcome: outcome,
        attributes: Map.unmodifiable(_attributes),
      ),
    );
  }
}

/// App-wide performance timing for sign-in, form submission, uploads, Cloud
/// Function calls and screen loads.
///
/// Every finished operation goes to:
/// * Firebase Performance as a custom trace named after the operation, with
///   `total_ms` and one `<step>_ms` metric per step (Console → Performance →
///   Custom traces).
/// * Firebase Analytics as a `perf_timing` event with the operation, duration,
///   outcome and slowest step (for BigQuery / Explorations), only when the
///   operation took at least [analyticsThreshold] or did not succeed, so
///   Analytics holds a log of lags without an event for every screen load.
/// * The debug console as a `[perf] ...` line (debug and profile builds).
/// * [recent], an in-memory list of the latest records.
///
/// Reporting never throws into the caller and never includes user data:
/// only operation names, step names, durations and the attributes callers
/// pass, which must not contain personal or health information.
class PerformanceTiming {
  PerformanceTiming._();

  static final PerformanceTiming instance = PerformanceTiming._();

  static const int _recentLimit = 100;

  /// Operations at least this slow are also logged to Analytics.
  Duration analyticsThreshold = const Duration(seconds: 1);

  bool _firebaseEnabled = false;
  FirebasePerformance? _performance;
  FirebaseAnalytics? _analytics;
  final Map<String, TimedOperation> _active = {};
  final List<TimingRecord> _recent = [];
  final List<void Function(TimingRecord)> _listeners = [];

  /// Latest finished operations, oldest first.
  List<TimingRecord> get recent => List.unmodifiable(_recent);

  /// Starts sending records to Firebase. Call after Firebase is initialized.
  /// Before this (and in tests) records still reach the console, [recent]
  /// and listeners.
  Future<void> initialize({bool collectionEnabled = true}) async {
    try {
      _performance = FirebasePerformance.instance;
      await _performance!.setPerformanceCollectionEnabled(collectionEnabled);
      _analytics = FirebaseAnalytics.instance;
      _firebaseEnabled = collectionEnabled;
    } on Object catch (error) {
      _firebaseEnabled = false;
      debugPrint('Performance timing initialization deferred: $error');
    }
  }

  void addListener(void Function(TimingRecord record) listener) =>
      _listeners.add(listener);

  void removeListener(void Function(TimingRecord record) listener) =>
      _listeners.remove(listener);

  /// Starts an operation. If [key] is given the operation can be fetched
  /// later with [active], e.g. to finish it from another widget.
  TimedOperation start(
    String name, {
    Map<String, String> attributes = const {},
    String? key,
  }) {
    final operation = TimedOperation._(this, _safeName(name), attributes);
    if (key != null) {
      _active.remove(key)?.stop(outcome: 'replaced');
      _active[key] = operation;
    }
    return operation;
  }

  /// The running operation started with [key], if any.
  TimedOperation? active(String key) {
    final operation = _active[key];
    if (operation == null || operation.isStopped) {
      _active.remove(key);
      return null;
    }
    return operation;
  }

  /// Times [action]. The operation is marked `error` if [action] throws.
  /// [action] gets the operation so it can record steps.
  Future<T> measure<T>(
    String name,
    Future<T> Function(TimedOperation operation) action, {
    Map<String, String> attributes = const {},
  }) async {
    final operation = start(name, attributes: attributes);
    try {
      final result = await action(operation);
      operation.stop();
      return result;
    } on Object {
      operation.stop(outcome: 'error');
      rethrow;
    }
  }

  @visibleForTesting
  void resetForTesting() {
    _active.clear();
    _recent.clear();
    _listeners.clear();
    _firebaseEnabled = false;
    _performance = null;
    _analytics = null;
  }

  Trace? _startTrace(String name) {
    if (!_firebaseEnabled) return null;
    try {
      final trace = _performance!.newTrace(name);
      unawaited(trace.start().catchError((Object _) {}));
      return trace;
    } on Object {
      return null;
    }
  }

  void _finish(TimedOperation operation, TimingRecord record) {
    _active.removeWhere((_, value) => identical(value, operation));
    _recent.add(record);
    if (_recent.length > _recentLimit) _recent.removeAt(0);
    if (!kReleaseMode) debugPrint(record.toString());
    for (final listener in List.of(_listeners)) {
      try {
        listener(record);
      } on Object catch (error) {
        debugPrint('Performance timing listener failed: $error');
      }
    }
    unawaited(_report(operation._trace, record));
  }

  Future<void> _report(Trace? trace, TimingRecord record) async {
    if (!_firebaseEnabled) return;
    if (trace == null) {
      // Started before Firebase was ready (e.g. app_start): the trace's own
      // duration is meaningless, but total_ms and the step metrics are right.
      try {
        trace = _performance!.newTrace(record.name);
        await trace.start();
      } on Object {
        trace = null;
      }
    }
    if (trace != null) {
      try {
        trace.setMetric('total_ms', record.total.inMilliseconds);
        for (final step in record.steps.entries.take(30)) {
          trace.setMetric(
            _safeName('${step.key}_ms'),
            step.value.inMilliseconds,
          );
        }
        trace.putAttribute('outcome', record.outcome);
        for (final attribute in record.attributes.entries.take(4)) {
          trace.putAttribute(
            _safeName(attribute.key, maxLength: 40),
            _safeValue(attribute.value),
          );
        }
        await trace.stop();
      } on Object catch (error) {
        debugPrint('Performance trace deferred: $error');
      }
    }
    if (record.outcome == 'success' && record.total < analyticsThreshold) {
      return;
    }
    try {
      final slowest = record.slowestStep;
      await _analytics?.logEvent(
        name: 'perf_timing',
        parameters: {
          'operation': _safeValue(record.name),
          'duration_ms': record.total.inMilliseconds,
          'outcome': record.outcome,
          if (slowest != null) 'slowest_step': _safeValue(slowest.key),
          if (slowest != null) 'slowest_step_ms': slowest.value.inMilliseconds,
        },
      );
    } on Object catch (error) {
      debugPrint('Performance analytics deferred: $error');
    }
  }

  /// Firebase trace and metric names: no leading underscore, at most 100
  /// characters, letters, digits and underscores only.
  static String _safeName(String value, {int maxLength = 100}) {
    var sanitized = value.trim().replaceAll(RegExp('[^a-zA-Z0-9_]'), '_');
    sanitized = sanitized.replaceFirst(RegExp('^_+'), '');
    if (sanitized.isEmpty) sanitized = 'unnamed';
    return sanitized.length <= maxLength
        ? sanitized
        : sanitized.substring(0, maxLength);
  }

  static String _safeValue(String value) {
    final trimmed = value.trim();
    return trimmed.length <= 100 ? trimmed : trimmed.substring(0, 100);
  }
}

/// Times every Cloud Function call made through it as `fn_<name>`.
extension TimedCloudFunctions on FirebaseFunctions {
  Future<HttpsCallableResult<T>> callTimed<T>(String name, [Object? data]) =>
      PerformanceTiming.instance.measure(
        'fn_$name',
        (_) => httpsCallable(name).call<T>(data),
      );
}

/// Times how long a stream takes to deliver its first event after it is
/// listened to, as [name]. Each listen is timed separately.
extension TimedFirstEvent<T> on Stream<T> {
  Stream<T> timeFirstEvent(
    String name, {
    Map<String, String> attributes = const {},
  }) {
    final source = this;
    late StreamController<T> controller;
    StreamSubscription<T>? subscription;
    TimedOperation? operation;
    void onListen() {
      final timed =
          operation = PerformanceTiming.instance.start(
            name,
            attributes: attributes,
          );
      subscription = source.listen(
        (event) {
          timed.stop();
          controller.add(event);
        },
        onError: (Object error, StackTrace stack) {
          timed.stop(outcome: 'error');
          controller.addError(error, stack);
        },
        onDone: () {
          timed.stop(outcome: 'cancelled');
          controller.close();
        },
      );
    }

    Future<void> onCancel() async {
      operation?.stop(outcome: 'cancelled');
      await subscription?.cancel();
    }

    controller =
        source.isBroadcast
            ? StreamController<T>.broadcast(
              onListen: onListen,
              onCancel: onCancel,
            )
            : StreamController<T>(
              onListen: onListen,
              onPause: () => subscription?.pause(),
              onResume: () => subscription?.resume(),
              onCancel: onCancel,
            );
    return controller.stream;
  }
}
