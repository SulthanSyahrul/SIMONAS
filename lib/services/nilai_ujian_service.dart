import '../models/model_utils.dart';
import '../models/nilai_ujian_model.dart';
import 'guru_service.dart';
import 'supabase_crud_service.dart';

class NilaiUjianBatchInput {
  final String siswaUid;
  final double? nilaiUts;
  final double? nilaiUas;

  const NilaiUjianBatchInput({
    required this.siswaUid,
    required this.nilaiUts,
    required this.nilaiUas,
  });
}

class NilaiUjianService extends SupabaseCrudService<NilaiRecord> {
  NilaiUjianService({super.client}) : super('nilai_ujian');

  static const String _selectWithRelations =
      '*, siswa:siswa_uid(id, user_id), guru:guru_uid(id, user_id)';
  static const int _batchSize = 100;

  @override
  NilaiRecord fromJson(String id, Map<String, dynamic> json) =>
      NilaiRecord.fromJson(json, id: id);

  @override
  Map<String, dynamic> toJson(NilaiRecord value) => value.toJson();

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
    final guruIds = rows
        .map((row) => ModelUtils.integerOrNull(row['guru_uid']))
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
          .select('id, user_id')
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
          final embeddedSiswa = row['siswa'];
          final embeddedGuru = row['guru'];
          final siswa = embeddedSiswa is Map
              ? Map<String, dynamic>.from(embeddedSiswa)
              : siswaById[ModelUtils.integerOrNull(row['siswa_uid'])];
          final guru = embeddedGuru is Map
              ? Map<String, dynamic>.from(embeddedGuru)
              : guruById[ModelUtils.integerOrNull(row['guru_uid'])];
          return <String, dynamic>{
            ...row,
            'siswa_user_id': siswa?['user_id'],
            'guru_user_id': guru?['user_id'],
          };
        })
        .toList(growable: false);
  }

  @override
  Future<NilaiRecord> create(dynamic value, {String? id}) async {
    final payload = await _normalizePayloadAsync(payloadFromValue(value));
    return super.create(payload, id: id);
  }

  @override
  Future<NilaiRecord> update(String id, dynamic value) async {
    final payload = await _normalizePayloadAsync(payloadFromValue(value));
    return super.update(id, payload);
  }

  Future<void> upsertManyByGuruContext({
    required String guruUid,
    required String kelasId,
    required String mapelId,
    required String tahunAjaranId,
    required Iterable<NilaiUjianBatchInput> items,
  }) async {
    final normalizedItems = items.toList(growable: false);
    if (normalizedItems.isEmpty) {
      return;
    }

    try {
      final guruId = await _resolveGuruInternalId(guruUid);
      final siswaIdByRef = await _resolveSiswaInternalIds(
        normalizedItems.map((item) => item.siswaUid),
      );
      final normalizedKelasId = normalizeIdValue(kelasId);
      final normalizedMapelId = normalizeIdValue(mapelId);
      final normalizedTahunAjaranId = normalizeIdValue(tahunAjaranId);

      final payloads = normalizedItems.map((item) {
        final siswaId = siswaIdByRef[item.siswaUid.trim()];
        if (siswaId == null) {
          throw Exception(
            'Profil siswa dengan UID ${item.siswaUid} tidak ditemukan.',
          );
        }
        return <String, dynamic>{
          'siswa_uid': siswaId,
          'guru_uid': guruId,
          'kelas_id': normalizedKelasId,
          'mapel_id': normalizedMapelId,
          'tahun_ajaran_id': normalizedTahunAjaranId,
          'nilai_uts': item.nilaiUts,
          'nilai_uas': item.nilaiUas,
          'is_deleted': false,
        };
      }).toList(growable: false);

      for (final batch in _chunk(payloads, _batchSize)) {
        await client.from(table).upsert(
          batch,
          onConflict: 'siswa_uid,mapel_id,kelas_id,tahun_ajaran_id',
        );
      }
    } catch (error) {
      throw Exception('Failed to batch upsert nilai ujian: $error');
    }
  }

  Future<List<NilaiRecord>> getNilaiBySiswa(String siswaUid) async {
    final siswaIds = await _resolveSiswaCandidateIds(siswaUid);
    if (siswaIds.isEmpty) {
      return const <NilaiRecord>[];
    }

    dynamic query = client
        .from(table)
        .select(_selectWithRelations)
        .eq('is_deleted', false);
    query = siswaIds.length == 1
        ? query.eq('siswa_uid', siswaIds.first)
        : query.inFilter('siswa_uid', siswaIds);
    final rows = await query;
    return mapResponseList(rows);
  }

  Future<List<NilaiRecord>> getNilaiBySiswaDanTahunAjaran(
    String siswaUid,
    String tahunAjaranId,
  ) async {
    final siswaIds = await _resolveSiswaCandidateIds(siswaUid);
    if (siswaIds.isEmpty) {
      return const <NilaiRecord>[];
    }

    dynamic query = client
        .from(table)
        .select(_selectWithRelations)
        .eq('is_deleted', false)
        .eq('tahun_ajaran_id', normalizeIdValue(tahunAjaranId));
    query = siswaIds.length == 1
        ? query.eq('siswa_uid', siswaIds.first)
        : query.inFilter('siswa_uid', siswaIds);
    final rows = await query;
    return mapResponseList(rows);
  }

  Future<List<NilaiRecord>> getByGuruFilters({
    required String guruUid,
    String? kelasId,
    String? mapelId,
    String? tahunAjaranId,
  }) async {
    final guruIds = await _resolveGuruCandidateIds(guruUid);
    if (guruIds.isEmpty) {
      return const <NilaiRecord>[];
    }

    dynamic query = client
        .from(table)
        .select(_selectWithRelations)
        .eq('is_deleted', false);
    query = guruIds.length == 1
        ? query.eq('guru_uid', guruIds.first)
        : query.inFilter('guru_uid', guruIds);

    final normalizedKelasId = kelasId?.trim();
    if (normalizedKelasId != null && normalizedKelasId.isNotEmpty) {
      query = query.eq('kelas_id', normalizeIdValue(normalizedKelasId));
    }

    final normalizedMapelId = mapelId?.trim();
    if (normalizedMapelId != null && normalizedMapelId.isNotEmpty) {
      query = query.eq('mapel_id', normalizeIdValue(normalizedMapelId));
    }

    final normalizedTahunAjaranId = tahunAjaranId?.trim();
    if (normalizedTahunAjaranId != null && normalizedTahunAjaranId.isNotEmpty) {
      query = query.eq(
        'tahun_ajaran_id',
        normalizeIdValue(normalizedTahunAjaranId),
      );
    }

    final rows = await query;
    return mapResponseList(rows);
  }

  Future<List<NilaiRecord>> getByWaliKelasScope({
    required Iterable<String> allowedKelasIds,
    required Iterable<String> allowedTahunAjaranIds,
    String? kelasId,
    String? mapelId,
    String? tahunAjaranId,
  }) async {
    final normalizedAllowedKelas = allowedKelasIds
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final normalizedAllowedTahunAjaran = allowedTahunAjaranIds
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);

    if (normalizedAllowedKelas.isEmpty ||
        normalizedAllowedTahunAjaran.isEmpty) {
      return const <NilaiRecord>[];
    }

    final normalizedKelasId = kelasId?.trim();
    if (normalizedKelasId != null &&
        normalizedKelasId.isNotEmpty &&
        !normalizedAllowedKelas.contains(normalizedKelasId)) {
      return const <NilaiRecord>[];
    }

    final normalizedTahunAjaranId = tahunAjaranId?.trim();
    if (normalizedTahunAjaranId != null &&
        normalizedTahunAjaranId.isNotEmpty &&
        !normalizedAllowedTahunAjaran.contains(normalizedTahunAjaranId)) {
      return const <NilaiRecord>[];
    }

    dynamic query = client
        .from(table)
        .select(
          'id, siswa_uid, kelas_id, mapel_id, guru_uid, tahun_ajaran_id, nilai_uts, nilai_uas, created_at, updated_at, is_deleted, siswa:siswa_uid(user_id), guru:guru_uid(user_id)',
        )
        .eq('is_deleted', false);

    if (normalizedKelasId != null && normalizedKelasId.isNotEmpty) {
      query = query.eq('kelas_id', normalizeIdValue(normalizedKelasId));
    } else {
      query = query.inFilter(
        'kelas_id',
        normalizedAllowedKelas
            .map((item) => normalizeIdValue(item))
            .toList(growable: false),
      );
    }

    if (normalizedTahunAjaranId != null && normalizedTahunAjaranId.isNotEmpty) {
      query = query.eq(
        'tahun_ajaran_id',
        normalizeIdValue(normalizedTahunAjaranId),
      );
    } else {
      query = query.inFilter(
        'tahun_ajaran_id',
        normalizedAllowedTahunAjaran
            .map((item) => normalizeIdValue(item))
            .toList(growable: false),
      );
    }

    final normalizedMapelId = mapelId?.trim();
    if (normalizedMapelId != null && normalizedMapelId.isNotEmpty) {
      query = query.eq('mapel_id', normalizeIdValue(normalizedMapelId));
    }

    final rows = await query;
    return (rows as List<dynamic>)
        .map((row) {
          final record = Map<String, dynamic>.from(row as Map);
          final siswa = record['siswa'];
          final guru = record['guru'];
          return NilaiRecord.fromJson(<String, dynamic>{
            ...record,
            'siswa_user_id': siswa is Map
                ? Map<String, dynamic>.from(siswa)['user_id']
                : null,
            'guru_user_id': guru is Map
                ? Map<String, dynamic>.from(guru)['user_id']
                : null,
          }, id: record['id']?.toString() ?? '');
        })
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> _normalizePayloadAsync(
    Map<String, dynamic> payload,
  ) async {
    final normalized = <String, dynamic>{};
    final siswaRef =
        payload['siswa_uid'] ?? payload['siswa_id'] ?? payload['siswaId'];
    final guruRef =
        payload['guru_uid'] ?? payload['guru_id'] ?? payload['guruId'];

    if (siswaRef != null) {
      normalized['siswa_uid'] = await _resolveSiswaInternalId(siswaRef);
    }
    if (guruRef != null) {
      normalized['guru_uid'] = await _resolveGuruInternalId(guruRef);
    }
    if (payload.containsKey('mapel_id') ||
        payload.containsKey('mata_pelajaran_id')) {
      normalized['mapel_id'] = normalizeIdValue(
        payload['mapel_id'] ?? payload['mata_pelajaran_id'],
      );
    }
    if (payload.containsKey('kelas_id')) {
      normalized['kelas_id'] = normalizeIdValue(payload['kelas_id']);
    }
    if (payload.containsKey('tahun_ajaran_id')) {
      normalized['tahun_ajaran_id'] = normalizeIdValue(
        payload['tahun_ajaran_id'],
      );
    }
    if (payload.containsKey('nilai_uts') || payload.containsKey('uts')) {
      normalized['nilai_uts'] = ModelUtils.doubleValue(
        payload['nilai_uts'] ?? payload['uts'],
      );
    }
    if (payload.containsKey('nilai_uas') || payload.containsKey('uas')) {
      normalized['nilai_uas'] = ModelUtils.doubleValue(
        payload['nilai_uas'] ?? payload['uas'],
      );
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

    final resolved = <String, Object>{};
    final userIds = <String>[];
    for (final value in normalized) {
      final integerValue = int.tryParse(value);
      if (integerValue != null) {
        resolved[value] = integerValue;
      } else {
        userIds.add(value);
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

  Iterable<List<Map<String, dynamic>>> _chunk(
    List<Map<String, dynamic>> items,
    int size,
  ) sync* {
    if (items.isEmpty) {
      return;
    }

    for (var index = 0; index < items.length; index += size) {
      final end = (index + size) < items.length ? (index + size) : items.length;
      yield items.sublist(index, end);
    }
  }
}
