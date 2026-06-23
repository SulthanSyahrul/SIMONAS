import 'model_utils.dart';

class TugasRecord {
  final String id;
  final String guruUid;
  final String kelasId;
  final String mapelId;
  final String tahunAjaranId;
  final int semester;
  final String judulTugas;
  final String deskripsi;
  final DateTime? deadline;
  final String? semesterId;
  final String? fileUrl;
  final DateTime? tanggalDibuat;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final bool isDeleted;

  const TugasRecord({
    required this.id,
    required this.guruUid,
    required this.kelasId,
    required this.mapelId,
    required this.tahunAjaranId,
    required this.semester,
    required this.judulTugas,
    required this.deskripsi,
    this.deadline,
    this.semesterId,
    this.fileUrl,
    this.tanggalDibuat,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    required this.isDeleted,
  });

  factory TugasRecord.fromJson(Map<String, dynamic> json, {required String id}) {
    return TugasRecord(
      id: ModelUtils.string(json['id'], fallback: id),
      guruUid: ModelUtils.string(
        json['guru_user_id'] ?? json['guru_uid'] ?? json['guru_id'],
      ),
      kelasId: ModelUtils.string(json['kelas_id'] ?? json['kelasId']),
      mapelId: ModelUtils.string(json['mapel_id'] ?? json['mapelId']),
      tahunAjaranId: ModelUtils.string(
        json['tahun_ajaran_id'] ?? json['semester_tahun_ajaran_id'],
      ),
      semester: ModelUtils.integer(
        json['semester'] ?? json['semester_ke'],
        fallback: 1,
      ),
      judulTugas: ModelUtils.string(
        json['judul_tugas'] ?? json['judulTugas'],
      ),
      deskripsi: ModelUtils.string(json['deskripsi']),
      deadline: ModelUtils.dateTime(
        json['tanggal_deadline'] ?? json['deadline'],
      ),
      semesterId: ModelUtils.nullableString(json['semester_id']),
      fileUrl: ModelUtils.nullableString(json['file_url']),
      tanggalDibuat: ModelUtils.dateTime(
        json['tanggal_dibuat'] ?? json['created_at'],
      ),
      createdAt: ModelUtils.dateTime(json['created_at'] ?? json['createdAt']),
      updatedAt: ModelUtils.dateTime(json['updated_at'] ?? json['updatedAt']),
      deletedAt: ModelUtils.dateTime(json['deleted_at'] ?? json['deletedAt']),
      isDeleted: ModelUtils.boolean(json['is_deleted'] ?? json['isDeleted']),
    );
  }

  Map<String, dynamic> toJson() {
    return ModelUtils.compact(<String, dynamic>{
      'guru_uid': guruUid,
      'kelas_id': kelasId,
      'mapel_id': mapelId,
      'semester_id': semesterId,
      'judul_tugas': judulTugas,
      'deskripsi': deskripsi,
      'tanggal_dibuat': ModelUtils.isoDate(tanggalDibuat ?? createdAt),
      'tanggal_deadline': ModelUtils.isoDate(deadline),
      'file_url': fileUrl,
      'is_deleted': isDeleted,
      'created_at': ModelUtils.isoDateTime(createdAt),
      'updated_at': ModelUtils.isoDateTime(updatedAt),
    });
  }

  TugasRecord copyWith({
    String? id,
    String? guruUid,
    String? kelasId,
    String? mapelId,
    String? tahunAjaranId,
    int? semester,
    String? judulTugas,
    String? deskripsi,
    Object? deadline = _tugasSentinel,
    Object? semesterId = _tugasSentinel,
    Object? fileUrl = _tugasSentinel,
    Object? tanggalDibuat = _tugasSentinel,
    Object? createdAt = _tugasSentinel,
    Object? updatedAt = _tugasSentinel,
    Object? deletedAt = _tugasSentinel,
    bool? isDeleted,
  }) {
    return TugasRecord(
      id: id ?? this.id,
      guruUid: guruUid ?? this.guruUid,
      kelasId: kelasId ?? this.kelasId,
      mapelId: mapelId ?? this.mapelId,
      tahunAjaranId: tahunAjaranId ?? this.tahunAjaranId,
      semester: semester ?? this.semester,
      judulTugas: judulTugas ?? this.judulTugas,
      deskripsi: deskripsi ?? this.deskripsi,
      deadline: deadline == _tugasSentinel ? this.deadline : deadline as DateTime?,
      semesterId: semesterId == _tugasSentinel
          ? this.semesterId
          : semesterId as String?,
      fileUrl: fileUrl == _tugasSentinel ? this.fileUrl : fileUrl as String?,
      tanggalDibuat: tanggalDibuat == _tugasSentinel
          ? this.tanggalDibuat
          : tanggalDibuat as DateTime?,
      createdAt: createdAt == _tugasSentinel
          ? this.createdAt
          : createdAt as DateTime?,
      updatedAt: updatedAt == _tugasSentinel
          ? this.updatedAt
          : updatedAt as DateTime?,
      deletedAt: deletedAt == _tugasSentinel
          ? this.deletedAt
          : deletedAt as DateTime?,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}

const Object _tugasSentinel = Object();
