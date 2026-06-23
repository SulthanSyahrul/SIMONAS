import '../models/histori_wali_kelas_model.dart';
import '../models/model_utils.dart';
import 'guru_service.dart';
import 'supabase_crud_service.dart';

class HistoriWaliKelasService extends SupabaseCrudService<HistoriWaliKelasRecord> {
  HistoriWaliKelasService({super.client}) : super('histori_wali_kelas');

  @override
  HistoriWaliKelasRecord fromJson(String id, Map<String, dynamic> json) =>
      HistoriWaliKelasRecord.fromJson(json, id: id);

  @override
  Map<String, dynamic> toJson(HistoriWaliKelasRecord value) => value.toJson();

  @override
  Future<List<Map<String, dynamic>>> transformRows(
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) {
      return rows;
    }

    final guruIds = rows
        .map((row) => ModelUtils.integerOrNull(row['guru_uid']))
        .whereType<int>()
        .toSet()
        .toList(growable: false);

    final guruById = <int, Map<String, dynamic>>{};
    if (guruIds.isNotEmpty) {
      final guruRows = await client
          .from('guru')
          .select('id, user_id')
          .inFilter('id', guruIds)
          .eq('is_deleted', false);
      for (final row in guruRows as List<dynamic>) {
        final record = Map<String, dynamic>.from(row as Map);
        final recordId = ModelUtils.integerOrNull(record['id']);
        if (recordId != null) {
          guruById[recordId] = record;
        }
      }
    }

    return rows.map((row) {
      final guru = guruById[ModelUtils.integerOrNull(row['guru_uid'])];
      return <String, dynamic>{
        ...row,
        'guru_user_id': guru?['user_id'],
        'is_aktif': !ModelUtils.boolean(row['is_deleted']),
      };
    }).toList(growable: false);
  }

  @override
  Future<HistoriWaliKelasRecord> create(dynamic value, {String? id}) async {
    final payload = await _normalizePayloadAsync(payloadFromValue(value));
    return super.create(payload, id: id);
  }

  @override
  Future<HistoriWaliKelasRecord> update(String id, dynamic value) async {
    final payload = await _normalizePayloadAsync(payloadFromValue(value));
    return super.update(id, payload);
  }

  Future<List<HistoriWaliKelasRecord>> getByTahunAjaranId(
    String tahunAjaranId, {
    bool onlyAktif = false,
    bool forceFullFetch = false,
  }) async {
    dynamic query = client
        .from(table)
        .select(selectStatement)
        .eq('tahun_ajaran_id', normalizeIdValue(tahunAjaranId));
    if (onlyAktif) {
      query = query.eq('is_deleted', false);
    }
    final rows = await query;
    return mapResponseList(rows);
  }

  Future<List<HistoriWaliKelasRecord>> getByTahunAjaranAndKelas(
    String tahunAjaranId,
    String kelasId, {
    bool forceFullFetch = false,
  }) async {
    final rows = await client
        .from(table)
        .select(selectStatement)
        .eq('tahun_ajaran_id', normalizeIdValue(tahunAjaranId))
        .eq('kelas_id', normalizeIdValue(kelasId));
    return mapResponseList(rows);
  }

  Future<List<HistoriWaliKelasRecord>> getByGuruAndTahunAjaran(
    String guruUid,
    String tahunAjaranId, {
    bool onlyAktif = false,
    bool forceFullFetch = false,
  }) async {
    final guruIds = await _resolveGuruCandidateIds(guruUid);
    if (guruIds.isEmpty) {
      return const <HistoriWaliKelasRecord>[];
    }

    dynamic query = client
        .from(table)
        .select(selectStatement)
        .eq('tahun_ajaran_id', normalizeIdValue(tahunAjaranId));
    query = guruIds.length == 1
        ? query.eq('guru_uid', guruIds.first)
        : query.inFilter('guru_uid', guruIds);
    if (onlyAktif) {
      query = query.eq('is_deleted', false);
    }
    final rows = await query;
    return mapResponseList(rows);
  }

  Future<List<HistoriWaliKelasRecord>> getByGuru(
    String guruUid, {
    bool onlyAktif = false,
  }) async {
    final guruIds = await _resolveGuruCandidateIds(guruUid);
    if (guruIds.isEmpty) {
      return const <HistoriWaliKelasRecord>[];
    }

    dynamic query = client.from(table).select(selectStatement);
    query = guruIds.length == 1
        ? query.eq('guru_uid', guruIds.first)
        : query.inFilter('guru_uid', guruIds);
    if (onlyAktif) {
      query = query.eq('is_deleted', false);
    }

    final rows = await query;
    return mapResponseList(rows);
  }

  Future<List<HistoriWaliKelasRecord>> getScopeByGuru(
    String guruUid, {
    bool onlyAktif = false,
  }) async {
    final guruIds = await _resolveGuruCandidateIds(guruUid);
    if (guruIds.isEmpty) {
      return const <HistoriWaliKelasRecord>[];
    }

    dynamic query = client.from(table).select(
      'id, guru_uid, kelas_id, tahun_ajaran_id, is_deleted, created_at, updated_at',
    );
    query = guruIds.length == 1
        ? query.eq('guru_uid', guruIds.first)
        : query.inFilter('guru_uid', guruIds);
    if (onlyAktif) {
      query = query.eq('is_deleted', false);
    }

    final rows = await query;
    return (rows as List<dynamic>).map((row) {
      final record = Map<String, dynamic>.from(row as Map);
      record['is_aktif'] = !ModelUtils.boolean(record['is_deleted']);
      return HistoriWaliKelasRecord.fromJson(
        record,
        id: record['id']?.toString() ?? '',
      );
    }).toList(growable: false);
  }

  Future<List<HistoriWaliKelasRecord>> getWaliKelasAktif({
    String? tahunAjaranId,
  }) async {
    dynamic query = client.from(table).select(selectStatement).eq('is_deleted', false);
    if (tahunAjaranId != null && tahunAjaranId.trim().isNotEmpty) {
      query = query.eq('tahun_ajaran_id', normalizeIdValue(tahunAjaranId));
    }
    final rows = await query;
    return mapResponseList(rows);
  }

  Future<Map<String, dynamic>> _normalizePayloadAsync(
    Map<String, dynamic> payload,
  ) async {
    final normalized = <String, dynamic>{};
    final guruRef = payload['guru_uid'] ?? payload['guruId'];
    if (guruRef != null) {
      normalized['guru_uid'] = await _resolveGuruInternalId(guruRef);
    }
    if (payload.containsKey('kelas_id') || payload.containsKey('kelasId')) {
      normalized['kelas_id'] = normalizeIdValue(
        payload['kelas_id'] ?? payload['kelasId'],
      );
    }
    if (payload.containsKey('tahun_ajaran_id') || payload.containsKey('tahunAjaranId')) {
      normalized['tahun_ajaran_id'] = normalizeIdValue(
        payload['tahun_ajaran_id'] ?? payload['tahunAjaranId'],
      );
    }
    if (payload.containsKey('isAktif') || payload.containsKey('is_aktif')) {
      final aktif = ModelUtils.boolean(
        payload['isAktif'] ?? payload['is_aktif'],
        fallback: true,
      );
      normalized['is_deleted'] = !aktif;
    }
    if (payload.containsKey('is_deleted')) {
      normalized['is_deleted'] = ModelUtils.boolean(payload['is_deleted']);
    }
    return normalized;
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
