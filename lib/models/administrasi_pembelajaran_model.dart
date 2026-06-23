import 'model_utils.dart';

class AdministrasiPembelajaranRecord {
  final String id;
  final String guruUid;
  final String? guruName;
  final String kelasId;
  final String? kelasName;
  final String mapelId;
  final String? mapelName;
  final String tahunAjaranId;
  final String? tahunAjaranName;
  final bool tahunAjaranAktif;
  final int semester;
  final String jenis;
  final String? fileUrl;
  final String? filePath;
  final String? fileName;
  final String? statusVerifikasi;
  final String? catatanVerifikasi;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final bool isDeleted;
  final String? semesterId;
  final String? judulDokumen;
  final String? deskripsi;
  final DateTime? tanggalUpload;

  const AdministrasiPembelajaranRecord({
    required this.id,
    required this.guruUid,
    this.guruName,
    required this.kelasId,
    this.kelasName,
    required this.mapelId,
    this.mapelName,
    required this.tahunAjaranId,
    this.tahunAjaranName,
    this.tahunAjaranAktif = false,
    required this.semester,
    required this.jenis,
    this.fileUrl,
    this.filePath,
    this.fileName,
    this.statusVerifikasi,
    this.catatanVerifikasi,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    required this.isDeleted,
    this.semesterId,
    this.judulDokumen,
    this.deskripsi,
    this.tanggalUpload,
  });

