import 'model_utils.dart';

class NilaiRecord {
  final String id;
  final String siswaId;
  final String kelasId;
  final String mataPelajaranId;
  final String guruId;
  final String tahunAjaranId;
  final int semester;
  final double? nilaiUts;
  final double? nilaiUas;
  final double? nilaiTugas;
  final double? nilaiAkhir;
  final String? catatan;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final bool isDeleted;

  const NilaiRecord({
    required this.id,
    required this.siswaId,
    required this.kelasId,
    required this.mataPelajaranId,
    required this.guruId,
    required this.tahunAjaranId,
    required this.semester,
    this.nilaiUts,
    this.nilaiUas,
    this.nilaiTugas,
    this.nilaiAkhir,
    this.catatan,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    required this.isDeleted,
  });

  factory NilaiRecord.fromJson(Map<String, dynamic> json, {required String id}) {
    return NilaiRecord(
      id: ModelUtils.string(json['id'], fallback: id),
      siswaId: ModelUtils.string(
        json['siswa_user_id'] ?? json['siswa_id'] ?? json['siswa_uid'],
      ),
      kelasId: ModelUtils.string(json['kelas_id'] ?? json['kelasId']),
      mataPelajaranId: ModelUtils.string(
        json['mapel_id'] ?? json['mata_pelajaran_id'] ?? json['mataPelajaranId'],
      ),
      guruId: ModelUtils.string(
        json['guru_user_id'] ?? json['guru_uid'] ?? json['guru_id'],
      ),
      tahunAjaranId: ModelUtils.string(
        json['tahun_ajaran_id'] ?? json['tahunAjaranId'],
      ),
      semester: ModelUtils.integer(
        json['semester'] ?? json['semester_ke'],
        fallback: 1,
      ),
      nilaiUts: ModelUtils.doubleValue(json['nilai_uts'] ?? json['uts']),
      nilaiUas: ModelUtils.doubleValue(json['nilai_uas'] ?? json['uas']),
      nilaiTugas: ModelUtils.doubleValue(
        json['nilai_tugas'] ?? json['tugas'],
      ),
      nilaiAkhir: ModelUtils.doubleValue(json['nilai_akhir']),
      catatan: ModelUtils.nullableString(json['catatan']),
      createdAt: ModelUtils.dateTime(json['created_at'] ?? json['createdAt']),
      updatedAt: ModelUtils.dateTime(json['updated_at'] ?? json['updatedAt']),
      deletedAt: ModelUtils.dateTime(json['deleted_at'] ?? json['deletedAt']),
      isDeleted: ModelUtils.boolean(json['is_deleted'] ?? json['isDeleted']),
    );
  }

  Map<String, dynamic> toJson() {
    return ModelUtils.compact(<String, dynamic>{
      'siswa_uid': siswaId,
      'guru_uid': guruId,
      'mapel_id': mataPelajaranId,
      'kelas_id': kelasId,
      'tahun_ajaran_id': tahunAjaranId,
      'nilai_uts': nilaiUts,
      'nilai_uas': nilaiUas,
      'is_deleted': isDeleted,
      'created_at': ModelUtils.isoDateTime(createdAt),
      'updated_at': ModelUtils.isoDateTime(updatedAt),
    });
  }

  NilaiRecord copyWith({
    String? id,
    String? siswaId,
    String? kelasId,
    String? mataPelajaranId,
    String? guruId,
    String? tahunAjaranId,
    int? semester,
    Object? nilaiUts = _nilaiSentinel,
    Object? nilaiUas = _nilaiSentinel,
    Object? nilaiTugas = _nilaiSentinel,
    Object? nilaiAkhir = _nilaiSentinel,
    Object? catatan = _nilaiSentinel,
    Object? createdAt = _nilaiSentinel,
    Object? updatedAt = _nilaiSentinel,
    Object? deletedAt = _nilaiSentinel,
    bool? isDeleted,
  }) {
    return NilaiRecord(
      id: id ?? this.id,
      siswaId: siswaId ?? this.siswaId,
      kelasId: kelasId ?? this.kelasId,
      mataPelajaranId: mataPelajaranId ?? this.mataPelajaranId,
      guruId: guruId ?? this.guruId,
      tahunAjaranId: tahunAjaranId ?? this.tahunAjaranId,
      semester: semester ?? this.semester,
      nilaiUts: nilaiUts == _nilaiSentinel ? this.nilaiUts : nilaiUts as double?,
      nilaiUas: nilaiUas == _nilaiSentinel ? this.nilaiUas : nilaiUas as double?,
      nilaiTugas: nilaiTugas == _nilaiSentinel
          ? this.nilaiTugas
          : nilaiTugas as double?,
      nilaiAkhir: nilaiAkhir == _nilaiSentinel
          ? this.nilaiAkhir
          : nilaiAkhir as double?,
      catatan: catatan == _nilaiSentinel ? this.catatan : catatan as String?,
      createdAt: createdAt == _nilaiSentinel
          ? this.createdAt
          : createdAt as DateTime?,
      updatedAt: updatedAt == _nilaiSentinel
          ? this.updatedAt
          : updatedAt as DateTime?,
      deletedAt: deletedAt == _nilaiSentinel
          ? this.deletedAt
          : deletedAt as DateTime?,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}

const Object _nilaiSentinel = Object();
