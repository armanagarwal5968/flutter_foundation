import 'package:cloud_functions/cloud_functions.dart';

class RoleAssignment {
  const RoleAssignment({
    required this.uid,
    required this.email,
    required this.roles,
    required this.disabled,
    this.displayName,
    this.updatedAt,
    this.updatedBy,
  });

  final String uid;
  final String email;
  final Set<String> roles;
  final bool disabled;
  final String? displayName;
  final DateTime? updatedAt;
  final String? updatedBy;

  factory RoleAssignment.fromJson(Map<String, dynamic> json) {
    final updatedAtMillis = json['updatedAtMillis'];
    return RoleAssignment(
      uid: json['uid'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String?,
      disabled: json['disabled'] as bool? ?? false,
      roles: Set.unmodifiable(
        (json['roles'] as List<dynamic>? ?? const ['user']).cast<String>(),
      ),
      updatedAt:
          updatedAtMillis is int
              ? DateTime.fromMillisecondsSinceEpoch(updatedAtMillis)
              : null,
      updatedBy: json['updatedBy'] as String?,
    );
  }
}

abstract interface class RoleAdministrationService {
  Future<RoleAssignment> findByEmail(String email);

  Future<List<RoleAssignment>> listAssignments();

  Future<RoleAssignment> setRoles({
    required String email,
    required Set<String> roles,
  });
}

class FirebaseRoleAdministrationService implements RoleAdministrationService {
  FirebaseRoleAdministrationService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'asia-south1');

  final FirebaseFunctions _functions;

  @override
  Future<RoleAssignment> findByEmail(String email) async {
    final result = await _functions.httpsCallable('getUserRoleAssignment').call(
      {'email': email},
    );
    return RoleAssignment.fromJson(_map(result.data));
  }

  @override
  Future<List<RoleAssignment>> listAssignments() async {
    final result = await _functions.httpsCallable('listRoleAssignments').call();
    final data = _map(result.data);
    final assignments = data['assignments'] as List<dynamic>? ?? const [];
    return assignments
        .map((item) => RoleAssignment.fromJson(_map(item)))
        .toList(growable: false);
  }

  @override
  Future<RoleAssignment> setRoles({
    required String email,
    required Set<String> roles,
  }) async {
    final result = await _functions.httpsCallable('setUserRoles').call({
      'email': email,
      'roles': roles.toList()..sort(),
    });
    return RoleAssignment.fromJson(_map(result.data));
  }

  Map<String, dynamic> _map(Object? value) =>
      Map<String, dynamic>.from(value! as Map);
}
