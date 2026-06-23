import 'model_utils.dart';

class MapelRecord {
  final String id;
  final String namaMapel;
  final String? kodeMapel;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final bool isDeleted;

  const MapelRecord({
    required this.id,
    required this.namaMapel,
    this.kodeMapel,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    required this.isDeleted,
  });

  factory MapelRecord.fromJson(Map<String, dynamic> json, {required String id}) {
    return MapelRecord(
      id: ModelUtils.string(json['id'], fallback: id),
      namaMapel: ModelUtils.string(
        json['nama_mapel'] ?? json['namaMapel'] ?? json['nama'],
      ),
      kodeMapel: ModelUtils.nullableString(
        json['kode_mapel'] ?? json['kodeMapel'],
      ),
      createdAt: ModelUtils.dateTime(json['created_at'] ?? json['createdAt']),
      updatedAt: ModelUtils.dateTime(json['updated_at'] ?? json['updatedAt']),
      deletedAt: ModelUtils.dateTime(json['deleted_at'] ?? json['deletedAt']),
      isDeleted: ModelUtils.boolean(json['is_deleted'] ?? json['isDeleted']),
    );
  }

  Map<String, dynamic> toJson() {
    return ModelUtils.compact(<String, dynamic>{
      'nama_mapel': namaMapel,
      'is_deleted': isDeleted,
      'created_at': ModelUtils.isoDateTime(createdAt),
      'updated_at': ModelUtils.isoDateTime(updatedAt),
    });
  }

  MapelRecord copyWith({
    String? id,
    String? namaMapel,
    Object? kodeMapel = _mapelSentinel,
    Object? createdAt = _mapelSentinel,
    Object? updatedAt = _mapelSentinel,
    Object? deletedAt = _mapelSentinel,
    bool? isDeleted,
  }) {
    return MapelRecord(
      id: id ?? this.id,
      namaMapel: namaMapel ?? this.namaMapel,
      kodeMapel: kodeMapel == _mapelSentinel
          ? this.kodeMapel
          : kodeMapel as String?,
      createdAt: createdAt == _mapelSentinel
          ? this.createdAt
          : createdAt as DateTime?,
      updatedAt: updatedAt == _mapelSentinel
          ? this.updatedAt
          : updatedAt as DateTime?,
      deletedAt: deletedAt == _mapelSentinel
          ? this.deletedAt
          : deletedAt as DateTime?,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}

const Object _mapelSentinel = Object();
