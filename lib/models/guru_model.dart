import 'model_utils.dart';

class GuruRecord {
  final String id;
  final String uid;
  final String nama;
  final String? nip;
  final String? nuptk;
  final String? gender;
  final String? tempatLahir;
  final DateTime? tanggalLahir;
  final String? golongan;
  final String? alamat;
  final String? noHp;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final bool isDeleted;

  const GuruRecord({
    required this.id,
    required this.uid,
    required this.nama,
    required this.nip,
    required this.nuptk,
    required this.gender,
    required this.tempatLahir,
    required this.tanggalLahir,
    required this.golongan,
    required this.alamat,
    this.noHp,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    required this.isDeleted,
  });

  String get userId => uid;
  String get namaLengkap => nama;
  String? get jenisKelamin => gender;

  factory GuruRecord.fromJson(Map<String, dynamic> json, {required String id}) {
    return GuruRecord(
      id: ModelUtils.string(json['id'], fallback: id),
      uid: ModelUtils.string(json['user_id'] ?? json['uid']),
      nama: ModelUtils.string(
        json['nama_lengkap'] ?? json['nama'] ?? json['username'],
      ),
      nip: ModelUtils.nullableString(json['nip']),
      nuptk: ModelUtils.nullableString(json['nuptk']),
      gender: ModelUtils.nullableString(
        json['jenis_kelamin'] ?? json['gender'],
      ),
      tempatLahir: ModelUtils.nullableString(
        json['tempat_lahir'] ?? json['tempatLahir'],
      ),
      tanggalLahir: ModelUtils.dateTime(
        json['tanggal_lahir'] ?? json['tanggalLahir'],
      ),
      golongan: ModelUtils.nullableString(json['golongan']),
      alamat: ModelUtils.nullableString(json['alamat']),
      noHp: ModelUtils.nullableString(json['no_hp'] ?? json['noHp']),
      createdAt: ModelUtils.dateTime(json['created_at'] ?? json['createdAt']),
      updatedAt: ModelUtils.dateTime(json['updated_at'] ?? json['updatedAt']),
      deletedAt: ModelUtils.dateTime(json['deleted_at'] ?? json['deletedAt']),
      isDeleted: ModelUtils.boolean(json['is_deleted'] ?? json['isDeleted']),
    );
  }

  Map<String, dynamic> toJson() {
    return ModelUtils.compact(<String, dynamic>{
      'user_id': uid,
      'nama_lengkap': nama,
      'nip': nip,
      'nuptk': nuptk,
      'golongan': golongan,
      'no_hp': noHp,
      'alamat': alamat,
      'tanggal_lahir': ModelUtils.isoDate(tanggalLahir),
      'tempat_lahir': tempatLahir,
      'jenis_kelamin': gender,
      'is_deleted': isDeleted,
      'created_at': ModelUtils.isoDateTime(createdAt),
      'updated_at': ModelUtils.isoDateTime(updatedAt),
    });
  }

  GuruRecord copyWith({
    String? id,
    String? uid,
    String? nama,
    Object? nip = _guruSentinel,
    Object? nuptk = _guruSentinel,
    Object? gender = _guruSentinel,
    Object? tempatLahir = _guruSentinel,
    Object? tanggalLahir = _guruSentinel,
    Object? golongan = _guruSentinel,
    Object? alamat = _guruSentinel,
    Object? noHp = _guruSentinel,
    Object? createdAt = _guruSentinel,
    Object? updatedAt = _guruSentinel,
    Object? deletedAt = _guruSentinel,
    bool? isDeleted,
  }) {
    return GuruRecord(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      nama: nama ?? this.nama,
      nip: nip == _guruSentinel ? this.nip : nip as String?,
      nuptk: nuptk == _guruSentinel ? this.nuptk : nuptk as String?,
      gender: gender == _guruSentinel ? this.gender : gender as String?,
      tempatLahir: tempatLahir == _guruSentinel
          ? this.tempatLahir
          : tempatLahir as String?,
      tanggalLahir: tanggalLahir == _guruSentinel
          ? this.tanggalLahir
          : tanggalLahir as DateTime?,
      golongan: golongan == _guruSentinel ? this.golongan : golongan as String?,
      alamat: alamat == _guruSentinel ? this.alamat : alamat as String?,
      noHp: noHp == _guruSentinel ? this.noHp : noHp as String?,
      createdAt: createdAt == _guruSentinel
          ? this.createdAt
          : createdAt as DateTime?,
      updatedAt: updatedAt == _guruSentinel
          ? this.updatedAt
          : updatedAt as DateTime?,
      deletedAt: deletedAt == _guruSentinel
          ? this.deletedAt
          : deletedAt as DateTime?,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}

const Object _guruSentinel = Object();
