import '../models/absensi_jurnal_model.dart';
import '../models/model_utils.dart';
import 'supabase_crud_service.dart';

class AbsensiService extends SupabaseCrudService<AbsensiJurnalRecord> {
  AbsensiService({super.client}) : super('absensi_jurnal');
  static const int _batchSize = 100;

  @override
  AbsensiJurnalRecord fromJson(String id, Map<String, dynamic> json) =>
      AbsensiJurnalRecord.fromJson(json, id: id);

  @override
  Map<String, dynamic> toJson(AbsensiJurnalRecord value) => value.toJson();

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

    final embeddedSiswaIds = rows
        .map((row) {
          final embedded = row['siswa'];
          if (embedded is! Map) {
            return null;
          }
          return ModelUtils.integerOrNull(embedded['id']);
        })
        .whereType<int>()
        .toSet()
        .toList(growable: false);
    final siswaIdsToFetch = siswaIds
        .where((id) => !embeddedSiswaIds.contains(id))
        .toList(growable: false);

    final siswaById = <int, Map<String, dynamic>>{};
    if (siswaIdsToFetch.isNotEmpty) {
      final siswaRows = await client
          .from('siswa')
          .select('id, user_id, nama, nis')
          .inFilter('id', siswaIdsToFetch)
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
          final embeddedSiswa = row['siswa'];
          final siswa = embeddedSiswa is Map
              ? Map<String, dynamic>.from(embeddedSiswa)
              : siswaById[ModelUtils.integerOrNull(row['siswa_uid'])];
          return <String, dynamic>{
            ...row,
            'siswa_user_id': siswa?['user_id'],
            'siswa_nama': siswa?['nama'],
            'nis': siswa?['nis'],
          };
        })
        .toList(growable: false);
  }

  @override
  Future<AbsensiJurnalRecord> create(dynamic value, {String? id}) async {
    final payload = await _normalizePayloadAsync(payloadFromValue(value));
    return super.create(payload, id: id);
  }

  @override
  Future<AbsensiJurnalRecord> update(String id, dynamic value) async {
    final payload = await _normalizePayloadAsync(payloadFromValue(value));
    return super.update(id, payload);
  }

  Future<List<AbsensiJurnalRecord>> getByJurnalId(
    String jurnalId, {
    bool forceFullFetch = false,
  }) async {
    const selectQuery = '*, siswa:siswa_uid(id, user_id, nama, nis)';
    final rows = await client
        .from(table)
        .select(selectQuery)
        .eq('jurnal_id', normalizeIdValue(jurnalId))
        .eq('is_deleted', false);
    return mapResponseList(rows);
  }

  Future<List<AbsensiJurnalRecord>> getByJurnalIds(
    Iterable<String> jurnalIds, {
    bool forceFullFetch = false,
  }) async {
    final ids = jurnalIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (ids.isEmpty) {
      return const <AbsensiJurnalRecord>[];
    }

    const selectQuery = '*, siswa:siswa_uid(id, user_id, nama, nis)';
    final rows = await client
        .from(table)
        .select(selectQuery)
        .inFilter(
          'jurnal_id',
          ids.map(normalizeIdValue).toList(growable: false),
        )
        .eq('is_deleted', false);
    return mapResponseList(rows);
  }

  Future<List<AbsensiJurnalRecord>> getBySiswaUid(
    String siswaUid, {
    bool includeDeleted = false,
  }) async {
    final siswaInternalId = await _resolveSiswaInternalId(siswaUid);
    dynamic query = client
        .from(table)
        .select(selectStatement)
        .eq('siswa_uid', siswaInternalId);
    if (!includeDeleted) {
      query = query.eq('is_deleted', false);
    }
    final rows = await query;
    return mapResponseList(rows);
  }

  Future<void> upsertByJurnalAndSiswaBatch({
    required String jurnalId,
    required List<Map<String, dynamic>> rows,
    DateTime? tanggal,
  }) async {
    final siswaRefs = rows
        .map((row) => ModelUtils.string(row['siswa_uid'] ?? row['siswa_id']).trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final siswaInternalIds = await resolveSiswaInternalIds(siswaRefs);

    final payloads = <Map<String, dynamic>>[];
    for (final row in rows) {
      final siswaRef = ModelUtils.string(
        row['siswa_uid'] ?? row['siswa_id'] ?? row['siswaId'],
      ).trim();
      if (siswaRef.isEmpty) {
        continue;
      }

      final siswaInternalId = siswaInternalIds[siswaRef];
      if (siswaInternalId == null) {
        throw Exception('Profil siswa dengan UID $siswaRef tidak ditemukan.');
      }

      payloads.add(<String, dynamic>{
        'jurnal_id': normalizeIdValue(jurnalId),
        'siswa_uid': siswaInternalId,
        'status_kehadiran': ModelUtils.nullableString(
          row['status_kehadiran'] ?? row['status'],
        ),
        'is_deleted': false,
      });
    }

    if (payloads.isEmpty) {
      return;
    }

    for (final batch in _chunk(payloads, _batchSize)) {
      await client.from(table).upsert(
        batch,
        onConflict: 'jurnal_id,siswa_uid',
      );
    }
  }

  Future<void> softDeleteByJurnalId(String jurnalId) async {
    await client.from(table).update(<String, dynamic>{
      'is_deleted': true,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('jurnal_id', normalizeIdValue(jurnalId)).eq('is_deleted', false);
  }

  Future<Map<String, dynamic>> _normalizePayloadAsync(
    Map<String, dynamic> payload,
  ) async {
    final normalized = <String, dynamic>{};
    if (payload.containsKey('jurnal_id')) {
      normalized['jurnal_id'] = normalizeIdValue(payload['jurnal_id']);
    }
    final siswaRef =
        payload['siswa_uid'] ?? payload['siswa_id'] ?? payload['siswaId'];
    if (siswaRef != null) {
      normalized['siswa_uid'] = await _resolveSiswaInternalId(siswaRef);
    }
    if (payload.containsKey('status_kehadiran') ||
        payload.containsKey('status')) {
      normalized['status_kehadiran'] = ModelUtils.nullableString(
        payload['status_kehadiran'] ?? payload['status'],
      );
    }
    if (payload.containsKey('is_deleted')) {
      normalized['is_deleted'] = ModelUtils.boolean(payload['is_deleted']);
    }
    return normalized;
  }

  Future<Map<String, Object>> resolveSiswaInternalIds(
    Iterable<String> siswaUids,
  ) async {
    final normalized = siswaUids
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (normalized.isEmpty) {
      return const <String, Object>{};
    }

    final result = <String, Object>{};
    for (final item in normalized) {
      final integerValue = int.tryParse(item);
      if (integerValue != null) {
        result[item] = integerValue;
      }
    }

    final unresolved = normalized
        .where((item) => !result.containsKey(item))
        .toList(growable: false);
    for (final batch in _chunk(unresolved, _batchSize)) {
      final rows = await client
          .from('siswa')
          .select('id, user_id')
          .inFilter('user_id', batch)
          .eq('is_deleted', false);
      for (final row in rows as List<dynamic>) {
        final record = Map<String, dynamic>.from(row as Map);
        final uid = ModelUtils.string(record['user_id']).trim();
        if (uid.isEmpty) {
          continue;
        }
        result[uid] = normalizeIdValue(record['id']);
      }
    }
    return result;
  }

  Iterable<List<T>> _chunk<T>(List<T> values, int size) sync* {
    for (var i = 0; i < values.length; i += size) {
      final end = (i + size) < values.length ? i + size : values.length;
      yield values.sublist(i, end);
    }
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
}
