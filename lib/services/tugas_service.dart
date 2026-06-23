import '../models/model_utils.dart';
import '../models/tugas_model.dart';
import 'guru_service.dart';
import 'semester_service.dart';
import 'supabase_crud_service.dart';

class TugasService extends SupabaseCrudService<TugasRecord> {
  TugasService({super.client}) : super('tugas');

  @override
  TugasRecord fromJson(String id, Map<String, dynamic> json) =>
      TugasRecord.fromJson(json, id: id);

  @override
  Map<String, dynamic> toJson(TugasRecord value) => value.toJson();

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
          final semester = embeddedSemester is Map
              ? Map<String, dynamic>.from(embeddedSemester)
              : semesterById[ModelUtils.integerOrNull(row['semester_id'])];
          final guru = embeddedGuru is Map
              ? Map<String, dynamic>.from(embeddedGuru)
              : guruById[ModelUtils.integerOrNull(row['guru_uid'])];
          return <String, dynamic>{
            ...row,
            'guru_user_id': guru?['user_id'],
            'semester_tahun_ajaran_id': semester?['tahun_ajaran_id'],
            'semester_ke': semester?['semester_ke'],
          };
        })
        .toList(growable: false);
  }

  @override
  Future<TugasRecord> create(dynamic value, {String? id}) async {
    final payload = await _normalizePayloadAsync(payloadFromValue(value));
    return super.create(payload, id: id);
  }

  @override
  Future<TugasRecord> update(String id, dynamic value) async {
    final existing = await getById(id);
    final payload = await _normalizePayloadAsync(
      payloadFromValue(value),
      existing: existing,
    );
    return super.update(id, payload);
  }

  Future<List<TugasRecord>> getByGuruAndContext({
    required String guruUid,
    required String tahunAjaranId,
    required int semester,
  }) async {
    final guruIds = await _resolveGuruCandidateIds(guruUid);
    if (guruIds.isEmpty) {
      return const <TugasRecord>[];
    }

    final semesterRecord = await SemesterService(client: client)
        .getByTahunAjaranDanSemester(
          tahunAjaranId: tahunAjaranId,
          semesterKe: semester,
        );
    if (semesterRecord == null) {
      return const <TugasRecord>[];
    }

    const selectQuery =
        '*, semester:semester_id(id, tahun_ajaran_id, semester_ke), guru:guru_uid(id, user_id)';
    dynamic query = client
        .from(table)
        .select(selectQuery)
        .eq('semester_id', normalizeIdValue(semesterRecord.id))
        .eq('is_deleted', false);
    query = guruIds.length == 1
        ? query.eq('guru_uid', guruIds.first)
        : query.inFilter('guru_uid', guruIds);
    final rows = await query;
    return mapResponseList(rows);
  }

  Future<List<TugasRecord>> getByKelasAndContext({
    required String kelasId,
    required String tahunAjaranId,
    required int semester,
  }) async {
    final semesterRecord = await SemesterService(client: client)
        .getByTahunAjaranDanSemester(
          tahunAjaranId: tahunAjaranId,
          semesterKe: semester,
        );
    if (semesterRecord == null) {
      return const <TugasRecord>[];
    }

    const selectQuery =
        '*, semester:semester_id(id, tahun_ajaran_id, semester_ke), guru:guru_uid(id, user_id)';
    final rows = await client
        .from(table)
        .select(selectQuery)
        .eq('kelas_id', normalizeIdValue(kelasId))
        .eq('semester_id', normalizeIdValue(semesterRecord.id))
        .eq('is_deleted', false);
    return mapResponseList(rows);
  }

  Future<List<TugasRecord>> getByKelasMapelTahunAjaran({
    required String kelasId,
    required String mapelId,
    required String tahunAjaranId,
    int? semester,
  }) async {
    final semesterIds = await _resolveSemesterIdsForTahunAjaran(
      tahunAjaranId: tahunAjaranId,
      semester: semester,
    );
    if (semesterIds.isEmpty) {
      return const <TugasRecord>[];
    }

    const selectQuery =
        '*, semester:semester_id(id, tahun_ajaran_id, semester_ke), guru:guru_uid(id, user_id)';
    dynamic query = client
        .from(table)
        .select(selectQuery)
        .eq('kelas_id', normalizeIdValue(kelasId))
        .eq('mapel_id', normalizeIdValue(mapelId))
        .eq('is_deleted', false);
    query = semesterIds.length == 1
        ? query.eq('semester_id', normalizeIdValue(semesterIds.first))
        : query.inFilter(
            'semester_id',
            semesterIds.map(normalizeIdValue).toList(growable: false),
          );
    final rows = await query;
    return mapResponseList(rows);
  }

  Future<List<TugasRecord>> getByGuruKelasMapelTahunAjaran({
    required String guruUid,
    required String kelasId,
    required String mapelId,
    required String tahunAjaranId,
    int? semester,
  }) async {
    final guruIds = await _resolveGuruCandidateIds(guruUid);
    if (guruIds.isEmpty) {
      return const <TugasRecord>[];
    }

    final semesterIds = await _resolveSemesterIdsForTahunAjaran(
      tahunAjaranId: tahunAjaranId,
      semester: semester,
    );
    if (semesterIds.isEmpty) {
      return const <TugasRecord>[];
    }

    const selectQuery =
        '*, semester:semester_id(id, tahun_ajaran_id, semester_ke), guru:guru_uid(id, user_id)';
    dynamic query = client
        .from(table)
        .select(selectQuery)
        .eq('kelas_id', normalizeIdValue(kelasId))
        .eq('mapel_id', normalizeIdValue(mapelId))
        .eq('is_deleted', false);
    query = guruIds.length == 1
        ? query.eq('guru_uid', guruIds.first)
        : query.inFilter('guru_uid', guruIds);
    query = semesterIds.length == 1
        ? query.eq('semester_id', normalizeIdValue(semesterIds.first))
        : query.inFilter(
            'semester_id',
            semesterIds.map(normalizeIdValue).toList(growable: false),
          );
    final rows = await query;
    return mapResponseList(rows);
  }

  Future<Map<String, dynamic>> _normalizePayloadAsync(
    Map<String, dynamic> payload, {
    TugasRecord? existing,
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

    if (payload.containsKey('judul_tugas') ||
        payload.containsKey('judulTugas')) {
      normalized['judul_tugas'] = ModelUtils.nullableString(
        payload['judul_tugas'] ?? payload['judulTugas'],
      );
    }
    if (payload.containsKey('deskripsi')) {
      normalized['deskripsi'] = ModelUtils.nullableString(payload['deskripsi']);
    }
    if (payload.containsKey('tanggal_dibuat') ||
        payload.containsKey('created_at')) {
      normalized['tanggal_dibuat'] = ModelUtils.isoDate(
        payload['tanggal_dibuat'] ?? payload['created_at'],
      );
    }
    if (payload.containsKey('tanggal_deadline') ||
        payload.containsKey('deadline')) {
      normalized['tanggal_deadline'] = ModelUtils.isoDate(
        payload['tanggal_deadline'] ?? payload['deadline'],
      );
    }
    if (payload.containsKey('file_url')) {
      normalized['file_url'] = ModelUtils.nullableString(payload['file_url']);
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

  Future<List<String>> _resolveSemesterIdsForTahunAjaran({
    required String tahunAjaranId,
    int? semester,
  }) async {
    final semesterService = SemesterService(client: client);
    if (semester != null) {
      final record = await semesterService.getByTahunAjaranDanSemester(
        tahunAjaranId: tahunAjaranId,
        semesterKe: semester,
      );
      return record == null ? const <String>[] : <String>[record.id];
    }

    final rows = await semesterService.getByTahunAjaran(tahunAjaranId);
    return rows.map((item) => item.id).toList(growable: false);
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
