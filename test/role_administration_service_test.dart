import 'package:alramwarnaga_foundation/alramwarnaga_foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a callable role assignment response', () {
    final assignment = RoleAssignment.fromJson({
      'uid': 'uid-1',
      'email': 'user@example.com',
      'displayName': 'User',
      'disabled': false,
      'roles': ['user', 'role_1'],
      'updatedAtMillis': 1000,
      'updatedBy': 'admin-uid',
    });

    expect(assignment.uid, 'uid-1');
    expect(assignment.roles, {'user', 'role_1'});
    expect(assignment.updatedAt, DateTime.fromMillisecondsSinceEpoch(1000));
  });
}
