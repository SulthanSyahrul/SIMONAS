import 'model_utils.dart';

class RoleRecord {
  final String id;
  final String role;
  final String? description;
  final bool isDeleted;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const RoleRecord({
    required this.id,
    required this.role,
    this.description,
    required this.isDeleted,
    this.createdAt,
    this.updatedAt,
  });

  factory RoleRecord.fromJson(Map<String, dynamic> json, {required String id}) {
    return RoleRecord(
      id: ModelUtils.string(json['id'], fallback: id),
      role: ModelUtils.string(json['role']).trim().toLowerCase(),
      description: ModelUtils.nullableString(json['description']),
      isDeleted: ModelUtils.boolean(json['is_deleted'] ?? json['isDeleted']),
      createdAt: ModelUtils.dateTime(json['created_at'] ?? json['createdAt']),
      updatedAt: ModelUtils.dateTime(json['updated_at'] ?? json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return ModelUtils.compact(<String, dynamic>{
      'role': role,
      'description': description,
      'is_deleted': isDeleted,
      'created_at': ModelUtils.isoDateTime(createdAt),
      'updated_at': ModelUtils.isoDateTime(updatedAt),
    });
  }

  RoleRecord copyWith({
    String? id,
    String? role,
    Object? description = _roleSentinel,
    bool? isDeleted,
    Object? createdAt = _roleSentinel,
    Object? updatedAt = _roleSentinel,
  }) {
    return RoleRecord(
      id: id ?? this.id,
      role: role ?? this.role,
      description: description == _roleSentinel
          ? this.description
          : description as String?,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt == _roleSentinel
          ? this.createdAt
          : createdAt as DateTime?,
      updatedAt: updatedAt == _roleSentinel
          ? this.updatedAt
          : updatedAt as DateTime?,
    );
  }
}

const Object _roleSentinel = Object();
