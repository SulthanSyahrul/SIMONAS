import '../models/role_model.dart';
import '../core/utils/role_display_helper.dart';
import 'supabase_crud_service.dart';

class RoleService extends SupabaseCrudService<RoleRecord> {
  RoleService({super.client}) : super('roles');

  @override
  RoleRecord fromJson(String id, Map<String, dynamic> json) =>
      RoleRecord.fromJson(json, id: id);

  @override
  Map<String, dynamic> toJson(RoleRecord value) => value.toJson();

  String normalizeRole(String role) {
    return normalizeRoleValue(role);
  }

  Future<RoleRecord?> getByRoleName(String roleName) async {
    try {
      final normalizedRole = normalizeRole(roleName);
      final row = await client
          .from(table)
          .select(selectStatement)
          .eq('role', normalizedRole)
          .eq('is_deleted', false)
          .maybeSingle();
      if (row == null) return null;
      return mapResponseSingle(row);
    } catch (error) {
      throw Exception('Failed to fetch role $roleName: $error');
    }
  }

  Future<RoleRecord> ensureRole(String roleName, {String? description}) async {
    final existing = await getByRoleName(roleName);
    if (existing != null) {
      return existing;
    }

    final normalizedRole = normalizeRole(roleName);
    return create(<String, dynamic>{
      'role': normalizedRole,
      'description': description,
      'is_deleted': false,
    });
  }
}
