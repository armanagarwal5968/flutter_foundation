import 'package:alramwarnaga_foundation/alramwarnaga_foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'crash reporter is a safe no-op on unsupported test platforms',
    () async {
      final reporter = FirebaseCrashReporter(supportedOverride: false);

      expect(reporter.isSupported, isFalse);
      await reporter.initialize();
      await reporter.identifyUser('test-user');
      await reporter.recordError(
        StateError('test error'),
        StackTrace.current,
        reason: 'unit_test',
      );
    },
  );
}
