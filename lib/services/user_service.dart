import '../models/model_utils.dart';
import '../models/user_model.dart';
import '../core/utils/role_display_helper.dart';
import 'role_service.dart';
import 'supabase_crud_service.dart';

class UserService extends SupabaseCrudService<UserRecord> {
  UserService({super.client}) : super('users');

  static const int _liteBatchSize = 50;

  @override
  UserRecord fromJson(String id, Map<String, dynamic> json) =>
      UserRecord.fromJson(json, id: id);

  @override
  Map<String, dynamic> toJson(UserRecord value) => value.toJson();

  @override
  Map<String, dynamic> preparePayload(
    Map<String, dynamic> payload, {
    required bool isUpdate,
  }) {
    final normalized = <String, dynamic>{};
    final uid = ModelUtils.nullableString(payload['uid'] ?? payload['id']);
    final email = ModelUtils.nullableString(payload['email']);
    final username = ModelUtils.nullableString(
      payload['username'] ?? payload['nama'],
    );

    if (uid != null && !isUpdate) {
      normalized['id'] = uid;
    }
    if (email != null || payload.containsKey('email')) {
      normalized['email'] = email;
    }
    if (username != null ||
        payload.containsKey('username') ||
        payload.containsKey('nama')) {
      normalized['username'] = username;
    }

    if (payload.containsKey('active') || payload.containsKey('status')) {
      final active = payload.containsKey('active')
          ? ModelUtils.boolean(payload['active'], fallback: true)
          : ModelUtils.string(
                  payload['status'],
                  fallback: 'aktif',
                ).toLowerCase() ==
                'aktif';
      normalized['is_deleted'] = !active;
    }

    if (payload.containsKey('is_deleted')) {
      final isDeleted = ModelUtils.boolean(payload['is_deleted']);
      normalized['is_deleted'] = isDeleted;
    }

    if (payload.containsKey('created_at')) {
      normalized['created_at'] = payload['created_at'];
    }
    if (payload.containsKey('updated_at')) {
      normalized['updated_at'] = payload['updated_at'];
    }

    return super.preparePayload(normalized, isUpdate: isUpdate);
  }

  Future<List<UserRecord>> getByUserId(String uid) async {
    return _fetchUsersByFilter((query) => query.eq('id', uid.trim()).limit(1));
  }

  Future<List<UserRecord>> getByUserIdLite(String uid) async {
    final normalized = uid.trim();
    if (normalized.isEmpty) {
      return const <UserRecord>[];
    }

    try {
      final rows = await client
          .from(table)
          .select('id, email, username, is_deleted')
          .eq('id', normalized)
          .limit(1);
      return (rows as List<dynamic>)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .map((row) => fromJson(row['id']?.toString() ?? '', row))
          .toList(growable: false);
    } catch (error) {
      throw Exception('Gagal mengambil user ringan $normalized: $error');
    }
  }

  Future<List<UserRecord>> getByUid(String uid) async {
    return getByUserId(uid);
  }

  Future<List<UserRecord>> getByUids(Iterable<String> uids) async {
    final normalized = uids
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (normalized.isEmpty) {
      return const <UserRecord>[];
    }

    try {
      final rows = await client
          .from(table)
          .select(selectStatement)
          .inFilter('id', normalized)
          .eq('is_deleted', false);
      final enriched = await _enrichUsers(
        (rows as List<dynamic>)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList(growable: false),
      );
      return enriched
          .map((row) => fromJson(row['id']?.toString() ?? '', row))
          .toList(growable: false);
    } catch (error) {
      throw Exception('Gagal mengambil user berdasarkan daftar UID: $error');
    }
  }

  Future<List<UserRecord>> getByUidsLite(Iterable<String> uids) async {
    final normalized = uids
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (normalized.isEmpty) {
      return const <UserRecord>[];
    }

    try {
      final recordsById = <String, UserRecord>{};
      for (final batch in _chunkIds(normalized, _liteBatchSize)) {
        final rows = await client
            .from(table)
            .select('id, email, username, is_deleted')
            .inFilter('id', batch)
            .eq('is_deleted', false);
        for (final record in _mapLiteRows(rows as List<dynamic>)) {
          recordsById[record.uid] = record;
        }
      }
      return normalized
          .map((id) => recordsById[id])
          .whereType<UserRecord>()
          .toList(growable: false);
    } catch (error) {
      throw Exception(
        'Gagal mengambil user ringan berdasarkan daftar UID: $error',
      );
    }
  }

  Future<List<UserRecord>> getByEmail(String email) async {
    return _fetchUsersByFilter((query) => query.eq('email', email.trim()));
  }

  Future<List<UserRecord>> getByUsername(String username) async {
    return _fetchUsersByFilter(
      (query) => query.eq('username', username.trim()),
    );
  }

  Future<List<UserRecord>> getByRole(
    String role, {
    bool forceRefresh = false,
  }) async {
    final userIds = await _resolveUserIdsByRole(role);
    if (userIds.isEmpty) {
      return const <UserRecord>[];
    }

    try {
      return getByUids(userIds);
    } catch (error) {
      throw Exception('Gagal mengambil user berdasarkan role $role: $error');
    }
  }

