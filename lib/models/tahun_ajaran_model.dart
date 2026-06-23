import 'model_utils.dart';

class TahunAjaranRecord {
  final String id;
  final String nama;
  final bool aktif;
  final int? semesterAktif;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final bool isDeleted;

  const TahunAjaranRecord({
    required this.id,
    required this.nama,
    required this.aktif,
    this.semesterAktif,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    required this.isDeleted,
  });

  factory TahunAjaranRecord.fromJson(Map<String, dynamic> json, {required String id}) {
    return TahunAjaranRecord(
      id: ModelUtils.string(json['id'], fallback: id),
      nama: ModelUtils.string(json['tahun_ajaran'] ?? json['nama']),
      aktif: ModelUtils.boolean(json['is_aktif'] ?? json['aktif']),
      semesterAktif: ModelUtils.integerOrNull(
        json['semester_aktif'] ?? json['semesterAktif'],
      ),
      createdAt: ModelUtils.dateTime(json['created_at'] ?? json['createdAt']),
      updatedAt: ModelUtils.dateTime(json['updated_at'] ?? json['updatedAt']),
      deletedAt: ModelUtils.dateTime(json['deleted_at'] ?? json['deletedAt']),
      isDeleted: ModelUtils.boolean(json['is_deleted'] ?? json['isDeleted']),
    );
  }

  Map<String, dynamic> toJson() {
    return ModelUtils.compact(<String, dynamic>{
      'tahun_ajaran': nama,
      'is_aktif': aktif,
      'is_deleted': isDeleted,
      'created_at': ModelUtils.isoDateTime(createdAt),
      'updated_at': ModelUtils.isoDateTime(updatedAt),
    });
  }

  TahunAjaranRecord copyWith({
    String? id,
    String? nama,
    bool? aktif,
    Object? semesterAktif = _tahunAjaranSentinel,
    Object? createdAt = _tahunAjaranSentinel,
    Object? updatedAt = _tahunAjaranSentinel,
    Object? deletedAt = _tahunAjaranSentinel,
    bool? isDeleted,
  }) {
    return TahunAjaranRecord(
      id: id ?? this.id,
      nama: nama ?? this.nama,
      aktif: aktif ?? this.aktif,
      semesterAktif: semesterAktif == _tahunAjaranSentinel
          ? this.semesterAktif
          : semesterAktif as int?,
      createdAt: createdAt == _tahunAjaranSentinel
          ? this.createdAt
          : createdAt as DateTime?,
      updatedAt: updatedAt == _tahunAjaranSentinel
          ? this.updatedAt
          : updatedAt as DateTime?,
      deletedAt: deletedAt == _tahunAjaranSentinel
          ? this.deletedAt
          : deletedAt as DateTime?,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}

const Object _tahunAjaranSentinel = Object();