  factory AdministrasiPembelajaranRecord.fromJson(Map<String, dynamic> json, {required String id}) {
    return AdministrasiPembelajaranRecord(
      id: ModelUtils.string(json['id'], fallback: id),
      guruUid: ModelUtils.string(
        json['guru_user_id'] ?? json['guru_uid'] ?? json['guru_id'],
      ),
      guruName: ModelUtils.nullableString(
        json['guru_nama'] ?? json['guruName'] ?? json['nama_guru'],
      ),
      kelasId: ModelUtils.string(json['kelas_id'] ?? json['kelasId']),
      kelasName: ModelUtils.nullableString(
        json['kelas_nama'] ?? json['kelasName'] ?? json['nama_kelas'],
      ),
      mapelId: ModelUtils.string(json['mapel_id'] ?? json['mapelId']),
      mapelName: ModelUtils.nullableString(
        json['mapel_nama'] ?? json['mapelName'] ?? json['nama_mapel'],
      ),
      tahunAjaranId: ModelUtils.string(
        json['tahun_ajaran_id'] ?? json['semester_tahun_ajaran_id'],
      ),
      tahunAjaranName: ModelUtils.nullableString(
        json['tahun_ajaran_nama'] ??
            json['tahunAjaranName'] ??
            json['nama_tahun_ajaran'],
      ),
      tahunAjaranAktif: ModelUtils.boolean(
        json['tahun_ajaran_aktif'] ?? json['tahunAjaranAktif'],
      ),
      semester: ModelUtils.integer(
        json['semester'] ?? json['semester_ke'],
        fallback: 1,
      ),
      jenis: ModelUtils.string(
        json['jenis'] ?? json['tipe_dokumen'] ?? json['tipeDokumen'],
      ),
      fileUrl: ModelUtils.nullableString(json['file_url'] ?? json['fileUrl']),
      filePath: ModelUtils.nullableString(
        json['file_path'] ?? json['filePath'],
      ),
      fileName: ModelUtils.nullableString(
        json['file_name'] ?? json['fileName'],
      ),
      statusVerifikasi: ModelUtils.nullableString(
        json['status_verifikasi'] ?? json['statusVerifikasi'],
      ),
      catatanVerifikasi: ModelUtils.nullableString(
        json['catatan_verifikasi'] ?? json['catatanVerifikasi'],
      ),
      createdAt: ModelUtils.dateTime(json['created_at'] ?? json['createdAt']),
      updatedAt: ModelUtils.dateTime(json['updated_at'] ?? json['updatedAt']),
      deletedAt: ModelUtils.dateTime(json['deleted_at'] ?? json['deletedAt']),
      isDeleted: ModelUtils.boolean(json['is_deleted'] ?? json['isDeleted']),
      semesterId: ModelUtils.nullableString(json['semester_id']),
      judulDokumen: ModelUtils.nullableString(
        json['judul_dokumen'] ?? json['judulDokumen'],
      ),
      deskripsi: ModelUtils.nullableString(json['deskripsi']),
      tanggalUpload: ModelUtils.dateTime(
        json['tanggal_upload'] ?? json['tanggalUpload'],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return ModelUtils.compact(<String, dynamic>{
      'guru_uid': guruUid,
      'semester_id': semesterId,
      'kelas_id': kelasId,
      'mapel_id': mapelId,
      'judul_dokumen': judulDokumen ?? fileName ?? jenis,
      'tipe_dokumen': jenis,
      'deskripsi': deskripsi,
      'file_url': fileUrl,
      'tanggal_upload': ModelUtils.isoDate(tanggalUpload ?? createdAt),
      'is_deleted': isDeleted,
      'created_at': ModelUtils.isoDateTime(createdAt),
      'updated_at': ModelUtils.isoDateTime(updatedAt),
    });
  }

  AdministrasiPembelajaranRecord copyWith({
    String? id,
    String? guruUid,
    Object? guruName = _administrasiSentinel,
    String? kelasId,
    Object? kelasName = _administrasiSentinel,
    String? mapelId,
    Object? mapelName = _administrasiSentinel,
    String? tahunAjaranId,
    Object? tahunAjaranName = _administrasiSentinel,
    bool? tahunAjaranAktif,
    int? semester,
    String? jenis,
    Object? fileUrl = _administrasiSentinel,
    Object? filePath = _administrasiSentinel,
    Object? fileName = _administrasiSentinel,
    Object? statusVerifikasi = _administrasiSentinel,
    Object? catatanVerifikasi = _administrasiSentinel,
    Object? createdAt = _administrasiSentinel,
    Object? updatedAt = _administrasiSentinel,
    Object? deletedAt = _administrasiSentinel,
    bool? isDeleted,
    Object? semesterId = _administrasiSentinel,
    Object? judulDokumen = _administrasiSentinel,
    Object? deskripsi = _administrasiSentinel,
    Object? tanggalUpload = _administrasiSentinel,
  }) {
    return AdministrasiPembelajaranRecord(
      id: id ?? this.id,
      guruUid: guruUid ?? this.guruUid,
      guruName: guruName == _administrasiSentinel
          ? this.guruName
          : guruName as String?,
      kelasId: kelasId ?? this.kelasId,
      kelasName: kelasName == _administrasiSentinel
          ? this.kelasName
          : kelasName as String?,
      mapelId: mapelId ?? this.mapelId,
      mapelName: mapelName == _administrasiSentinel
          ? this.mapelName
          : mapelName as String?,
      tahunAjaranId: tahunAjaranId ?? this.tahunAjaranId,
      tahunAjaranName: tahunAjaranName == _administrasiSentinel
          ? this.tahunAjaranName
          : tahunAjaranName as String?,
      tahunAjaranAktif: tahunAjaranAktif ?? this.tahunAjaranAktif,
      semester: semester ?? this.semester,
      jenis: jenis ?? this.jenis,
      fileUrl: fileUrl == _administrasiSentinel ? this.fileUrl : fileUrl as String?,
      filePath: filePath == _administrasiSentinel
          ? this.filePath
          : filePath as String?,
      fileName: fileName == _administrasiSentinel
          ? this.fileName
          : fileName as String?,
      statusVerifikasi: statusVerifikasi == _administrasiSentinel
          ? this.statusVerifikasi
          : statusVerifikasi as String?,
      catatanVerifikasi: catatanVerifikasi == _administrasiSentinel
          ? this.catatanVerifikasi
          : catatanVerifikasi as String?,
      createdAt: createdAt == _administrasiSentinel
          ? this.createdAt
          : createdAt as DateTime?,
      updatedAt: updatedAt == _administrasiSentinel
          ? this.updatedAt
          : updatedAt as DateTime?,
      deletedAt: deletedAt == _administrasiSentinel
          ? this.deletedAt
          : deletedAt as DateTime?,
      isDeleted: isDeleted ?? this.isDeleted,
      semesterId: semesterId == _administrasiSentinel
          ? this.semesterId
          : semesterId as String?,
      judulDokumen: judulDokumen == _administrasiSentinel
          ? this.judulDokumen
          : judulDokumen as String?,
      deskripsi: deskripsi == _administrasiSentinel
          ? this.deskripsi
          : deskripsi as String?,
      tanggalUpload: tanggalUpload == _administrasiSentinel
          ? this.tanggalUpload
          : tanggalUpload as DateTime?,
    );
  }
}

const Object _administrasiSentinel = Object();
