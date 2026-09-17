import 'package:alramwarnaga_foundation/alramwarnaga_foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats ordinal dates with the requested month style', () {
    expect(formatFriendlyDate(DateTime(2026, 9, 10)), '10th Sept, 2026');
    expect(formatFriendlyDate(DateTime(2026, 1, 1)), '1st Jan, 2026');
    expect(formatFriendlyDate(DateTime(2026, 2, 2)), '2nd Feb, 2026');
    expect(formatFriendlyDate(DateTime(2026, 3, 3)), '3rd Mar, 2026');
    expect(formatFriendlyDate(DateTime(2026, 8, 11)), '11th Aug, 2026');
    expect(formatFriendlyDate(DateTime(2026, 8, 12)), '12th Aug, 2026');
    expect(formatFriendlyDate(DateTime(2026, 8, 13)), '13th Aug, 2026');
    expect(formatFriendlyDate(DateTime(2026, 8, 21)), '21st Aug, 2026');
  });

  test('formats ISO strings and preserves non-date labels', () {
    expect(
      formatFriendlyDateValue('2026-09-10T00:00:00.000'),
      '10th Sept, 2026',
    );
    expect(formatFriendlyDateValue('Postpartum Week 1'), 'Postpartum Week 1');
  });
}
