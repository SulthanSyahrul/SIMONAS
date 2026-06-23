import 'model_utils.dart';

class KelasRecord {
  final String id;
  final String namaKelas;
  final int tingkat;
  final String? waliKelasUid;
  final String tahunAjaranId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final bool isDeleted;

  const KelasRecord({
    required this.id,
    required this.namaKelas,
    this.tingkat = 0,
    required this.waliKelasUid,
    required this.tahunAjaranId,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    required this.isDeleted,
  });

  factory KelasRecord.fromJson(Map<String, dynamic> json, {required String id}) {
    return KelasRecord(
      id: ModelUtils.string(json['id'], fallback: id),
      namaKelas: ModelUtils.string(
        json['nama_kelas'] ?? json['namaKelas'] ?? json['nama'],
      ),
      tingkat: ModelUtils.integer(
        json['tingkat'],
        fallback: _inferTingkat(
          ModelUtils.string(
            json['nama_kelas'] ?? json['namaKelas'] ?? json['nama'],
          ),
        ),
      ),
      waliKelasUid: ModelUtils.nullableString(
        json['wali_kelas_uid'] ?? json['waliKelasUid'],
      ),
      tahunAjaranId: ModelUtils.string(
        json['tahun_ajaran_id'] ?? json['tahunAjaranId'],
      ),
      createdAt: ModelUtils.dateTime(json['created_at'] ?? json['createdAt']),
      updatedAt: ModelUtils.dateTime(json['updated_at'] ?? json['updatedAt']),
      deletedAt: ModelUtils.dateTime(json['deleted_at'] ?? json['deletedAt']),
      isDeleted: ModelUtils.boolean(json['is_deleted'] ?? json['isDeleted']),
    );
  }

  Map<String, dynamic> toJson() {
    return ModelUtils.compact(<String, dynamic>{
      'nama_kelas': namaKelas,
      'tingkat': tingkat == 0 ? _inferTingkat(namaKelas) : tingkat,
      'is_deleted': isDeleted,
      'created_at': ModelUtils.isoDateTime(createdAt),
      'updated_at': ModelUtils.isoDateTime(updatedAt),
    });
  }

  KelasRecord copyWith({
    String? id,
    String? namaKelas,
    int? tingkat,
    Object? waliKelasUid = _kelasSentinel,
    String? tahunAjaranId,
    Object? createdAt = _kelasSentinel,
    Object? updatedAt = _kelasSentinel,
    Object? deletedAt = _kelasSentinel,
    bool? isDeleted,
  }) {
    return KelasRecord(
      id: id ?? this.id,
      namaKelas: namaKelas ?? this.namaKelas,
      tingkat: tingkat ?? this.tingkat,
      waliKelasUid: waliKelasUid == _kelasSentinel
          ? this.waliKelasUid
          : waliKelasUid as String?,
      tahunAjaranId: tahunAjaranId ?? this.tahunAjaranId,
      createdAt: createdAt == _kelasSentinel
          ? this.createdAt
          : createdAt as DateTime?,
      updatedAt: updatedAt == _kelasSentinel
          ? this.updatedAt
          : updatedAt as DateTime?,
      deletedAt: deletedAt == _kelasSentinel
          ? this.deletedAt
          : deletedAt as DateTime?,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  int get lantai {
    final normalized = namaKelas.trim().toUpperCase();
    if (normalized.isEmpty) return 1;
    final suffix = normalized[normalized.length - 1];
    return suffix == 'D' || suffix == 'E' || suffix == 'F' ? 2 : 1;
  }

  static int _inferTingkat(String namaKelas) {
    final match = RegExp(r'(\d+)').firstMatch(namaKelas);
    if (match == null) return 0;
    return int.tryParse(match.group(1)!) ?? 0;
  }
}

const Object _kelasSentinel = Object();