  Future<List<UserRecord>> getByRoleLite(
    String role, {
    bool forceRefresh = false,
  }) async {
    final userIds = await _resolveUserIdsByRole(role);
    if (userIds.isEmpty) {
      return const <UserRecord>[];
    }

    try {
      final normalizedRole = RoleService(client: client).normalizeRole(role);
      final recordsById = <String, UserRecord>{};
      for (final batch in _chunkIds(userIds, _liteBatchSize)) {
        final rows = await client
            .from(table)
            .select('id, email, username, is_deleted')
            .inFilter('id', batch)
            .eq('is_deleted', false);
        for (final record in _mapLiteRows(
          rows as List<dynamic>,
          roleName: normalizedRole,
        )) {
          recordsById[record.uid] = record;
        }
      }
      return userIds
          .map((id) => recordsById[id])
          .whereType<UserRecord>()
          .toList(growable: false);
    } catch (error) {
      throw Exception(
        'Gagal mengambil user ringan berdasarkan role $role: $error',
      );
    }
  }

  Iterable<List<String>> _chunkIds(List<String> ids, int size) sync* {
    if (ids.isEmpty) {
      return;
    }
    for (var i = 0; i < ids.length; i += size) {
      final end = (i + size) < ids.length ? (i + size) : ids.length;
      yield ids.sublist(i, end);
    }
  }

  List<UserRecord> _mapLiteRows(List<dynamic> rows, {String? roleName}) {
    return rows
        .map((row) => Map<String, dynamic>.from(row as Map))
        .map(
          (row) => roleName == null
              ? row
              : <String, dynamic>{...row, 'role': roleName},
        )
        .map((row) => fromJson(row['id']?.toString() ?? '', row))
        .toList(growable: false);
  }

  Future<List<String>> _resolveUserIdsByRole(String role) async {
    try {
      final roleService = RoleService(client: client);
      final requested = roleService.normalizeRole(role);
      final candidates = <String>{requested};
      if (requested == 'kepala_sekolah') {
        candidates.add('kepsek');
      }

      final roleRows = await client
          .from('roles')
          .select('id, role')
          .inFilter('role', candidates.toList(growable: false))
          .eq('is_deleted', false);

      final roleIds = (roleRows as List<dynamic>)
          .map((row) => ModelUtils.integerOrNull((row as Map)['id']))
          .whereType<int>()
          .toList(growable: false);

      if (roleIds.isEmpty) {
        return const <String>[];
      }

      final userRoleRows = await client
          .from('user_roles')
          .select('user_id')
          .inFilter('role_id', roleIds)
          .eq('is_deleted', false);

      final userIds = (userRoleRows as List<dynamic>)
          .map((row) => ModelUtils.nullableString((row as Map)['user_id']))
          .whereType<String>()
          .toSet()
          .toList(growable: false);
      return userIds;
    } catch (error) {
      throw Exception(
        'Gagal menyelesaikan user ID berdasarkan role $role: $error',
      );
    }
  }

  Future<List<UserRecord>> _fetchUsersByFilter(
    dynamic Function(dynamic query) applyQuery,
  ) async {
    try {
      dynamic query = client
          .from(table)
          .select(selectStatement)
          .eq('is_deleted', false);
      query = applyQuery(query);
      final rows = await query;
      final enriched = await _enrichUsers(
        (rows as List<dynamic>)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList(growable: false),
      );
      return enriched
          .map((row) => fromJson(row['id']?.toString() ?? '', row))
          .toList(growable: false);
    } catch (error) {
      throw Exception('Gagal mengambil user dari $table: $error');
    }
  }

  Future<List<Map<String, dynamic>>> _enrichUsers(
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) {
      return rows;
    }

    final userIds = rows
        .map((row) => ModelUtils.string(row['id']))
        .where((id) => id.isNotEmpty)
        .toList(growable: false);

    final guruRows = await client
        .from('guru')
        .select('user_id, nama_lengkap')
        .inFilter('user_id', userIds)
        .eq('is_deleted', false);
    final siswaRows = await client
        .from('siswa')
        .select('user_id, nama')
        .inFilter('user_id', userIds)
        .eq('is_deleted', false);
    final userRoleRows = await client
        .from('user_roles')
        .select('user_id, role_id')
        .inFilter('user_id', userIds)
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

    final guruNames = <String, String>{};
    for (final row in guruRows as List<dynamic>) {
      final record = Map<String, dynamic>.from(row as Map);
      final userId = ModelUtils.string(record['user_id']);
      final name = ModelUtils.nullableString(record['nama_lengkap']);
      if (userId.isNotEmpty && name != null) {
        guruNames[userId] = name;
      }
    }

    final siswaNames = <String, String>{};
    for (final row in siswaRows as List<dynamic>) {
      final record = Map<String, dynamic>.from(row as Map);
      final userId = ModelUtils.string(record['user_id']);
      final name = ModelUtils.nullableString(record['nama']);
      if (userId.isNotEmpty && name != null) {
        siswaNames[userId] = name;
      }
    }

    final rolesByUserId = <String, List<String>>{};
    for (final row in userRoleRows) {
      final record = Map<String, dynamic>.from(row as Map);
      final userId = ModelUtils.string(record['user_id']);
      final roleId = ModelUtils.integerOrNull(record['role_id']);
      if (userId.isEmpty || roleId == null) {
        continue;
      }
      final roleName = rolesById[roleId];
      if (roleName == null) {
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

    return rows
        .map((row) {
          final userId = ModelUtils.string(row['id']);
          final username = ModelUtils.nullableString(row['username']);
          final profileName =
              guruNames[userId] ?? siswaNames[userId] ?? username;
          final userRoles = rolesByUserId[userId] ?? const <String>[];
          return <String, dynamic>{
            ...row,
            'uid': userId,
            'nama': profileName ?? userId,
            'role_name': userRoles.isEmpty ? null : userRoles.first,
            'roles': userRoles,
          };
        })
        .toList(growable: false);
  }

  int _rolePriority(String role) {
    final index = orderedSupportedRoles.indexOf(normalizeRoleValue(role));
    return index < 0 ? 99 : index;
  }
}
