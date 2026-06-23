import 'model_utils.dart';

class SiswaRecord {
  final String id;
  final String uid;
  final String? nama;
  final String? email;
  final String? noHp;
  final String? nis;
  final String? gender;
  final String? tempatLahir;
  final DateTime? tanggalLahir;
  final String? alamat;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final bool isDeleted;

  const SiswaRecord({
    required this.id,
    required this.uid,
    required this.nama,
    required this.email,
    required this.noHp,
    required this.nis,
    required this.gender,
    required this.tempatLahir,
    required this.tanggalLahir,
    required this.alamat,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    required this.isDeleted,
  });

  String get userId => uid;
  String? get jenisKelamin => gender;

  factory SiswaRecord.fromJson(Map<String, dynamic> json, {required String id}) {
    return SiswaRecord(
      id: ModelUtils.string(json['id'], fallback: id),
      uid: ModelUtils.string(json['user_id'] ?? json['uid']),
      nama: ModelUtils.nullableString(json['nama'] ?? json['username']),
      email: ModelUtils.nullableString(json['email']),
      noHp: ModelUtils.nullableString(json['no_hp'] ?? json['noHp']),
      nis: ModelUtils.nullableString(json['nis']),
      gender: ModelUtils.nullableString(
        json['jenis_kelamin'] ?? json['gender'],
      ),
      tempatLahir: ModelUtils.nullableString(
        json['tempat_lahir'] ?? json['tempatLahir'],
      ),
      tanggalLahir: ModelUtils.dateTime(
        json['tanggal_lahir'] ?? json['tanggalLahir'],
      ),
      alamat: ModelUtils.nullableString(json['alamat']),
      createdAt: ModelUtils.dateTime(json['created_at'] ?? json['createdAt']),
      updatedAt: ModelUtils.dateTime(json['updated_at'] ?? json['updatedAt']),
      deletedAt: ModelUtils.dateTime(json['deleted_at'] ?? json['deletedAt']),
      isDeleted: ModelUtils.boolean(json['is_deleted'] ?? json['isDeleted']),
    );
  }

  Map<String, dynamic> toJson() {
    return ModelUtils.compact(<String, dynamic>{
      'user_id': uid,
      'nis': nis,
      'nama': nama,
      'jenis_kelamin': gender,
      'tempat_lahir': tempatLahir,
      'tanggal_lahir': ModelUtils.isoDate(tanggalLahir),
      'alamat': alamat,
      'no_hp': noHp,
      'is_deleted': isDeleted,
      'created_at': ModelUtils.isoDateTime(createdAt),
      'updated_at': ModelUtils.isoDateTime(updatedAt),
    });
  }

  SiswaRecord copyWith({
    String? id,
    String? uid,
    Object? nama = _siswaSentinel,
    Object? email = _siswaSentinel,
    Object? noHp = _siswaSentinel,
    Object? nis = _siswaSentinel,
    Object? gender = _siswaSentinel,
    Object? tempatLahir = _siswaSentinel,
    Object? tanggalLahir = _siswaSentinel,
    Object? alamat = _siswaSentinel,
    Object? createdAt = _siswaSentinel,
    Object? updatedAt = _siswaSentinel,
    Object? deletedAt = _siswaSentinel,
    bool? isDeleted,
  }) {
    return SiswaRecord(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      nama: nama == _siswaSentinel ? this.nama : nama as String?,
      email: email == _siswaSentinel ? this.email : email as String?,
      noHp: noHp == _siswaSentinel ? this.noHp : noHp as String?,
      nis: nis == _siswaSentinel ? this.nis : nis as String?,
      gender: gender == _siswaSentinel ? this.gender : gender as String?,
      tempatLahir: tempatLahir == _siswaSentinel
          ? this.tempatLahir
          : tempatLahir as String?,
      tanggalLahir: tanggalLahir == _siswaSentinel
          ? this.tanggalLahir
          : tanggalLahir as DateTime?,
      alamat: alamat == _siswaSentinel ? this.alamat : alamat as String?,
      createdAt: createdAt == _siswaSentinel
          ? this.createdAt
          : createdAt as DateTime?,
      updatedAt: updatedAt == _siswaSentinel
          ? this.updatedAt
          : updatedAt as DateTime?,
      deletedAt: deletedAt == _siswaSentinel
          ? this.deletedAt
          : deletedAt as DateTime?,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}

const Object _siswaSentinel = Object();
