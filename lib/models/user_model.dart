import 'model_utils.dart';

class UserRecord {
  final String id;
  final String uid;
  final String nama;
  final String email;
  final String? role;
  final List<String> roles;
  final String? username;
  final String status;
  final bool active;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final bool isDeleted;

  const UserRecord({
    required this.id,
    required this.uid,
    required this.nama,
    required this.email,
    this.role,
    this.roles = const <String>[],
    this.username,
    required this.status,
    required this.active,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    required this.isDeleted,
  });

  factory UserRecord.fromJson(Map<String, dynamic> json, {required String id}) {
    final resolvedId = ModelUtils.string(json['id'], fallback: id);
    final resolvedUsername = ModelUtils.nullableString(
      json['username'] ?? json['nama'] ?? json['name'],
    );
    final resolvedNama = ModelUtils.string(
      json['nama'] ??
          json['profile_name'] ??
          json['guru_nama_lengkap'] ??
          json['siswa_nama'] ??
          resolvedUsername,
      fallback: resolvedId,
    );
    final deleted = ModelUtils.boolean(json['is_deleted'] ?? json['isDeleted']);
    final active = ModelUtils.boolean(json['active'], fallback: !deleted);

    return UserRecord(
      id: resolvedId,
      uid: resolvedId,
      nama: resolvedNama,
      email: ModelUtils.string(json['email']),
      role: ModelUtils.nullableString(json['role'] ?? json['role_name']),
        roles: (json['roles'] is List)
          ? (json['roles'] as List)
            .map((item) => ModelUtils.string(item))
            .where((item) => item.isNotEmpty)
            .toList(growable: false)
          : const <String>[],
      username: resolvedUsername,
      status: ModelUtils.string(
        json['status'],
        fallback: active ? 'aktif' : 'nonaktif',
      ),
      active: active,
      createdAt: ModelUtils.dateTime(json['created_at'] ?? json['createdAt']),
      updatedAt: ModelUtils.dateTime(json['updated_at'] ?? json['updatedAt']),
      deletedAt: ModelUtils.dateTime(json['deleted_at'] ?? json['deletedAt']),
      isDeleted: deleted,
    );
  }

  Map<String, dynamic> toJson() {
    return ModelUtils.compact(<String, dynamic>{
      'id': uid,
      'email': email,
      'username': username ?? nama,
      'is_deleted': !active || isDeleted,
      'created_at': ModelUtils.isoDateTime(createdAt),
      'updated_at': ModelUtils.isoDateTime(updatedAt),
    });
  }

  UserRecord copyWith({
    String? id,
    String? uid,
    String? nama,
    String? email,
    Object? role = _sentinel,
    Object? roles = _sentinel,
    Object? username = _sentinel,
    String? status,
    bool? active,
    Object? createdAt = _sentinel,
    Object? updatedAt = _sentinel,
    Object? deletedAt = _sentinel,
    bool? isDeleted,
  }) {
    return UserRecord(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      nama: nama ?? this.nama,
      email: email ?? this.email,
      role: role == _sentinel ? this.role : role as String?,
        roles: roles == _sentinel
          ? this.roles
          : List<String>.from(roles as List<String>),
      username: username == _sentinel ? this.username : username as String?,
      status: status ?? this.status,
      active: active ?? this.active,
      createdAt: createdAt == _sentinel
          ? this.createdAt
          : createdAt as DateTime?,
      updatedAt: updatedAt == _sentinel
          ? this.updatedAt
          : updatedAt as DateTime?,
      deletedAt: deletedAt == _sentinel
          ? this.deletedAt
          : deletedAt as DateTime?,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}

const Object _sentinel = Object();
