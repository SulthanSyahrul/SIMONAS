import 'model_utils.dart';

class KelasSiswaRecord {
  final String id;
  final String siswaId;
  final String? siswaRecordId;
  final String? siswaNama;
  final String? siswaNis;
  final String kelasId;
  final String tahunAjaranId;
  final String status;
  final bool isDeleted;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  const KelasSiswaRecord({
    required this.id,
    required this.siswaId,
    this.siswaRecordId,
    this.siswaNama,
    this.siswaNis,
    required this.kelasId,
    required this.tahunAjaranId,
    required this.status,
    required this.isDeleted,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  bool get statusAktif => status.toLowerCase() == 'aktif';

  factory KelasSiswaRecord.fromJson(Map<String, dynamic> json, {required String id}) {
    final siswa = json['siswa'];
    final aktif = ModelUtils.boolean(
      json['status_aktif'] ?? json['statusAktif'],
      fallback: ModelUtils.string(json['status'], fallback: 'aktif')
              .toLowerCase() !=
          'nonaktif',
    );

    return KelasSiswaRecord(
      id: ModelUtils.string(json['id'], fallback: id),
      siswaId: ModelUtils.string(
        json['siswa_user_id'] ??
            json['siswa_id'] ??
            json['user_id'] ??
            json['siswa_uid'],
      ),
      siswaRecordId: ModelUtils.nullableString(
        json['siswa_record_id'] ??
            (siswa is Map<String, dynamic> ? siswa['id'] : null),
      ),
      siswaNama: ModelUtils.nullableString(
        json['siswa_nama'] ??
            (siswa is Map<String, dynamic> ? siswa['nama'] : null),
      ),
      siswaNis: ModelUtils.nullableString(
        json['siswa_nis'] ??
            (siswa is Map<String, dynamic> ? siswa['nis'] : null),
      ),
      kelasId: ModelUtils.string(json['kelas_id'] ?? json['kelasId']),
      tahunAjaranId: ModelUtils.string(
        json['tahun_ajaran_id'] ?? json['tahunAjaranId'],
      ),
      status: ModelUtils.string(
        json['status'],
        fallback: aktif ? 'aktif' : 'nonaktif',
      ),
      isDeleted: ModelUtils.boolean(json['is_deleted'] ?? json['isDeleted']),
      createdAt: ModelUtils.dateTime(json['created_at'] ?? json['createdAt']),
      updatedAt: ModelUtils.dateTime(json['updated_at'] ?? json['updatedAt']),
      deletedAt: ModelUtils.dateTime(json['deleted_at'] ?? json['deletedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return ModelUtils.compact(<String, dynamic>{
      'kelas_id': kelasId,
      'siswa_uid': siswaId,
      'tahun_ajaran_id': tahunAjaranId,
      'status_aktif': statusAktif,
      'is_deleted': isDeleted,
      'created_at': ModelUtils.isoDateTime(createdAt),
      'updated_at': ModelUtils.isoDateTime(updatedAt),
    });
  }

  KelasSiswaRecord copyWith({
    String? id,
    String? siswaId,
    Object? siswaRecordId = _kelasSiswaSentinel,
    Object? siswaNama = _kelasSiswaSentinel,
    Object? siswaNis = _kelasSiswaSentinel,
    String? kelasId,
    String? tahunAjaranId,
    String? status,
    bool? isDeleted,
    Object? createdAt = _kelasSiswaSentinel,
    Object? updatedAt = _kelasSiswaSentinel,
    Object? deletedAt = _kelasSiswaSentinel,
  }) {
    return KelasSiswaRecord(
      id: id ?? this.id,
      siswaId: siswaId ?? this.siswaId,
      siswaRecordId: siswaRecordId == _kelasSiswaSentinel
          ? this.siswaRecordId
          : siswaRecordId as String?,
      siswaNama: siswaNama == _kelasSiswaSentinel ? this.siswaNama : siswaNama as String?,
      siswaNis: siswaNis == _kelasSiswaSentinel ? this.siswaNis : siswaNis as String?,
      kelasId: kelasId ?? this.kelasId,
      tahunAjaranId: tahunAjaranId ?? this.tahunAjaranId,
      status: status ?? this.status,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt == _kelasSiswaSentinel
          ? this.createdAt
          : createdAt as DateTime?,
      updatedAt: updatedAt == _kelasSiswaSentinel
          ? this.updatedAt
          : updatedAt as DateTime?,
      deletedAt: deletedAt == _kelasSiswaSentinel
          ? this.deletedAt
          : deletedAt as DateTime?,
    );
  }
}

const Object _kelasSiswaSentinel = Object();
