import '../models/model_utils.dart';
import '../models/nilai_tugas_model.dart';
import 'supabase_crud_service.dart';

class NilaiTugasService extends SupabaseCrudService<NilaiTugasRecord> {
  NilaiTugasService({super.client}) : super('nilai_tugas');

  @override
  NilaiTugasRecord fromJson(String id, Map<String, dynamic> json) =>
      NilaiTugasRecord.fromJson(json, id: id);

  @override
  Map<String, dynamic> toJson(NilaiTugasRecord value) => value.toJson();

  @override
  Future<List<Map<String, dynamic>>> transformRows(
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) {
      return rows;
    }

    final siswaIds = rows
        .map((row) => ModelUtils.integerOrNull(row['siswa_uid']))
        .whereType<int>()
        .toSet()
        .toList(growable: false);

    final siswaById = <int, Map<String, dynamic>>{};
    if (siswaIds.isNotEmpty) {
      final siswaRows = await client
          .from('siswa')
          .select('id, user_id')
          .inFilter('id', siswaIds)
          .eq('is_deleted', false);
      for (final row in siswaRows as List<dynamic>) {
        final record = Map<String, dynamic>.from(row as Map);
        final recordId = ModelUtils.integerOrNull(record['id']);
        if (recordId != null) {
          siswaById[recordId] = record;
        }
      }
    }

