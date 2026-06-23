import '../models/jadwal_model.dart';
import '../models/model_utils.dart';
import 'guru_service.dart';
import 'semester_service.dart';
import 'supabase_crud_service.dart';

class JadwalService extends SupabaseCrudService<JadwalRecord> {
  JadwalService({super.client}) : super('jadwal');

  final Map<String, List<int>> _guruCandidateIdsCache = <String, List<int>>{};
  final Map<String, String> _semesterIdsCache = <String, String>{};
  final Map<String, int> _guruInternalIdsCache = <String, int>{};

  @override
  String get selectStatement =>
      '*, '
      'semester:semester_id(id, tahun_ajaran_id, semester_ke, is_deleted), '
      'guru:guru_uid(id, user_id), '
      'kelas:kelas_id(id, nama_kelas), '
      'mapel:mapel_id(id, nama_mapel)';

  @override
  JadwalRecord fromJson(String id, Map<String, dynamic> json) =>
      JadwalRecord.fromJson(json, id: id);

  @override
  Map<String, dynamic> toJson(JadwalRecord value) => value.toJson();

  @override
  Future<List<Map<String, dynamic>>> transformRows(
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) return rows;

    final semesterIds = rows
        .map((r) => ModelUtils.integerOrNull(r['semester_id']))
        .whereType<int>()
        .toSet()
        .toList(growable: false);

    final embeddedSemesterIds = rows
        .map((r) {
          final embedded = r['semester'];
          if (embedded is! Map) return null;
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
        final rec = Map<String, dynamic>.from(row as Map);
        final rid = ModelUtils.integerOrNull(rec['id']);
        if (rid != null) semesterById[rid] = rec;
      }
    }

    final guruIds = rows
        .map((r) => ModelUtils.integerOrNull(r['guru_uid']))
        .whereType<int>()
        .toSet()
        .toList(growable: false);
    final embeddedGuruIds = rows
        .map((r) {
          final embedded = r['guru'];
          if (embedded is! Map) return null;
          return ModelUtils.integerOrNull(embedded['id']);
        })
        .whereType<int>()
        .toSet()
        .toList(growable: false);
    final guruIdsToFetch = guruIds.where((id) => !embeddedGuruIds.contains(id)).toList(growable: false);

    final guruById = <int, Map<String, dynamic>>{};
    if (guruIdsToFetch.isNotEmpty) {
      final guruRows = await client
          .from('guru')
          .select('id, user_id')
          .inFilter('id', guruIdsToFetch)
          .eq('is_deleted', false);
      for (final row in guruRows as List<dynamic>) {
        final rec = Map<String, dynamic>.from(row as Map);
        final rid = ModelUtils.integerOrNull(rec['id']);
        if (rid != null) guruById[rid] = rec;
      }
    }

