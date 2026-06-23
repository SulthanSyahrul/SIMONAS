import 'model_utils.dart';

class SemesterRecord {
  final String id;
  final String tahunAjaranId;
  final int semesterKe;
  final bool aktif;
  final bool isDeleted;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  const SemesterRecord({
    required this.id,
    required this.tahunAjaranId,
    required this.semesterKe,
    required this.aktif,
    required this.isDeleted,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  factory SemesterRecord.fromJson(Map<String, dynamic> json, {required String id}) {
    return SemesterRecord(
      id: ModelUtils.string(json['id'], fallback: id),
      tahunAjaranId: ModelUtils.string(
        json['tahun_ajaran_id'] ?? json['tahunAjaranId'],
      ),
      semesterKe: ModelUtils.integer(
        json['semester_ke'] ?? json['semesterKe'],
      ),
      aktif: ModelUtils.boolean(json['is_aktif'] ?? json['aktif']),
      isDeleted: ModelUtils.boolean(json['is_deleted'] ?? json['isDeleted']),
      createdAt: ModelUtils.dateTime(json['created_at'] ?? json['createdAt']),
      updatedAt: ModelUtils.dateTime(json['updated_at'] ?? json['updatedAt']),
      deletedAt: ModelUtils.dateTime(json['deleted_at'] ?? json['deletedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return ModelUtils.compact(<String, dynamic>{
      'tahun_ajaran_id': tahunAjaranId,
      'semester_ke': semesterKe,
      'is_aktif': aktif,
      'is_deleted': isDeleted,
      'created_at': ModelUtils.isoDateTime(createdAt),
      'updated_at': ModelUtils.isoDateTime(updatedAt),
    });
  }

  SemesterRecord copyWith({
    String? id,
    String? tahunAjaranId,
    int? semesterKe,
    bool? aktif,
    bool? isDeleted,
    Object? createdAt = _semesterSentinel,
    Object? updatedAt = _semesterSentinel,
    Object? deletedAt = _semesterSentinel,
  }) {
    return SemesterRecord(
      id: id ?? this.id,
      tahunAjaranId: tahunAjaranId ?? this.tahunAjaranId,
      semesterKe: semesterKe ?? this.semesterKe,
      aktif: aktif ?? this.aktif,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt == _semesterSentinel
          ? this.createdAt
          : createdAt as DateTime?,
      updatedAt: updatedAt == _semesterSentinel
          ? this.updatedAt
          : updatedAt as DateTime?,
      deletedAt: deletedAt == _semesterSentinel
          ? this.deletedAt
          : deletedAt as DateTime?,
    );
  }
}

const Object _semesterSentinel = Object();
