import 'dart:async';

import 'package:alramwarnaga_foundation/src/telemetry/performance_timing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final timing = PerformanceTiming.instance;
  late List<TimingRecord> records;

  setUp(() {
    timing.resetForTesting();
    records = [];
    timing.addListener(records.add);
  });

  tearDown(timing.resetForTesting);

  test('step records time since the previous step', () async {
    final operation = timing.start('sign_in_google');
    await Future<void>.delayed(const Duration(milliseconds: 30));
    operation.step('google_popup');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    operation.step('load_claims');
    operation.stop();

    final record = records.single;
    expect(record.name, 'sign_in_google');
    expect(record.outcome, 'success');
    expect(record.steps.keys, ['google_popup', 'load_claims']);
    expect(
      record.steps['google_popup']!.inMilliseconds,
      greaterThanOrEqualTo(25),
    );
    expect(
      record.steps['load_claims']!,
      lessThan(record.steps['google_popup']!),
    );
    expect(record.slowestStep!.key, 'google_popup');
    expect(record.total, greaterThanOrEqualTo(record.steps['google_popup']!));
  });

  test('mark records time since start for parallel loads', () async {
    final operation = timing.start('post_login_load');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    operation.mark('account_status_doc');
    operation.mark('account_status_doc');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    operation.mark('mother_profile_doc');
    operation.stop();

    final steps = records.single.steps;
    expect(
      steps['mother_profile_doc']!,
      greaterThan(steps['account_status_doc']!),
    );
    expect(
      steps['mother_profile_doc']!.inMilliseconds,
      greaterThanOrEqualTo(35),
    );
  });

  test('stop only reports once', () {
    timing.start('form_submit')
      ..stop()
      ..stop(outcome: 'error');
    expect(records.single.outcome, 'success');
  });

  test('measure marks thrown errors and rethrows them', () async {
    await expectLater(
      timing.measure('fn_bookAppointment', (_) async => throw StateError('x')),
      throwsStateError,
    );
    expect(records.single.outcome, 'error');
  });

  test('measure returns the action result', () async {
    final value = await timing.measure('fn_ping', (_) async => 42);
    expect(value, 42);
    expect(records.single.outcome, 'success');
  });

  test('keyed operations can be finished elsewhere', () {
    timing.start('post_login_load', key: 'post_login');
    timing.active('post_login')!
      ..setAttribute('destination', 'staff_shell')
      ..stop();
    expect(timing.active('post_login'), isNull);
    expect(records.single.attributes['destination'], 'staff_shell');
  });

  test('restarting a key replaces the previous operation', () {
    timing.start('post_login_load', key: 'post_login');
    timing.start('post_login_load', key: 'post_login');
    expect(records.single.outcome, 'replaced');
    expect(timing.active('post_login'), isNotNull);
  });

  test('names are made safe for Firebase', () {
    timing.start('_load form/catalog').stop();
    expect(records.single.name, 'load_form_catalog');
  });

  test('recent keeps the latest records', () {
    for (var i = 0; i < 105; i++) {
      timing.start('op_$i').stop();
    }
    expect(timing.recent, hasLength(100));
    expect(timing.recent.first.name, 'op_5');
    expect(timing.recent.last.name, 'op_104');
  });

  group('timeFirstEvent', () {
    test('times only the first event and passes events through', () async {
      final source = StreamController<int>();
      final events = <int>[];
      final subscription = source.stream
          .timeFirstEvent('load_journey')
          .listen(events.add);

      await Future<void>.delayed(const Duration(milliseconds: 20));
      source
        ..add(1)
        ..add(2);
      await Future<void>.delayed(Duration.zero);

      expect(events, [1, 2]);
      expect(records.single.name, 'load_journey');
      expect(records.single.outcome, 'success');
      expect(records.single.total.inMilliseconds, greaterThanOrEqualTo(15));
      await subscription.cancel();
      await source.close();
    });

    test('reports errors before the first event', () async {
      final source = StreamController<int>();
      final errors = <Object>[];
      final subscription = source.stream
          .timeFirstEvent('load_appointments')
          .listen((_) {}, onError: errors.add);
      source.addError(StateError('denied'));
      await Future<void>.delayed(Duration.zero);

      expect(errors.single, isStateError);
      expect(records.single.outcome, 'error');
      await subscription.cancel();
      await source.close();
    });

    test('reports cancelled when left before loading', () async {
      final source = StreamController<int>();
      final subscription = source.stream
          .timeFirstEvent('load_staff_tasks')
          .listen((_) {});
      await subscription.cancel();

      expect(records.single.outcome, 'cancelled');
      await source.close();
    });

    test('times each listen separately', () async {
      final stream = Stream<int>.value(1).timeFirstEvent('load_forms');
      await stream.first;
      final again = Stream<int>.value(1).timeFirstEvent('load_forms');
      await again.first;
      expect(records.where((r) => r.name == 'load_forms'), hasLength(2));
    });
  });

  test('toString is a readable console line', () {
    final record = TimingRecord(
      name: 'sign_in_google',
      total: const Duration(milliseconds: 2100),
      steps: const {
        'google_popup': Duration(milliseconds: 1900),
        'load_claims': Duration(milliseconds: 200),
      },
      outcome: 'success',
      attributes: const {'flow': 'redirect'},
    );
    expect(
      record.toString(),
      '[perf] sign_in_google 2100ms (google_popup 1900ms, load_claims 200ms) '
      'success flow=redirect',
    );
  });
}
