import 'package:alramwarnaga_foundation/alramwarnaga_foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('compares users by value', () {
    const first = AuthUser(id: '1', email: 'user@example.com');
    const second = AuthUser(id: '1', email: 'user@example.com');

    expect(first, second);
    expect(first.hashCode, second.hashCode);
  });

  test('defaults to the user role', () {
    const user = AuthUser(id: '1', email: 'user@example.com');

    expect(user.role, AccountRole.user);
    expect(user.isAdmin, isFalse);
  });

  test('parses admin and safely defaults unknown claims', () {
    expect(AccountRole.fromClaim('admin'), AccountRole.admin);
    expect(AccountRole.fromClaim('unknown'), AccountRole.user);
    expect(AccountRole.fromClaim(null), AccountRole.user);
  });
}
