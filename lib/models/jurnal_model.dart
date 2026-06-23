import 'model_utils.dart';

class JurnalRecord {
  final String id;
  final String guruUid;
  final String kelasId;
  final String? kelasNama;
  final String mataPelajaranId;
  final String? mapelNama;
  final String tahunAjaranId;
  final int semester;
  final String? semesterId;
  final DateTime? tanggal;
  final int jamAwal;
  final int jamAkhir;
  final String materi;
  final String status;
  final String? catatan;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final bool isDeleted;

  const JurnalRecord({
    required this.id,
    required this.guruUid,
    required this.kelasId,
    this.kelasNama,
    required this.mataPelajaranId,
    this.mapelNama,
    required this.tahunAjaranId,
    required this.semester,
    this.semesterId,
    this.tanggal,
    required this.jamAwal,
    required this.jamAkhir,
    required this.materi,
    required this.status,
    this.catatan,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    required this.isDeleted,
  });

  int get jamKe => jamAwal;
  String get userId => guruUid;
  String get statusKehadiran => status;
  String get mapelId => mataPelajaranId;
  String get materiPembelajaran => materi;

  factory JurnalRecord.fromJson(Map<String, dynamic> json, {required String id}) {
    final parsedJamAwal = ModelUtils.integer(
      json['jam_ke_awal'] ?? json['jam_awal'] ?? json['jamAwal'] ?? json['jam_ke'],
      fallback: 1,
    );
    final parsedJamAkhir = ModelUtils.integer(
      json['jam_ke_akhir'] ?? json['jam_akhir'] ?? json['jamAkhir'] ?? json['jam_ke'],
      fallback: parsedJamAwal,
    );
    final kelas = json['kelas'];
    final mapel = json['mapel'];

    return JurnalRecord(
      id: ModelUtils.string(json['id'], fallback: id),
      guruUid: ModelUtils.string(
        json['guru_user_id'] ?? json['guru_uid'] ?? json['user_id'],
      ),
      kelasId: ModelUtils.string(json['kelas_id'] ?? json['kelasId']),
      kelasNama: ModelUtils.nullableString(
        json['kelas_nama'] ??
            (kelas is Map<String, dynamic> ? kelas['nama_kelas'] : null),
      ),
      mataPelajaranId: ModelUtils.string(
        json['mapel_id'] ?? json['mata_pelajaran_id'] ?? json['mataPelajaranId'],
      ),
      mapelNama: ModelUtils.nullableString(
        json['mapel_nama'] ??
            (mapel is Map<String, dynamic> ? mapel['nama_mapel'] : null),
      ),
      tahunAjaranId: ModelUtils.string(
        json['tahun_ajaran_id'] ?? json['semester_tahun_ajaran_id'],
      ),
      semester: ModelUtils.integer(
        json['semester'] ?? json['semester_ke'],
        fallback: 1,
      ),
      semesterId: ModelUtils.nullableString(json['semester_id']),
      tanggal: ModelUtils.dateTime(json['tanggal']),
      jamAwal: parsedJamAwal,
      jamAkhir: parsedJamAkhir < parsedJamAwal ? parsedJamAwal : parsedJamAkhir,
      materi: ModelUtils.string(
        json['materi_pembelajaran'] ?? json['materi'],
      ),
      status: ModelUtils.string(
        json['status_kehadiran'] ?? json['status'],
        fallback: 'Masuk',
      ),
      catatan: ModelUtils.nullableString(json['catatan']),
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
      'mapel_id': mataPelajaranId,
      'semester_id': semesterId,
      'tanggal': ModelUtils.isoDate(tanggal),
      'jam_ke_awal': jamAwal,
      'jam_ke_akhir': jamAkhir,
      'materi_pembelajaran': materi,
      'catatan': catatan,
      'status_kehadiran': status,
      'is_deleted': isDeleted,
      'created_at': ModelUtils.isoDateTime(createdAt),
      'updated_at': ModelUtils.isoDateTime(updatedAt),
    });
  }

  JurnalRecord copyWith({
    String? id,
    String? guruUid,
    String? kelasId,
    Object? kelasNama = _jurnalSentinel,
    String? mataPelajaranId,
    Object? mapelNama = _jurnalSentinel,
    String? tahunAjaranId,
    int? semester,
    Object? semesterId = _jurnalSentinel,
    Object? tanggal = _jurnalSentinel,
    int? jamAwal,
    int? jamAkhir,
    String? materi,
    String? status,
    Object? catatan = _jurnalSentinel,
    Object? createdAt = _jurnalSentinel,
    Object? updatedAt = _jurnalSentinel,
    Object? deletedAt = _jurnalSentinel,
    bool? isDeleted,
  }) {
    return JurnalRecord(
      id: id ?? this.id,
      guruUid: guruUid ?? this.guruUid,
      kelasId: kelasId ?? this.kelasId,
      kelasNama: kelasNama == _jurnalSentinel ? this.kelasNama : kelasNama as String?,
      mataPelajaranId: mataPelajaranId ?? this.mataPelajaranId,
      mapelNama: mapelNama == _jurnalSentinel ? this.mapelNama : mapelNama as String?,
      tahunAjaranId: tahunAjaranId ?? this.tahunAjaranId,
      semester: semester ?? this.semester,
      semesterId: semesterId == _jurnalSentinel
          ? this.semesterId
          : semesterId as String?,
      tanggal: tanggal == _jurnalSentinel ? this.tanggal : tanggal as DateTime?,
      jamAwal: jamAwal ?? this.jamAwal,
      jamAkhir: jamAkhir ?? this.jamAkhir,
      materi: materi ?? this.materi,
      status: status ?? this.status,
      catatan: catatan == _jurnalSentinel ? this.catatan : catatan as String?,
      createdAt: createdAt == _jurnalSentinel
          ? this.createdAt
          : createdAt as DateTime?,
      updatedAt: updatedAt == _jurnalSentinel
          ? this.updatedAt
          : updatedAt as DateTime?,
      deletedAt: deletedAt == _jurnalSentinel
          ? this.deletedAt
          : deletedAt as DateTime?,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  bool includesJamKe(int jamKe) => jamAwal <= jamKe && jamAkhir >= jamKe;
}

const Object _jurnalSentinel = Object();
