import 'model_utils.dart';

class JadwalRecord {
  final String id;
  final String guruUid;
  final String kelasId;
  final String? kelasNama;
  final String mapelId;
  final String? mapelNama;
  final String hari;
  final int jamAwal;
  final int jamAkhir;
  final String tahunAjaranId;
  final int semester;
  final String? semesterId;
  final String? waktuMulai;
  final String? waktuSelesai;
  final String? ruangan;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final bool isDeleted;

  const JadwalRecord({
    required this.id,
    required this.guruUid,
    required this.kelasId,
    this.kelasNama,
    required this.mapelId,
    this.mapelNama,
    required this.hari,
    required this.jamAwal,
    required this.jamAkhir,
    required this.tahunAjaranId,
    required this.semester,
    this.semesterId,
    this.waktuMulai,
    this.waktuSelesai,
    this.ruangan,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    required this.isDeleted,
  });

  int get hariKe => ModelUtils.dayNumber(hari, fallback: 1);
  int get jamKe => jamAwal;

  factory JadwalRecord.fromJson(Map<String, dynamic> json, {required String id}) {
    final parsedJamAwal = ModelUtils.integer(
      json['jam_ke_awal'] ?? json['jam_awal'] ?? json['jamAwal'],
      fallback: 1,
    );
    final parsedJamAkhir = ModelUtils.integer(
      json['jam_ke_akhir'] ?? json['jam_akhir'] ?? json['jamAkhir'],
      fallback: parsedJamAwal,
    );
    final kelas = json['kelas'];
    final mapel = json['mapel'];

    return JadwalRecord(
      id: ModelUtils.string(json['id'], fallback: id),
      guruUid: ModelUtils.string(
        json['guru_user_id'] ?? json['guru_uid'] ?? json['guru_id'],
      ),
      kelasId: ModelUtils.string(json['kelas_id'] ?? json['kelasId']),
      kelasNama: ModelUtils.nullableString(
        json['kelas_nama'] ??
            (kelas is Map<String, dynamic> ? kelas['nama_kelas'] : null),
      ),
      mapelId: ModelUtils.string(json['mapel_id'] ?? json['mapelId']),
      mapelNama: ModelUtils.nullableString(
        json['mapel_nama'] ??
            (mapel is Map<String, dynamic> ? mapel['nama_mapel'] : null),
      ),
      hari: ModelUtils.string(
        json['hari'] ??
            json['hari_label'] ??
            ModelUtils.dayNameFromNumber(
              ModelUtils.dayNumber(json['hari_ke'], fallback: 1),
            ),
      ),
      jamAwal: parsedJamAwal,
      jamAkhir: parsedJamAkhir < parsedJamAwal ? parsedJamAwal : parsedJamAkhir,
      tahunAjaranId: ModelUtils.string(
        json['tahun_ajaran_id'] ?? json['semester_tahun_ajaran_id'],
      ),
      semester: ModelUtils.integer(
        json['semester'] is Map
            ? (json['semester'] as Map)['semester_ke']
            : (json['semester'] ?? json['semester_ke'] ?? json['semester_value']),
        fallback: 1,
      ),
      semesterId: ModelUtils.nullableString(json['semester_id']),
      waktuMulai: ModelUtils.nullableString(
        json['waktu_mulai'] ?? json['waktuMulai'],
      ),
      waktuSelesai: ModelUtils.nullableString(
        json['waktu_selesai'] ?? json['waktuSelesai'],
      ),
      ruangan: ModelUtils.nullableString(json['ruangan']),
      createdAt: ModelUtils.dateTime(json['created_at'] ?? json['createdAt']),
      updatedAt: ModelUtils.dateTime(json['updated_at'] ?? json['updatedAt']),
      deletedAt: ModelUtils.dateTime(json['deleted_at'] ?? json['deletedAt']),
      isDeleted: ModelUtils.boolean(json['is_deleted'] ?? json['isDeleted']),
    );
  }

  Map<String, dynamic> toJson() {
    return ModelUtils.compact(<String, dynamic>{
      'semester_id': semesterId,
      'guru_uid': guruUid,
      'kelas_id': kelasId,
      'mapel_id': mapelId,
      'hari_ke': hariKe,
      'jam_ke_awal': jamAwal,
      'jam_ke_akhir': jamAkhir,
      'is_deleted': isDeleted,
      'created_at': ModelUtils.isoDateTime(createdAt),
      'updated_at': ModelUtils.isoDateTime(updatedAt),
    });
  }

  JadwalRecord copyWith({
    String? id,
    String? guruUid,
    String? kelasId,
    Object? kelasNama = _jadwalSentinel,
    String? mapelId,
    Object? mapelNama = _jadwalSentinel,
    String? hari,
    int? jamAwal,
    int? jamAkhir,
    String? tahunAjaranId,
    int? semester,
    Object? semesterId = _jadwalSentinel,
    Object? waktuMulai = _jadwalSentinel,
    Object? waktuSelesai = _jadwalSentinel,
    Object? ruangan = _jadwalSentinel,
    Object? createdAt = _jadwalSentinel,
    Object? updatedAt = _jadwalSentinel,
    Object? deletedAt = _jadwalSentinel,
    bool? isDeleted,
  }) {
    return JadwalRecord(
      id: id ?? this.id,
      guruUid: guruUid ?? this.guruUid,
      kelasId: kelasId ?? this.kelasId,
      kelasNama: kelasNama == _jadwalSentinel ? this.kelasNama : kelasNama as String?,
      mapelId: mapelId ?? this.mapelId,
      mapelNama: mapelNama == _jadwalSentinel ? this.mapelNama : mapelNama as String?,
      hari: hari ?? this.hari,
      jamAwal: jamAwal ?? this.jamAwal,
      jamAkhir: jamAkhir ?? this.jamAkhir,
      tahunAjaranId: tahunAjaranId ?? this.tahunAjaranId,
      semester: semester ?? this.semester,
      semesterId: semesterId == _jadwalSentinel
          ? this.semesterId
          : semesterId as String?,
      waktuMulai: waktuMulai == _jadwalSentinel
          ? this.waktuMulai
          : waktuMulai as String?,
      waktuSelesai: waktuSelesai == _jadwalSentinel
          ? this.waktuSelesai
          : waktuSelesai as String?,
      ruangan: ruangan == _jadwalSentinel ? this.ruangan : ruangan as String?,
      createdAt: createdAt == _jadwalSentinel
          ? this.createdAt
          : createdAt as DateTime?,
      updatedAt: updatedAt == _jadwalSentinel
          ? this.updatedAt
          : updatedAt as DateTime?,
      deletedAt: deletedAt == _jadwalSentinel
          ? this.deletedAt
          : deletedAt as DateTime?,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  bool containsJam(int jamKe) => jamKe >= jamAwal && jamKe <= jamAkhir;

  bool overlapsWithRange(int otherAwal, int otherAkhir) {
    return jamAwal <= otherAkhir && jamAkhir >= otherAwal;
  }

  List<int> expandJamRange() {
    if (jamAkhir < jamAwal) return <int>[jamAwal];
    return List<int>.generate(jamAkhir - jamAwal + 1, (index) => jamAwal + index);
  }

  List<int> expandJams() => expandJamRange();
}

const Object _jadwalSentinel = Object();
