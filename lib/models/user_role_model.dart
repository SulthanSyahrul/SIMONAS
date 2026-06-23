import 'model_utils.dart';

class UserRoleRecord {
  final String id;
  final String uid;
  final String role;
  final String? roleId;
  final String? description;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final bool isDeleted;

  const UserRoleRecord({
    required this.id,
    required this.uid,
    required this.role,
    this.roleId,
    this.description,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    required this.isDeleted,
  });

  String get userId => uid;

  factory UserRoleRecord.fromJson(Map<String, dynamic> json, {required String id}) {
    return UserRoleRecord(
      id: ModelUtils.string(json['id'], fallback: id),
      uid: ModelUtils.string(json['user_id'] ?? json['uid']),
      role: ModelUtils.string(json['role'] ?? json['role_name'])
          .trim()
          .toLowerCase(),
      roleId: ModelUtils.nullableString(json['role_id']),
      description: ModelUtils.nullableString(json['description']),
      createdAt: ModelUtils.dateTime(json['created_at'] ?? json['createdAt']),
      updatedAt: ModelUtils.dateTime(json['updated_at'] ?? json['updatedAt']),
      deletedAt: ModelUtils.dateTime(json['deleted_at'] ?? json['deletedAt']),
      isDeleted: ModelUtils.boolean(json['is_deleted'] ?? json['isDeleted']),
    );
  }

  Map<String, dynamic> toJson() {
    return ModelUtils.compact(<String, dynamic>{
      'user_id': uid,
      'role_id': roleId,
      'is_deleted': isDeleted,
      'created_at': ModelUtils.isoDateTime(createdAt),
      'updated_at': ModelUtils.isoDateTime(updatedAt),
    });
  }

  UserRoleRecord copyWith({
    String? id,
    String? uid,
    String? role,
    Object? roleId = _userRoleSentinel,
    Object? description = _userRoleSentinel,
    Object? createdAt = _userRoleSentinel,
    Object? updatedAt = _userRoleSentinel,
    Object? deletedAt = _userRoleSentinel,
    bool? isDeleted,
  }) {
    return UserRoleRecord(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      role: role ?? this.role,
      roleId: roleId == _userRoleSentinel ? this.roleId : roleId as String?,
      description: description == _userRoleSentinel
          ? this.description
          : description as String?,
      createdAt: createdAt == _userRoleSentinel
          ? this.createdAt
          : createdAt as DateTime?,
      updatedAt: updatedAt == _userRoleSentinel
          ? this.updatedAt
          : updatedAt as DateTime?,
      deletedAt: deletedAt == _userRoleSentinel
          ? this.deletedAt
          : deletedAt as DateTime?,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}

const Object _userRoleSentinel = Object();
