import '../models/kelas_siswa_model.dart';
import '../models/model_utils.dart';
import 'supabase_crud_service.dart';

class KelasSiswaService extends SupabaseCrudService<KelasSiswaRecord> {
  KelasSiswaService({super.client}) : super('kelas_siswa');
  static const int _batchSize = 100;

  @override
  KelasSiswaRecord fromJson(String id, Map<String, dynamic> json) =>
      KelasSiswaRecord.fromJson(json, id: id);

  @override
  Map<String, dynamic> toJson(KelasSiswaRecord value) => value.toJson();

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
          if (embedded is! Map<String, dynamic>) {
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
          .select('id, user_id, nama')
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
          final siswa = embeddedSiswa is Map<String, dynamic>
              ? embeddedSiswa
              : siswaById[ModelUtils.integerOrNull(row['siswa_uid'])];
          return <String, dynamic>{
            ...row,
            'siswa_record_id': siswa?['id'],
            'siswa_user_id': siswa?['user_id'],
            'siswa_nama': siswa?['nama'],
            'siswa_nis': siswa?['nis'],
          };
        })
        .toList(growable: false);
  }

  Future<List<KelasSiswaRecord>> getActiveRosterByKelas(
    String kelasId, {
    bool forceFullFetch = false,
  }) async {
    final rows = await client
        .from(table)
        .select('*, siswa:siswa_uid(id, user_id, nama, nis, is_deleted)')
        .eq('kelas_id', normalizeIdValue(kelasId))
        .eq('is_deleted', false)
        .eq('status_aktif', true);
    return mapResponseList(rows);
  }

  @override
  Future<KelasSiswaRecord> create(dynamic value, {String? id}) async {
    final payload = await _normalizePayloadAsync(payloadFromValue(value));
    return super.create(payload, id: id);
  }

  @override
  Future<KelasSiswaRecord> update(String id, dynamic value) async {
    final payload = await _normalizePayloadAsync(payloadFromValue(value));
    return super.update(id, payload);
  }

  Future<List<KelasSiswaRecord>> getStudentsByClass(String kelasId) async {
    final rows = await client
        .from(table)
        .select(selectStatement)
        .eq('kelas_id', normalizeIdValue(kelasId))
        .eq('status_aktif', true)
        .eq('is_deleted', false);
    return mapResponseList(rows);
  }

  Future<List<KelasSiswaRecord>> getByKelasIdIncremental(
    String kelasId, {
    bool forceFullFetch = false,
  }) async {
    final rows = await client
        .from(table)
        .select('*, siswa:siswa_uid(id, user_id, nama, nis, is_deleted)')
        .eq('kelas_id', normalizeIdValue(kelasId))
        .eq('is_deleted', false);
    return mapResponseList(rows);
  }

  Future<List<KelasSiswaRecord>> getByKelasDanTahunAjaranIncremental(
    String kelasId,
    String tahunAjaranId, {
    bool onlyAktif = false,
    bool includeDeleted = false,
    bool forceFullFetch = false,
  }) async {
    dynamic query = client
        .from(table)
        .select(selectStatement)
        .eq('kelas_id', normalizeIdValue(kelasId))
        .eq('tahun_ajaran_id', normalizeIdValue(tahunAjaranId));
    if (!includeDeleted) {
      query = query.eq('is_deleted', false);
    }
    if (onlyAktif) {
      query = query.eq('status_aktif', true);
    }
    final rows = await query;
    return mapResponseList(rows);
  }

  Future<List<KelasSiswaRecord>> getByTahunAjaranIncremental(
    String tahunAjaranId, {
    bool forceFullFetch = false,
  }) async {
    final rows = await client
        .from(table)
        .select(selectStatement)
        .eq('tahun_ajaran_id', normalizeIdValue(tahunAjaranId))
        .eq('is_deleted', false);
    return mapResponseList(rows);
  }

  Future<List<KelasSiswaRecord>> getBySiswaUid(
    String siswaUid, {
    String? tahunAjaranId,
    bool onlyAktif = false,
    bool includeDeleted = false,
  }) async {
    dynamic query = client
        .from(table)
        .select(selectStatement)
        .eq('siswa_uid', await _resolveSiswaInternalId(siswaUid));
    if (!includeDeleted) {
      query = query.eq('is_deleted', false);
    }
    if (tahunAjaranId != null && tahunAjaranId.trim().isNotEmpty) {
      query = query.eq('tahun_ajaran_id', normalizeIdValue(tahunAjaranId));
    }
    if (onlyAktif) {
      query = query.eq('status_aktif', true);
    }
    final rows = await query;
    return mapResponseList(rows);
  }

  Future<Map<String, List<KelasSiswaRecord>>> getBySiswaUidsInTahunAjaran(
    Iterable<String> siswaUids, {
    required String tahunAjaranId,
    bool includeDeleted = false,
    Map<String, Object>? resolvedSiswaIdByUid,
  }) async {
    final normalizedUids = siswaUids
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (normalizedUids.isEmpty) {
      return const <String, List<KelasSiswaRecord>>{};
    }

    final siswaIdByUid =
        resolvedSiswaIdByUid ?? await _resolveSiswaInternalIds(normalizedUids);

    final internalIds = siswaIdByUid.values.toList(growable: false);
    dynamic query = client
        .from(table)
        .select(selectStatement)
        .eq('tahun_ajaran_id', normalizeIdValue(tahunAjaranId))
        .inFilter('siswa_uid', internalIds);
    if (!includeDeleted) {
      query = query.eq('is_deleted', false);
    }
    final rows = await query;
    final mapped = await mapResponseList(rows);

    final byUid = <String, List<KelasSiswaRecord>>{
      for (final uid in normalizedUids) uid: <KelasSiswaRecord>[],
    };
    for (final row in mapped) {
      byUid[row.siswaId]?.add(row);
    }
    return byUid;
  }

  Future<void> deactivateRowsByIds(Iterable<String> rowIds) async {
    final normalizedIds = rowIds
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (normalizedIds.isEmpty) {
      return;
    }
    for (final batch in _chunk(normalizedIds, _batchSize)) {
      await client
          .from(table)
          .update(<String, dynamic>{'status_aktif': false})
          .inFilter('id', batch.map(normalizeIdValue).toList(growable: false));
    }
  }

  Future<void> activateRowsByIds(Iterable<String> rowIds) async {
    final normalizedIds = rowIds
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (normalizedIds.isEmpty) {
      return;
    }
    for (final batch in _chunk(normalizedIds, _batchSize)) {
      await client
          .from(table)
          .update(<String, dynamic>{'status_aktif': true, 'is_deleted': false})
          .inFilter('id', batch.map(normalizeIdValue).toList(growable: false));
    }
  }

  Future<void> deactivateTargetYearRowsByUserIds({
    required Iterable<String> siswaUids,
    required String tahunAjaranId,
    Map<String, Object>? resolvedSiswaIdByUid,
  }) async {
    final siswaIdByUid =
        resolvedSiswaIdByUid ?? await _resolveSiswaInternalIds(siswaUids);
    final internalIds = siswaIdByUid.values.toList(growable: false);
    if (internalIds.isEmpty) {
      return;
    }
    for (final batch in _chunk(internalIds, _batchSize)) {
      await client
          .from(table)
          .update(<String, dynamic>{'status_aktif': false})
          .eq('tahun_ajaran_id', normalizeIdValue(tahunAjaranId))
          .eq('is_deleted', false)
          .eq('status_aktif', true)
          .inFilter('siswa_uid', batch);
    }
  }

  Future<void> bulkCreateEnrollmentsByUserIds(
    List<Map<String, dynamic>> enrollments, {
    Map<String, Object>? resolvedSiswaIdByUid,
  }) async {
    if (enrollments.isEmpty) {
      return;
    }
    final siswaUids = enrollments
        .map((item) => ModelUtils.string(item['siswa_uid']).trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final siswaIdByUid =
        resolvedSiswaIdByUid ?? await _resolveSiswaInternalIds(siswaUids);

    final rows = <Map<String, dynamic>>[];
    for (final item in enrollments) {
      final siswaUid = ModelUtils.string(item['siswa_uid']).trim();
      final siswaInternalId = siswaIdByUid[siswaUid];
      if (siswaInternalId == null) {
        continue;
      }
      rows.add(<String, dynamic>{
        'kelas_id': normalizeIdValue(item['kelas_id']),
        'siswa_uid': siswaInternalId,
        'tahun_ajaran_id': normalizeIdValue(item['tahun_ajaran_id']),
        'status_aktif': true,
        'is_deleted': false,
      });
    }
    if (rows.isEmpty) {
      return;
    }
    for (final batch in _chunk(rows, _batchSize)) {
      await client.from(table).insert(batch);
    }
  }

  Future<Map<String, Object>> _resolveSiswaInternalIds(
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
    for (final batch in _chunk(normalized, _batchSize)) {
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

  Future<Map<String, Object>> resolveSiswaInternalIds(
    Iterable<String> siswaUids,
  ) {
    return _resolveSiswaInternalIds(siswaUids);
  }

  Iterable<List<T>> _chunk<T>(List<T> values, int size) sync* {
    for (var i = 0; i < values.length; i += size) {
      final end = (i + size) < values.length ? i + size : values.length;
      yield values.sublist(i, end);
    }
  }

  Future<Map<String, dynamic>> _normalizePayloadAsync(
    Map<String, dynamic> payload,
  ) async {
    final normalized = <String, dynamic>{};
    if (payload.containsKey('kelas_id') || payload.containsKey('kelasId')) {
      normalized['kelas_id'] = normalizeIdValue(
        payload['kelas_id'] ?? payload['kelasId'],
      );
    }
    if (payload.containsKey('tahun_ajaran_id') ||
        payload.containsKey('tahunAjaranId')) {
      normalized['tahun_ajaran_id'] = normalizeIdValue(
        payload['tahun_ajaran_id'] ?? payload['tahunAjaranId'],
      );
    }
    final siswaRef =
        payload['siswa_uid'] ??
        payload['siswa_id'] ??
        payload['user_id'] ??
        payload['siswaId'] ??
        payload['uid'];
    if (siswaRef != null) {
      normalized['siswa_uid'] = await _resolveSiswaInternalId(siswaRef);
    }
    if (payload.containsKey('status_aktif') || payload.containsKey('status')) {
      final aktif = payload.containsKey('status_aktif')
          ? ModelUtils.boolean(payload['status_aktif'], fallback: true)
          : ModelUtils.string(
                  payload['status'],
                  fallback: 'aktif',
                ).toLowerCase() ==
                'aktif';
      normalized['status_aktif'] = aktif;
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
}
