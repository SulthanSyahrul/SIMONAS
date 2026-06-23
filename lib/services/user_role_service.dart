import '../models/model_utils.dart';
import '../models/user_role_model.dart';
import '../core/utils/role_display_helper.dart';
import 'role_service.dart';
import 'supabase_crud_service.dart';

class UserRoleService extends SupabaseCrudService<UserRoleRecord> {
  UserRoleService({super.client}) : super('user_roles');

  RoleService get _roleService => RoleService(client: client);

  @override
  UserRoleRecord fromJson(String id, Map<String, dynamic> json) =>
      UserRoleRecord.fromJson(json, id: id);

  @override
  Map<String, dynamic> toJson(UserRoleRecord value) => value.toJson();

  String normalizeRole(String role) {
    return normalizeRoleValue(role);
  }

  @override
  Future<List<Map<String, dynamic>>> transformRows(
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) {
      return rows;
    }

    final roleIds = rows
        .map((row) => ModelUtils.integerOrNull(row['role_id']))
        .whereType<int>()
        .toSet()
        .toList(growable: false);

    final rolesById = <int, Map<String, dynamic>>{};
    if (roleIds.isNotEmpty) {
      final roleRows = await client
          .from('roles')
          .select('id, role, description')
          .inFilter('id', roleIds)
          .eq('is_deleted', false);
      for (final row in roleRows as List<dynamic>) {
        final record = Map<String, dynamic>.from(row as Map);
        final roleId = ModelUtils.integerOrNull(record['id']);
        if (roleId != null) {
          rolesById[roleId] = record;
        }
      }
    }

