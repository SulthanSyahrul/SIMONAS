import 'model_utils.dart';

class NilaiTugasRecord {
  final String id;
  final String tugasId;
  final String siswaUid;
  final double? nilai;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final bool isDeleted;

  const NilaiTugasRecord({
    required this.id,
    required this.tugasId,
    required this.siswaUid,
    this.nilai,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    required this.isDeleted,
  });

  String get siswaId => siswaUid;

  factory NilaiTugasRecord.fromJson(Map<String, dynamic> json, {required String id}) {
    return NilaiTugasRecord(
      id: ModelUtils.string(json['id'], fallback: id),
      tugasId: ModelUtils.string(json['tugas_id'] ?? json['tugasId']),
      siswaUid: ModelUtils.string(
        json['siswa_user_id'] ?? json['siswa_uid'] ?? json['siswa_id'],
      ),
      nilai: ModelUtils.doubleValue(json['nilai']),
      createdAt: ModelUtils.dateTime(json['created_at'] ?? json['createdAt']),
      updatedAt: ModelUtils.dateTime(json['updated_at'] ?? json['updatedAt']),
      deletedAt: ModelUtils.dateTime(json['deleted_at'] ?? json['deletedAt']),
      isDeleted: ModelUtils.boolean(json['is_deleted'] ?? json['isDeleted']),
    );
  }

  Map<String, dynamic> toJson() {
    return ModelUtils.compact(<String, dynamic>{
      'tugas_id': tugasId,
      'siswa_uid': siswaUid,
      'nilai': nilai,
      'is_deleted': isDeleted,
      'created_at': ModelUtils.isoDateTime(createdAt),
      'updated_at': ModelUtils.isoDateTime(updatedAt),
    });
  }

  NilaiTugasRecord copyWith({
    String? id,
    String? tugasId,
    String? siswaUid,
    Object? nilai = _nilaiTugasSentinel,
    Object? createdAt = _nilaiTugasSentinel,
    Object? updatedAt = _nilaiTugasSentinel,
    Object? deletedAt = _nilaiTugasSentinel,
    bool? isDeleted,
  }) {
    return NilaiTugasRecord(
      id: id ?? this.id,
      tugasId: tugasId ?? this.tugasId,
      siswaUid: siswaUid ?? this.siswaUid,
      nilai: nilai == _nilaiTugasSentinel ? this.nilai : nilai as double?,
      createdAt: createdAt == _nilaiTugasSentinel
          ? this.createdAt
          : createdAt as DateTime?,
      updatedAt: updatedAt == _nilaiTugasSentinel
          ? this.updatedAt
          : updatedAt as DateTime?,
      deletedAt: deletedAt == _nilaiTugasSentinel
          ? this.deletedAt
          : deletedAt as DateTime?,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}

const Object _nilaiTugasSentinel = Object();