    return rows.map((row) {
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

      final jamAwal = ModelUtils.integerOrNull(row['jam_ke_awal'] ?? row['jam_awal'] ?? row['jamAwal']) ?? 1;
      final jamAkhir = ModelUtils.integerOrNull(row['jam_ke_akhir'] ?? row['jam_akhir'] ?? row['jamAkhir']) ?? jamAwal;

      return {
        ...row,
        'guru_user_id': guru?['user_id'],
        'semester_tahun_ajaran_id': semester?['tahun_ajaran_id'],
        'semester_ke': semester?['semester_ke'],
        'kelas_nama': embeddedKelas is Map
            ? embeddedKelas['nama_kelas']
            : row['kelas_nama'],
        'mapel_nama': embeddedMapel is Map
            ? embeddedMapel['nama_mapel']
            : row['mapel_nama'],
        'waktu_mulai': _getWaktuMulai(jamAwal),
        'waktu_selesai': _getWaktuSelesai(jamAkhir),
      };
    }).toList(growable: false);
  }

  @override
  Future<JadwalRecord> create(dynamic value, {String? id}) async {
    final payload = await _normalizePayloadAsync(payloadFromValue(value));
    return super.create(payload, id: id);
  }

  @override
  Future<JadwalRecord> update(String id, dynamic value) async {
    final existing = await getById(id);
    final payload = await _normalizePayloadAsync(
      payloadFromValue(value),
      existing: existing,
    );
    return super.update(id, payload);
  }
  Future<List<JadwalRecord>> getByGuruAndTahunAjaran(
    String guruUid,
    String tahunAjaranId, {
    bool forceFullFetch = false,
    int? semester,
    String? semesterId,
  }) async {
    final guruIds = await _resolveGuruCandidateIds(guruUid);
    if (guruIds.isEmpty) return const <JadwalRecord>[];

    final selectQuery =
        '*, '
        'semester:semester_id!inner(id, tahun_ajaran_id, semester_ke, is_deleted), '
        'guru:guru_uid(id, user_id), '
        'kelas:kelas_id(id, nama_kelas), '
        'mapel:mapel_id(id, nama_mapel)';

    dynamic query = client
        .from(table)
        .select(selectQuery)
        .eq('is_deleted', false)
        .eq('semester.tahun_ajaran_id', normalizeIdValue(tahunAjaranId))
        .eq('semester.is_deleted', false);
    if (semesterId != null && semesterId.trim().isNotEmpty) {
      query = query.eq('semester_id', normalizeIdValue(semesterId));
    } else if (semester != null) {
      query = query.eq('semester.semester_ke', semester);
    }
    query = guruIds.length == 1 ? query.eq('guru_uid', guruIds.first) : query.inFilter('guru_uid', guruIds);

    final rows = await query;
    return mapResponseList(rows);
  }

  Future<List<JadwalRecord>> getByTahunAjaranId(
    String tahunAjaranId, {
    bool forceFullFetch = false,
    int? semester,
  }) async {
    dynamic query = client
        .from(table)
        .select(
          '*, '
          'semester:semester_id!inner(id, tahun_ajaran_id, semester_ke, is_deleted), '
          'guru:guru_uid(id, user_id), '
          'kelas:kelas_id(id, nama_kelas), '
          'mapel:mapel_id(id, nama_mapel)',
        )
        .eq('is_deleted', false)
        .eq('semester.tahun_ajaran_id', normalizeIdValue(tahunAjaranId))
        .eq('semester.is_deleted', false);
    if (semester != null) {
      query = query.eq('semester.semester_ke', semester);
    }
    final rows = await query;
    return mapResponseList(rows);
  }

  Future<bool> existsGuruOverlapRange({
    required String guruUid,
    required String hari,
    required int jamMulai,
    required int jamSelesai,
    required String tahunAjaranId,
    int semester = 1,
    Iterable<String> excludeIds = const <String>[],
  }) async {
    final guruIds = await _resolveGuruCandidateIds(guruUid);
    if (guruIds.isEmpty) return false;

    final semesterId = await _resolveSemesterId({
      'tahun_ajaran_id': tahunAjaranId,
      'semester': semester,
    });
    if (semesterId == null) return false;

    final dayNum = ModelUtils.dayNumber(hari);
    final excludeSet = excludeIds.map((e) => e.trim()).toSet();

    var query = client
        .from(table)
        .select('id')
        .eq('semester_id', normalizeIdValue(semesterId))
        .eq('hari_ke', dayNum)
        .eq('is_deleted', false)
        .lte('jam_ke_awal', jamSelesai)
        .gte('jam_ke_akhir', jamMulai);

    if (guruIds.length == 1) {
      query = query.eq('guru_uid', guruIds.first);
    } else {
      query = query.inFilter('guru_uid', guruIds);
    }

    final rows = await query;
    return (rows as List<dynamic>).any((r) => !excludeSet.contains(r['id']?.toString()));
  }

  Future<bool> existsKelasOverlapRange({
    required String kelasId,
    required String hari,
    required int jamMulai,
    required int jamSelesai,
    required String tahunAjaranId,
    int semester = 1,
    Iterable<String> excludeIds = const <String>[],
  }) async {
    final semesterId = await _resolveSemesterId({
      'tahun_ajaran_id': tahunAjaranId,
      'semester': semester,
    });
    if (semesterId == null) return false;

    final dayNum = ModelUtils.dayNumber(hari);
    final excludeSet = excludeIds.map((e) => e.trim()).toSet();

    final rows = await client
        .from(table)
        .select('id')
        .eq('semester_id', normalizeIdValue(semesterId))
        .eq('kelas_id', normalizeIdValue(kelasId))
        .eq('hari_ke', dayNum)
        .eq('is_deleted', false)
        .lte('jam_ke_awal', jamSelesai)
        .gte('jam_ke_akhir', jamMulai);

    return (rows as List<dynamic>).any((r) => !excludeSet.contains(r['id']?.toString()));
  }

  Future<Map<String, dynamic>> _normalizePayloadAsync(
    Map<String, dynamic> payload, {
    JadwalRecord? existing,
  }) async {
    final normalized = <String, dynamic>{};

    final guruRef = payload['guru_uid'] ?? payload['guru_id'] ?? payload['guruId'];
    if (guruRef != null) {
      normalized['guru_uid'] = await _resolveGuruInternalId(guruRef);
    }
    if (payload.containsKey('kelas_id') || payload.containsKey('kelasId')) {
      normalized['kelas_id'] = normalizeIdValue(payload['kelas_id'] ?? payload['kelasId']);
    }
    if (payload.containsKey('mapel_id') || payload.containsKey('mapelId')) {
      normalized['mapel_id'] = normalizeIdValue(payload['mapel_id'] ?? payload['mapelId']);
    }

    final semesterId = await _resolveSemesterId(payload, fallbackTahunAjaranId: existing?.tahunAjaranId, fallbackSemester: existing?.semester, fallbackSemesterId: existing?.semesterId);
    if (semesterId != null) normalized['semester_id'] = semesterId;

    if (payload.containsKey('hari') || payload.containsKey('hari_ke')) {
      normalized['hari_ke'] = ModelUtils.dayNumber(payload['hari'] ?? payload['hari_ke']);
    }
    if (payload.containsKey('jam_awal') || payload.containsKey('jam_ke_awal') || payload.containsKey('jamAwal')) {
      normalized['jam_ke_awal'] = ModelUtils.integer(payload['jam_awal'] ?? payload['jam_ke_awal'] ?? payload['jamAwal']);
    }
    if (payload.containsKey('jam_akhir') || payload.containsKey('jam_ke_akhir') || payload.containsKey('jamAkhir')) {
      normalized['jam_ke_akhir'] = ModelUtils.integer(payload['jam_akhir'] ?? payload['jam_ke_akhir'] ?? payload['jamAkhir']);
    }
    if (payload.containsKey('is_deleted')) normalized['is_deleted'] = ModelUtils.boolean(payload['is_deleted']);

    return normalized;
  }

  Future<Object?> _resolveSemesterId(
    Map<String, dynamic> payload, {
    String? fallbackTahunAjaranId,
    int? fallbackSemester,
    String? fallbackSemesterId,
  }) async {
    if (payload['semester_id'] != null) return normalizeIdValue(payload['semester_id']);

    final semesterKe = payload.containsKey('semester_ke') ? ModelUtils.integerOrNull(payload['semester_ke']) : ModelUtils.integerOrNull(payload['semester']);
    final tahunAjaranId = ModelUtils.nullableString(payload['tahun_ajaran_id'] ?? fallbackTahunAjaranId);

    if (tahunAjaranId != null && (semesterKe ?? fallbackSemester) != null) {
      final cacheKey = '${tahunAjaranId}_${semesterKe ?? fallbackSemester}';
      if (_semesterIdsCache.containsKey(cacheKey)) {
        return normalizeIdValue(_semesterIdsCache[cacheKey]!);
      }

      final semesterRecord = await SemesterService(client: client).getByTahunAjaranDanSemester(
        tahunAjaranId: tahunAjaranId,
        semesterKe: semesterKe ?? fallbackSemester!,
      );
      if (semesterRecord == null) throw Exception('Semester tidak ditemukan untuk tahun ajaran $tahunAjaranId.');
      
      _semesterIdsCache[cacheKey] = semesterRecord.id.toString();
      return normalizeIdValue(semesterRecord.id);
    }

    if (fallbackSemesterId != null) return normalizeIdValue(fallbackSemesterId);
    return null;
  }

  Future<Object> _resolveGuruInternalId(dynamic value) async {
    final raw = ModelUtils.string(value).trim();
    final integerValue = int.tryParse(raw);
    if (integerValue != null) return integerValue;

    if (_guruInternalIdsCache.containsKey(raw)) {
      return _guruInternalIdsCache[raw]!;
    }

    final guru = await GuruService(client: client).getFirstByUid(raw);
    if (guru == null) throw Exception('Profil guru dengan UID $raw tidak ditemukan.');
    
    final idInt = int.parse(guru.id);
    _guruInternalIdsCache[raw] = idInt;
    return idInt;
  }

  Future<List<int>> _resolveGuruCandidateIds(String guruUid) async {
    final raw = guruUid.trim();
    final cached = _guruCandidateIdsCache[raw];
    if (cached != null) {
      return cached;
    }

    final integerValue = int.tryParse(raw);
    if (integerValue != null) {
      final result = <int>[integerValue];
      _guruCandidateIdsCache[raw] = result;
      return result;
    }

    final guru = await GuruService(client: client).getFirstByUid(raw);
    if (guru == null) {
      _guruCandidateIdsCache[raw] = const <int>[];
      return const <int>[];
    }
    final result = <int>[int.parse(guru.id)];
    _guruCandidateIdsCache[raw] = result;
    return result;
  }

  String? _getWaktuMulai(int jam) => ModelUtils.getWaktuMulai(jam);

  String? _getWaktuSelesai(int jam) => ModelUtils.getWaktuSelesai(jam);
}
