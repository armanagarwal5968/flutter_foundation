import 'package:alramwarnaga_foundation/alramwarnaga_foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('compares users by value', () {
    const first = AuthUser(id: '1', email: 'user@example.com');
    const second = AuthUser(id: '1', email: 'user@example.com');

    expect(first, second);
    expect(first.hashCode, second.hashCode);
  });
}
