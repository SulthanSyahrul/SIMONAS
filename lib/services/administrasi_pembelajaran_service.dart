import '../models/administrasi_pembelajaran_model.dart';
import '../models/model_utils.dart';
import 'guru_service.dart';
import 'semester_service.dart';
import 'supabase_crud_service.dart';

class AdministrasiPembelajaranService
    extends SupabaseCrudService<AdministrasiPembelajaranRecord> {
  AdministrasiPembelajaranService({super.client})
    : super('administrasi_pembelajaran');

  @override
  AdministrasiPembelajaranRecord fromJson(
    String id,
    Map<String, dynamic> json,
  ) => AdministrasiPembelajaranRecord.fromJson(json, id: id);

  @override
  Map<String, dynamic> toJson(AdministrasiPembelajaranRecord value) =>
      value.toJson();

  @override
  Future<List<Map<String, dynamic>>> transformRows(
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) {
      return rows;
    }

    final semesterIds = rows
        .map((row) => ModelUtils.integerOrNull(row['semester_id']))
        .whereType<int>()
        .toSet()
        .toList(growable: false);
    final guruIds = rows
        .map((row) => ModelUtils.integerOrNull(row['guru_uid']))
        .whereType<int>()
        .toSet()
        .toList(growable: false);

    final embeddedSemesterIds = rows
        .map((row) {
          final embedded = row['semester'];
          if (embedded is! Map) {
            return null;
          }
          return ModelUtils.integerOrNull(embedded['id']);
        })
        .whereType<int>()
        .toSet()
        .toList(growable: false);
    final semesterIdsToFetch = semesterIds
        .where((id) => !embeddedSemesterIds.contains(id))
        .toList(growable: false);

    final semesterById = <int, Map<String, dynamic>>{};
    if (semesterIdsToFetch.isNotEmpty) {
      final semesterRows = await client
          .from('semester')
          .select('id, tahun_ajaran_id, semester_ke')
          .inFilter('id', semesterIdsToFetch)
          .eq('is_deleted', false);
      for (final row in semesterRows as List<dynamic>) {
        final record = Map<String, dynamic>.from(row as Map);
        final recordId = ModelUtils.integerOrNull(record['id']);
        if (recordId != null) {
          semesterById[recordId] = record;
        }
      }
    }

    final embeddedGuruIds = rows
        .map((row) {
          final embedded = row['guru'];
          if (embedded is! Map) {
            return null;
          }
          return ModelUtils.integerOrNull(embedded['id']);
        })
        .whereType<int>()
        .toSet()
        .toList(growable: false);
    final guruIdsToFetch = guruIds
        .where((id) => !embeddedGuruIds.contains(id))
        .toList(growable: false);

    final guruById = <int, Map<String, dynamic>>{};
    if (guruIdsToFetch.isNotEmpty) {
      final guruRows = await client
          .from('guru')
          .select('id, user_id')
          .inFilter('id', guruIdsToFetch)
          .eq('is_deleted', false);
      for (final row in guruRows as List<dynamic>) {
        final record = Map<String, dynamic>.from(row as Map);
        final recordId = ModelUtils.integerOrNull(record['id']);
        if (recordId != null) {
          guruById[recordId] = record;
        }
      }
    }

    return rows
        .map((row) {
          final embeddedSemester = row['semester'];
          final embeddedGuru = row['guru'];
          final embeddedKelas = row['kelas'];
          final embeddedMapel = row['mapel'];
          final semester = embeddedSemester is Map
              ? Map<String, dynamic>.from(embeddedSemester)
              : semesterById[ModelUtils.integerOrNull(row['semester_id'])];
          final guru = embeddedGuru is Map
              ? Map<String, dynamic>.from(embeddedGuru)
              : guruById[ModelUtils.integerOrNull(row['guru_uid'])];
          final tahunAjaranRaw = semester?['tahun_ajaran'];
          final tahunAjaran = tahunAjaranRaw is Map
              ? Map<String, dynamic>.from(tahunAjaranRaw)
              : null;
          final kelas = embeddedKelas is Map
              ? Map<String, dynamic>.from(embeddedKelas)
              : null;
          final mapel = embeddedMapel is Map
              ? Map<String, dynamic>.from(embeddedMapel)
              : null;
          return <String, dynamic>{
            ...row,
            'guru_user_id': guru?['user_id'],
            'guru_nama': guru?['nama_lengkap'],
            'kelas_nama': kelas?['nama_kelas'],
            'mapel_nama': mapel?['nama_mapel'],
            'semester_tahun_ajaran_id': semester?['tahun_ajaran_id'],
            'semester_ke': semester?['semester_ke'],
            'tahun_ajaran_nama': tahunAjaran?['tahun_ajaran'],
            'tahun_ajaran_aktif': tahunAjaran?['is_aktif'],
          };
        })
        .toList(growable: false);
  }

  Future<List<AdministrasiPembelajaranRecord>> getMonitoringByJenis(
    String jenis,
  ) async {
    const selectQuery =
        'id, guru_uid, kelas_id, mapel_id, semester_id, judul_dokumen, tipe_dokumen, deskripsi, file_url, file_path, tanggal_upload, status_verifikasi, catatan_verifikasi, is_deleted, created_at, updated_at, '
        'guru:guru_uid(id, user_id, nama_lengkap), '
        'kelas:kelas_id(id, nama_kelas), '
        'mapel:mapel_id(id, nama_mapel), '
        'semester:semester_id(id, tahun_ajaran_id, semester_ke, tahun_ajaran:tahun_ajaran_id(id, tahun_ajaran, is_aktif))';

    final rows = await client
        .from(table)
        .select(selectQuery)
        .eq('is_deleted', false)
        .eq('tipe_dokumen', jenis);
    return mapResponseList(rows);
  }

  @override
  Future<AdministrasiPembelajaranRecord> create(
    dynamic value, {
    String? id,
  }) async {
    final payload = await _normalizePayloadAsync(payloadFromValue(value));
    return super.create(payload, id: id);
  }

  @override
  Future<AdministrasiPembelajaranRecord> update(
    String id,
    dynamic value,
  ) async {
    final existing = await getById(id);
    final payload = await _normalizePayloadAsync(
      payloadFromValue(value),
      existing: existing,
    );
    return super.update(id, payload);
  }

  Future<List<AdministrasiPembelajaranRecord>> getByGuru(String guruUid) async {
    final guruIds = await _resolveGuruCandidateIds(guruUid);
    if (guruIds.isEmpty) {
      return const <AdministrasiPembelajaranRecord>[];
    }

    const selectQuery =
        '*, semester:semester_id(id, tahun_ajaran_id, semester_ke), guru:guru_uid(id, user_id)';
    dynamic query = client
        .from(table)
        .select(selectQuery)
        .eq('is_deleted', false);
    query = guruIds.length == 1
        ? query.eq('guru_uid', guruIds.first)
        : query.inFilter('guru_uid', guruIds);
    final rows = await query;
    return mapResponseList(rows);
  }

  Future<Map<String, dynamic>> _normalizePayloadAsync(
    Map<String, dynamic> payload, {
    AdministrasiPembelajaranRecord? existing,
  }) async {
    final normalized = <String, dynamic>{};

    final guruRef = payload['guru_uid'] ?? payload['guru_id'];
    if (guruRef != null) {
      normalized['guru_uid'] = await _resolveGuruInternalId(guruRef);
    }
    if (payload.containsKey('kelas_id')) {
      normalized['kelas_id'] = normalizeIdValue(payload['kelas_id']);
    }
    if (payload.containsKey('mapel_id')) {
      normalized['mapel_id'] = normalizeIdValue(payload['mapel_id']);
    }

    final semesterId = await _resolveSemesterId(
      payload,
      fallbackTahunAjaranId: existing?.tahunAjaranId,
      fallbackSemester: existing?.semester,
      fallbackSemesterId: existing?.semesterId,
    );
    if (semesterId != null) {
      normalized['semester_id'] = semesterId;
    }

    if (payload.containsKey('judul_dokumen') ||
        payload.containsKey('judulDokumen') ||
        payload.containsKey('file_name')) {
      normalized['judul_dokumen'] = ModelUtils.nullableString(
        payload['judul_dokumen'] ??
            payload['judulDokumen'] ??
            payload['file_name'],
      );
    }
    if (payload.containsKey('tipe_dokumen') || payload.containsKey('jenis')) {
      normalized['tipe_dokumen'] = ModelUtils.nullableString(
        payload['tipe_dokumen'] ?? payload['jenis'],
      );
    }
    if (payload.containsKey('deskripsi')) {
      normalized['deskripsi'] = ModelUtils.nullableString(payload['deskripsi']);
    }
    if (payload.containsKey('file_url')) {
      normalized['file_url'] = ModelUtils.nullableString(payload['file_url']);
    }
    if (payload.containsKey('file_path')) {
      normalized['file_path'] = ModelUtils.nullableString(payload['file_path']);
    }
    if (payload.containsKey('status_verifikasi')) {
      normalized['status_verifikasi'] = ModelUtils.nullableString(
        payload['status_verifikasi'],
      );
    }
    if (payload.containsKey('catatan_verifikasi')) {
      normalized['catatan_verifikasi'] = ModelUtils.nullableString(
        payload['catatan_verifikasi'],
      );
    }
    if (payload.containsKey('tanggal_upload') ||
        payload.containsKey('created_at')) {
      normalized['tanggal_upload'] = ModelUtils.isoDate(
        payload['tanggal_upload'] ?? payload['created_at'],
      );
    }
    if (payload.containsKey('is_deleted')) {
      normalized['is_deleted'] = ModelUtils.boolean(payload['is_deleted']);
    }
    return normalized;
  }

  Future<Object?> _resolveSemesterId(
    Map<String, dynamic> payload, {
    String? fallbackTahunAjaranId,
    int? fallbackSemester,
    String? fallbackSemesterId,
  }) async {
    if (payload['semester_id'] != null) {
      return normalizeIdValue(payload['semester_id']);
    }

    final semesterKe = payload.containsKey('semester_ke')
        ? ModelUtils.integerOrNull(payload['semester_ke'])
        : ModelUtils.integerOrNull(payload['semester']);
    final tahunAjaranId = ModelUtils.nullableString(
      payload['tahun_ajaran_id'] ?? fallbackTahunAjaranId,
    );

    if (tahunAjaranId != null && (semesterKe ?? fallbackSemester) != null) {
      final semesterRecord = await SemesterService(client: client)
          .getByTahunAjaranDanSemester(
            tahunAjaranId: tahunAjaranId,
            semesterKe: semesterKe ?? fallbackSemester!,
          );
      if (semesterRecord == null) {
        throw Exception(
          'Semester tidak ditemukan untuk tahun ajaran $tahunAjaranId.',
        );
      }
      return normalizeIdValue(semesterRecord.id);
    }

    if (fallbackSemesterId != null) {
      return normalizeIdValue(fallbackSemesterId);
    }
    return null;
  }

  Future<Object> _resolveGuruInternalId(dynamic value) async {
    final raw = ModelUtils.string(value).trim();
    final integerValue = int.tryParse(raw);
    if (integerValue != null) {
      return integerValue;
    }

    final guru = await GuruService(client: client).getFirstByUid(raw);
    if (guru == null) {
      throw Exception('Profil guru dengan UID $raw tidak ditemukan.');
    }
    return normalizeIdValue(guru.id);
  }

  Future<List<int>> _resolveGuruCandidateIds(String guruUid) async {
    final raw = guruUid.trim();
    final integerValue = int.tryParse(raw);
    if (integerValue != null) {
      return <int>[integerValue];
    }

    final guru = await GuruService(client: client).getFirstByUid(raw);
    if (guru == null) {
      return const <int>[];
    }
    return <int>[int.parse(guru.id)];
  }
}