    return rows
        .map((row) {
          final siswa = siswaById[ModelUtils.integerOrNull(row['siswa_uid'])];
          return <String, dynamic>{...row, 'siswa_user_id': siswa?['user_id']};
        })
        .toList(growable: false);
  }

  @override
  Future<NilaiTugasRecord> create(dynamic value, {String? id}) async {
    final payload = await _normalizePayloadAsync(payloadFromValue(value));
    return super.create(payload, id: id);
  }

  @override
  Future<NilaiTugasRecord> update(String id, dynamic value) async {
    final payload = await _normalizePayloadAsync(payloadFromValue(value));
    return super.update(id, payload);
  }

  Future<List<NilaiTugasRecord>> getNilaiTugasBySiswa(String siswaUid) async {
    final siswaIds = await _resolveSiswaCandidateIds(siswaUid);
    if (siswaIds.isEmpty) {
      return const <NilaiTugasRecord>[];
    }

    dynamic query = client
        .from(table)
        .select(selectStatement)
        .eq('is_deleted', false);
    query = siswaIds.length == 1
        ? query.eq('siswa_uid', siswaIds.first)
        : query.inFilter('siswa_uid', siswaIds);
    final rows = await query;
    return mapResponseList(rows);
  }

  Future<List<NilaiTugasRecord>> getByTugas(String tugasId) async {
    final rows = await client
        .from(table)
        .select(selectStatement)
        .eq('tugas_id', normalizeIdValue(tugasId))
        .eq('is_deleted', false);
    return mapResponseList(rows);
  }

  Future<List<NilaiTugasRecord>> getByTugasIds(
    Iterable<String> tugasIds,
  ) async {
    final normalizedIds = tugasIds
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (normalizedIds.isEmpty) {
      return const <NilaiTugasRecord>[];
    }

    dynamic query = client
        .from(table)
        .select(selectStatement)
        .eq('is_deleted', false);
    query = normalizedIds.length == 1
        ? query.eq('tugas_id', normalizeIdValue(normalizedIds.first))
        : query.inFilter(
            'tugas_id',
            normalizedIds.map(normalizeIdValue).toList(growable: false),
          );
    final rows = await query;
    return mapResponseList(rows);
  }

  Future<List<NilaiTugasRecord>> getBySiswaAndTugasIds({
    required String siswaUid,
    required Iterable<String> tugasIds,
  }) async {
    final siswaIds = await _resolveSiswaCandidateIds(siswaUid);
    final normalizedTugasIds = tugasIds
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (siswaIds.isEmpty || normalizedTugasIds.isEmpty) {
      return const <NilaiTugasRecord>[];
    }

    dynamic query = client
        .from(table)
        .select(selectStatement)
        .eq('is_deleted', false)
        .inFilter(
          'tugas_id',
          normalizedTugasIds.map(normalizeIdValue).toList(growable: false),
        );
    query = siswaIds.length == 1
        ? query.eq('siswa_uid', siswaIds.first)
        : query.inFilter('siswa_uid', siswaIds);
    final rows = await query;
    return mapResponseList(rows);
  }

  Future<NilaiTugasRecord> upsertByTugasAndSiswa({
    required String tugasId,
    required String siswaUid,
    double? nilai,
  }) async {
    try {
      final payload = await _normalizePayloadAsync(<String, dynamic>{
        'tugas_id': tugasId,
        'siswa_uid': siswaUid,
        'nilai': nilai,
        'is_deleted': false,
      });
      final row = await client
          .from(table)
          .upsert(payload, onConflict: 'tugas_id,siswa_uid')
          .select(selectStatement)
          .single();
      return mapResponseSingle(row);
    } catch (error) {
      throw Exception('Failed to upsert nilai tugas: $error');
    }
  }

  Future<void> upsertManyByTugasAndSiswa({
    required String tugasId,
    required Iterable<NilaiTugasBatchInput> items,
  }) async {
    final normalizedItems = items.toList(growable: false);
    if (normalizedItems.isEmpty) {
      return;
    }

    try {
      final siswaIdByRef = await _resolveSiswaInternalIds(
        normalizedItems.map((item) => item.siswaUid),
      );
      final normalizedTugasId = normalizeIdValue(tugasId);
      final payload =
          normalizedItems.map((item) {
            final siswaId = siswaIdByRef[item.siswaUid.trim()];
            if (siswaId == null) {
              throw Exception(
                'Profil siswa dengan UID ${item.siswaUid} tidak ditemukan.',
              );
            }
            return <String, dynamic>{
              'tugas_id': normalizedTugasId,
              'siswa_uid': siswaId,
              'nilai': item.nilai,
              'is_deleted': false,
            };
          }).toList(growable: false);

      await client.from(table).upsert(payload, onConflict: 'tugas_id,siswa_uid');
    } catch (error) {
      throw Exception('Failed to batch upsert nilai tugas: $error');
    }
  }

  Future<Map<String, dynamic>> _normalizePayloadAsync(
    Map<String, dynamic> payload,
  ) async {
    final normalized = <String, dynamic>{};
    if (payload.containsKey('tugas_id')) {
      normalized['tugas_id'] = normalizeIdValue(payload['tugas_id']);
    }
    final siswaRef =
        payload['siswa_uid'] ?? payload['siswa_id'] ?? payload['siswaId'];
    if (siswaRef != null) {
      normalized['siswa_uid'] = await _resolveSiswaInternalId(siswaRef);
    }
    if (payload.containsKey('nilai')) {
      normalized['nilai'] = ModelUtils.doubleValue(payload['nilai']);
    }
    if (payload.containsKey('is_deleted')) {
      normalized['is_deleted'] = ModelUtils.boolean(payload['is_deleted']);
    }
    return normalized;
  }

  Future<Object> _resolveSiswaInternalId(dynamic value) async {
    final raw = ModelUtils.string(value).trim();
    final integerValue = int.tryParse(raw);
    if (integerValue != null) {
      return integerValue;
    }

    final rows = await client
        .from('siswa')
        .select('id')
        .eq('user_id', raw)
        .eq('is_deleted', false)
        .limit(1);
    if ((rows as List<dynamic>).isEmpty) {
      throw Exception('Profil siswa dengan UID $raw tidak ditemukan.');
    }
    final record = Map<String, dynamic>.from(rows.first as Map);
    return normalizeIdValue(record['id']);
  }

  Future<List<int>> _resolveSiswaCandidateIds(String siswaUid) async {
    final raw = siswaUid.trim();
    final integerValue = int.tryParse(raw);
    if (integerValue != null) {
      return <int>[integerValue];
    }

    final rows = await client
        .from('siswa')
        .select('id')
        .eq('user_id', raw)
        .eq('is_deleted', false)
        .limit(1);
    if ((rows as List<dynamic>).isEmpty) {
      return const <int>[];
    }
    final record = Map<String, dynamic>.from(rows.first as Map);
    return <int>[ModelUtils.integer(record['id'])];
  }

  Future<Map<String, Object>> _resolveSiswaInternalIds(
    Iterable<String> values,
  ) async {
    final refs = values
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (refs.isEmpty) {
      return const <String, Object>{};
    }

    final resolved = <String, Object>{};
    final userIds = <String>[];
    for (final ref in refs) {
      final integerValue = int.tryParse(ref);
      if (integerValue != null) {
        resolved[ref] = integerValue;
      } else {
        userIds.add(ref);
      }
    }

    if (userIds.isEmpty) {
      return resolved;
    }

    final rows = await client
        .from('siswa')
        .select('id, user_id')
        .inFilter('user_id', userIds)
        .eq('is_deleted', false);
    for (final row in rows as List<dynamic>) {
      final record = Map<String, dynamic>.from(row as Map);
      final userId = ModelUtils.nullableString(record['user_id']);
      if (userId == null || userId.trim().isEmpty) {
        continue;
      }
      resolved[userId.trim()] = normalizeIdValue(record['id']);
    }

    return resolved;
  }
}

class NilaiTugasBatchInput {
  final String siswaUid;
  final double? nilai;

  const NilaiTugasBatchInput({required this.siswaUid, required this.nilai});
}
