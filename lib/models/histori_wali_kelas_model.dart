import 'model_utils.dart';

class HistoriWaliKelasRecord {
  final String id;
  final String guruUid;
  final String kelasId;
  final String tahunAjaranId;
  final bool isAktif;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final bool isDeleted;

  const HistoriWaliKelasRecord({
    required this.id,
    required this.guruUid,
    required this.kelasId,
    required this.tahunAjaranId,
    required this.isAktif,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    required this.isDeleted,
  });

  factory HistoriWaliKelasRecord.fromJson(Map<String, dynamic> json, {required String id}) {
    final deleted = ModelUtils.boolean(json['is_deleted'] ?? json['isDeleted']);
    return HistoriWaliKelasRecord(
      id: ModelUtils.string(json['id'], fallback: id),
      guruUid: ModelUtils.string(
        json['guru_user_id'] ?? json['guru_uid'] ?? json['guruId'],
      ),
      kelasId: ModelUtils.string(json['kelas_id'] ?? json['kelasId']),
      tahunAjaranId: ModelUtils.string(
        json['tahun_ajaran_id'] ?? json['tahunAjaranId'],
      ),
      isAktif: ModelUtils.boolean(
        json['is_aktif'] ?? json['isAktif'],
        fallback: !deleted,
      ),
      createdAt: ModelUtils.dateTime(json['created_at'] ?? json['createdAt']),
      updatedAt: ModelUtils.dateTime(json['updated_at'] ?? json['updatedAt']),
      deletedAt: ModelUtils.dateTime(json['deleted_at'] ?? json['deletedAt']),
      isDeleted: deleted,
    );
  }

  Map<String, dynamic> toJson() {
    return ModelUtils.compact(<String, dynamic>{
      'guru_uid': guruUid,
      'kelas_id': kelasId,
      'tahun_ajaran_id': tahunAjaranId,
      'is_deleted': isDeleted || !isAktif,
      'created_at': ModelUtils.isoDateTime(createdAt),
      'updated_at': ModelUtils.isoDateTime(updatedAt),
    });
  }

  HistoriWaliKelasRecord copyWith({
    String? id,
    String? guruUid,
    String? kelasId,
    String? tahunAjaranId,
    bool? isAktif,
    Object? createdAt = _historiWaliSentinel,
    Object? updatedAt = _historiWaliSentinel,
    Object? deletedAt = _historiWaliSentinel,
    bool? isDeleted,
  }) {
    return HistoriWaliKelasRecord(
      id: id ?? this.id,
      guruUid: guruUid ?? this.guruUid,
      kelasId: kelasId ?? this.kelasId,
      tahunAjaranId: tahunAjaranId ?? this.tahunAjaranId,
      isAktif: isAktif ?? this.isAktif,
      createdAt: createdAt == _historiWaliSentinel
          ? this.createdAt
          : createdAt as DateTime?,
      updatedAt: updatedAt == _historiWaliSentinel
          ? this.updatedAt
          : updatedAt as DateTime?,
      deletedAt: deletedAt == _historiWaliSentinel
          ? this.deletedAt
          : deletedAt as DateTime?,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}

const Object _historiWaliSentinel = Object();