    return rows.map((row) {
      final roleId = ModelUtils.integerOrNull(row['role_id']);
      final role = roleId == null ? null : rolesById[roleId];
      return <String, dynamic>{
        ...row,
        'uid': row['user_id'],
        'role_name': role?['role'],
        'role': role?['role'],
        'description': role?['description'],
      };
    }).toList(growable: false);
  }

  @override
  Future<UserRoleRecord> create(dynamic value, {String? id}) async {
    final payload = await _normalizePayloadAsync(payloadFromValue(value));
    return super.create(payload, id: id);
  }

  @override
  Future<UserRoleRecord> update(String id, dynamic value) async {
    final payload = await _normalizePayloadAsync(payloadFromValue(value));
    return super.update(id, payload);
  }

  Future<List<UserRoleRecord>> getByUidDirect(String uid) async {
    try {
      final rows = await client
          .from(table)
          .select(selectStatement)
          .eq('user_id', uid.trim())
          .eq('is_deleted', false);
      return mapResponseList(rows);
    } catch (error) {
      throw Exception('Gagal mengambil role user $uid: $error');
    }
  }

  Future<List<UserRoleRecord>> getByUid(String uid) async {
    return getByUidDirect(uid);
  }

  Future<Map<String, List<String>>> getRolesByUids(
    Iterable<String> uids,
  ) async {
    final normalized = uids
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (normalized.isEmpty) {
      return const <String, List<String>>{};
    }

    try {
      final userRoleRows = await client
          .from(table)
          .select('user_id, role_id')
          .inFilter('user_id', normalized)
          .eq('is_deleted', false);

      final roleIds = (userRoleRows as List<dynamic>)
          .map((row) => ModelUtils.integerOrNull((row as Map)['role_id']))
          .whereType<int>()
          .toSet()
          .toList(growable: false);

      final rolesById = <int, String>{};
      if (roleIds.isNotEmpty) {
        final roleRows = await client
            .from('roles')
            .select('id, role')
            .inFilter('id', roleIds)
            .eq('is_deleted', false);
        for (final row in roleRows as List<dynamic>) {
          final record = Map<String, dynamic>.from(row as Map);
          final roleId = ModelUtils.integerOrNull(record['id']);
          if (roleId != null) {
            rolesById[roleId] = ModelUtils.string(record['role']);
          }
        }
      }

      final rolesByUserId = <String, List<String>>{};
      for (final row in userRoleRows) {
        final record = Map<String, dynamic>.from(row as Map);
        final userId = ModelUtils.string(record['user_id']);
        final roleId = ModelUtils.integerOrNull(record['role_id']);
        final roleName = roleId == null ? null : rolesById[roleId];
        if (userId.isEmpty || roleName == null) {
          continue;
        }
        final list = rolesByUserId.putIfAbsent(userId, () => <String>[]);
        if (!list.contains(roleName)) {
          list.add(roleName);
        }
      }

      for (final entry in rolesByUserId.entries) {
        entry.value.sort((a, b) => _rolePriority(a).compareTo(_rolePriority(b)));
      }

      return rolesByUserId;
    } catch (error) {
      throw Exception(
        'Gagal mengambil role berdasarkan daftar UID: $error',
      );
    }
  }

  Future<UserRoleRecord> assignRole({required String uid, required String role}) async {
    try {
      final normalizedRole = normalizeRole(role);
      final resolvedRole = await _roleService.ensureRole(normalizedRole);
      final roleId = int.parse(resolvedRole.id);

      final existing = await client
          .from(table)
          .select(selectStatement)
          .eq('user_id', uid.trim())
          .eq('role_id', roleId)
          .limit(1);

      if ((existing as List<dynamic>).isNotEmpty) {
        final row = Map<String, dynamic>.from(existing.first as Map);
        if (ModelUtils.boolean(row['is_deleted'])) {
          return update(
            row['id'].toString(),
            <String, dynamic>{'is_deleted': false},
          );
        }
        return await mapResponseSingle(row);
      }

      return create(<String, dynamic>{
        'user_id': uid.trim(),
        'role_id': roleId,
        'is_deleted': false,
      });
    } catch (error) {
      throw Exception('Gagal menetapkan role $role untuk user $uid: $error');
    }
  }

  Future<List<UserRoleRecord>> syncRoles({
    required String uid,
    required List<String> roles,
  }) async {
    final normalizedRoles = sortRoleValues(roles);
    if (normalizedRoles.isEmpty) {
      throw Exception('Minimal satu role harus dipilih.');
    }

    final resolvedRoles = <String, int>{};
    for (final role in normalizedRoles) {
      final record = await _roleService.ensureRole(role);
      resolvedRoles[role] = int.parse(record.id);
    }

    final existingRows = await client
        .from(table)
        .select('id, role_id, is_deleted')
        .eq('user_id', uid.trim());

    final existingByRoleId = <int, Map<String, dynamic>>{};
    for (final row in existingRows as List<dynamic>) {
      final record = Map<String, dynamic>.from(row as Map);
      final roleId = ModelUtils.integerOrNull(record['role_id']);
      if (roleId != null) {
        existingByRoleId[roleId] = record;
      }
    }

    final results = <UserRoleRecord>[];
    for (final entry in resolvedRoles.entries) {
      final roleId = entry.value;
      final existing = existingByRoleId.remove(roleId);
      if (existing != null) {
        final isDeleted = ModelUtils.boolean(existing['is_deleted']);
        if (isDeleted) {
          results.add(
            await update(
              existing['id'].toString(),
              <String, dynamic>{'is_deleted': false},
            ),
          );
        } else {
          results.add(await mapResponseSingle(existing));
        }
        continue;
      }

      results.add(
        await create(<String, dynamic>{
          'user_id': uid.trim(),
          'role_id': roleId,
          'is_deleted': false,
        }),
      );
    }

    for (final row in existingByRoleId.values) {
      if (ModelUtils.boolean(row['is_deleted'])) {
        continue;
      }
      await update(row['id'].toString(), <String, dynamic>{'is_deleted': true});
    }

    return results;
  }

  Future<Map<String, dynamic>> _normalizePayloadAsync(
    Map<String, dynamic> payload,
  ) async {
    final normalized = <String, dynamic>{};
    final userId = ModelUtils.nullableString(payload['user_id'] ?? payload['uid']);
    if (userId != null) {
      normalized['user_id'] = userId;
    }

    if (payload['role_id'] != null) {
      normalized['role_id'] = normalizeIdValue(payload['role_id']);
    } else {
      final roleName = ModelUtils.nullableString(payload['role'] ?? payload['role_name']);
      if (roleName != null) {
        final role = await _roleService.ensureRole(roleName);
        normalized['role_id'] = int.parse(role.id);
      }
    }

    if (payload.containsKey('is_deleted')) {
      normalized['is_deleted'] = ModelUtils.boolean(payload['is_deleted']);
    }

    return normalized;
  }

  int _rolePriority(String role) {
    final index = orderedSupportedRoles.indexOf(normalizeRoleValue(role));
    return index < 0 ? 99 : index;
  }
}
