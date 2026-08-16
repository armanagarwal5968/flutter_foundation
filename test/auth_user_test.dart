import 'package:alramwarnaga_foundation/alramwarnaga_foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('compares users and role sets by value', () {
    const first = AuthUser(
      id: '1',
      email: 'user@example.com',
      roles: {'user', 'role_1'},
    );
    const second = AuthUser(
      id: '1',
      email: 'user@example.com',
      roles: {'role_1', 'user'},
    );

    expect(first, second);
    expect(first.hashCode, second.hashCode);
  });

  test('defaults to the user role', () {
    const user = AuthUser(id: '1', email: 'user@example.com');

    expect(user.roles, {BuiltInRole.user});
    expect(user.isAdmin, isFalse);
  });

  test('parses multiple and legacy role claims', () {
    expect(
      parseAccountRoles({
        'roles': ['admin', 'role_1', 'invalid-role'],
        'role': 'role_2',
      }),
      {'user', 'admin', 'role_1', 'role_2'},
    );
  });

  test('permission policy combines roles and grants admin all access', () {
    const policy = RolePermissionPolicy<String>(
      permissionsByRole: {
        'user': {'use_app'},
        'role_1': {'manage_whitelist'},
        'role_2': {'submit_forms'},
      },
    );
    const specialist = AuthUser(
      id: '1',
      email: null,
      roles: {'user', 'role_1'},
    );
    const admin = AuthUser(id: '2', email: null, roles: {'user', 'admin'});

    expect(policy.allows(specialist, 'manage_whitelist'), isTrue);
    expect(policy.allows(specialist, 'submit_forms'), isFalse);
    expect(policy.allows(admin, 'submit_forms'), isTrue);
  });
}
