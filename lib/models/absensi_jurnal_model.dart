import 'model_utils.dart';

class AbsensiJurnalRecord {
  final String id;
  final String jurnalId;
  final String siswaUid;
  final String? siswaNama;
  final String? nis;
  final String status;
  final String? keterangan;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final bool isDeleted;

  const AbsensiJurnalRecord({
    required this.id,
    required this.jurnalId,
    required this.siswaUid,
    this.siswaNama,
    this.nis,
    required this.status,
    this.keterangan,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    required this.isDeleted,
  });

  String get siswaId => siswaUid;
  String get statusKehadiran => status;
  String? get catatan => keterangan;
  DateTime? get tanggal => createdAt;

  factory AbsensiJurnalRecord.fromJson(Map<String, dynamic> json, {required String id}) {
    return AbsensiJurnalRecord(
      id: ModelUtils.string(json['id'], fallback: id),
      jurnalId: ModelUtils.string(json['jurnal_id'] ?? json['jurnalId']),
      siswaUid: ModelUtils.string(
        json['siswa_user_id'] ??
            json['siswa_uid'] ??
            json['siswa_id'] ??
            json['siswaId'],
      ),
      siswaNama: ModelUtils.nullableString(
        json['siswa_nama'] ?? json['nama_siswa'],
      ),
      nis: ModelUtils.nullableString(json['nis']),
      status: ModelUtils.string(
        json['status_kehadiran'] ?? json['status'],
        fallback: 'Hadir',
      ),
      keterangan: ModelUtils.nullableString(
        json['keterangan'] ?? json['catatan'],
      ),
      createdAt: ModelUtils.dateTime(json['created_at'] ?? json['createdAt']),
      updatedAt: ModelUtils.dateTime(json['updated_at'] ?? json['updatedAt']),
      deletedAt: ModelUtils.dateTime(json['deleted_at'] ?? json['deletedAt']),
      isDeleted: ModelUtils.boolean(json['is_deleted'] ?? json['isDeleted']),
    );
  }

  Map<String, dynamic> toJson() {
    return ModelUtils.compact(<String, dynamic>{
      'jurnal_id': jurnalId,
      'siswa_uid': siswaUid,
      'status_kehadiran': status,
      'created_at': ModelUtils.isoDateTime(createdAt),
      'updated_at': ModelUtils.isoDateTime(updatedAt),
      'is_deleted': isDeleted,
    });
  }

  AbsensiJurnalRecord copyWith({
    String? id,
    String? jurnalId,
    String? siswaUid,
    Object? siswaNama = _absensiSentinel,
    Object? nis = _absensiSentinel,
    String? status,
    Object? keterangan = _absensiSentinel,
    Object? createdAt = _absensiSentinel,
    Object? updatedAt = _absensiSentinel,
    Object? deletedAt = _absensiSentinel,
    bool? isDeleted,
  }) {
    return AbsensiJurnalRecord(
      id: id ?? this.id,
      jurnalId: jurnalId ?? this.jurnalId,
      siswaUid: siswaUid ?? this.siswaUid,
      siswaNama: siswaNama == _absensiSentinel
          ? this.siswaNama
          : siswaNama as String?,
      nis: nis == _absensiSentinel ? this.nis : nis as String?,
      status: status ?? this.status,
      keterangan: keterangan == _absensiSentinel
          ? this.keterangan
          : keterangan as String?,
      createdAt: createdAt == _absensiSentinel
          ? this.createdAt
          : createdAt as DateTime?,
      updatedAt: updatedAt == _absensiSentinel
          ? this.updatedAt
          : updatedAt as DateTime?,
      deletedAt: deletedAt == _absensiSentinel
          ? this.deletedAt
          : deletedAt as DateTime?,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}

const Object _absensiSentinel = Object();
