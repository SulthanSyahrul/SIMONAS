import '../models/jurnal_model.dart';
import '../models/model_utils.dart';
import 'guru_service.dart';
import 'semester_service.dart';
import 'supabase_crud_service.dart';

class JurnalHistoryPage {
  final List<JurnalRecord> data;
  final int nextOffset;
  final bool hasMore;

  const JurnalHistoryPage({
    required this.data,
    required this.nextOffset,
    required this.hasMore,
  });
}

class JurnalService extends SupabaseCrudService<JurnalRecord> {
  JurnalService({super.client}) : super('jurnal');

  final Map<String, List<int>> _guruCandidateIdsCache = <String, List<int>>{};
  static const String _joinedSelectQuery =
      '*, '
      'semester:semester_id!inner(id, tahun_ajaran_id, semester_ke, is_deleted, tahun_ajaran:tahun_ajaran_id(id, tahun_ajaran, is_aktif)), '
      'guru:guru_uid(id, user_id, nama_lengkap), '
      'kelas:kelas_id(id, nama_kelas), '
      'mapel:mapel_id(id, nama_mapel)';

  @override
  JurnalRecord fromJson(String id, Map<String, dynamic> json) =>
      JurnalRecord.fromJson(json, id: id);

  @override
  Map<String, dynamic> toJson(JurnalRecord value) => value.toJson();

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
          if (embedded is! Map<String, dynamic>) {
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
          if (embedded is! Map<String, dynamic>) {
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
          final embeddedTahunAjaran =
              embeddedSemester is Map<String, dynamic>
              ? embeddedSemester['tahun_ajaran']
              : null;
          final semester = embeddedSemester is Map
              ? Map<String, dynamic>.from(embeddedSemester)
              : semesterById[ModelUtils.integerOrNull(row['semester_id'])];
          final guru = embeddedGuru is Map
              ? Map<String, dynamic>.from(embeddedGuru)
              : guruById[ModelUtils.integerOrNull(row['guru_uid'])];
          final tahunAjaran = embeddedTahunAjaran is Map
              ? Map<String, dynamic>.from(embeddedTahunAjaran)
              : null;
          return <String, dynamic>{
            ...row,
            'guru_user_id': guru?['user_id'],
            'guru_nama': guru?['nama_lengkap'],
            'semester_tahun_ajaran_id': semester?['tahun_ajaran_id'],
            'semester_ke': semester?['semester_ke'],
            'tahun_ajaran_nama': tahunAjaran?['tahun_ajaran'],
            'tahun_ajaran_aktif': tahunAjaran?['is_aktif'],
            'kelas_nama': row['kelas'] is Map<String, dynamic>
                ? (row['kelas'] as Map<String, dynamic>)['nama_kelas']
                : row['kelas_nama'],
            'mapel_nama': row['mapel'] is Map<String, dynamic>
                ? (row['mapel'] as Map<String, dynamic>)['nama_mapel']
                : row['mapel_nama'],
          };
        })
        .toList(growable: false);
  }
  @override
  Future<JurnalRecord> create(dynamic value, {String? id}) async {
    final payload = await _normalizePayloadAsync(payloadFromValue(value));
    final prepared = preparePayload(payload, isUpdate: false);
    if (id != null && id.trim().isNotEmpty) {
      prepared['id'] = normalizeIdValue(id);
    }
    final row = await client
        .from(table)
        .insert(prepared)
        .select(_joinedSelectQuery)
        .single();
    return mapResponseSingle(row);
  }

  @override
  Future<JurnalRecord> update(String id, dynamic value) async {
    final existing = _needsExistingRecordForUpdate(value)
        ? await getById(id)
        : null;
    final payload = await _normalizePayloadAsync(
      payloadFromValue(value),
      existing: existing,
    );
    final prepared = preparePayload(payload, isUpdate: true);
    if (prepared.isEmpty) {
      if (existing == null) {
        final current = await getById(id);
        if (current == null) {
          throw Exception('Record $id tidak ditemukan di $table.');
        }
        return current;
      }
      return existing;
    }
    final row = await client
        .from(table)
        .update(prepared)
        .eq('id', normalizeIdValue(id))
        .select(_joinedSelectQuery)
        .single();
    return mapResponseSingle(row);
  }

  Future<List<JurnalRecord>> getJurnalByGuru(String guruUid) async {
    final guruIds = await _resolveGuruCandidateIds(guruUid);
    if (guruIds.isEmpty) {
      return const <JurnalRecord>[];
    }

    dynamic query = client
        .from(table)
        .select(selectStatement)
        .eq('is_deleted', false);
    query = guruIds.length == 1
        ? query.eq('guru_uid', guruIds.first)
        : query.inFilter('guru_uid', guruIds);
    final rows = await query;
    return mapResponseList(rows);
  }

  Future<List<JurnalRecord>> getJurnalByGuruAndContext({
    required String guruUid,
    required String tahunAjaranId,
    required int semester,
    String? semesterId,
  }) async {
    final guruIds = await _resolveGuruCandidateIds(guruUid);
    if (guruIds.isEmpty) {
      return const <JurnalRecord>[];
    }

    dynamic query = client
        .from(table)
        .select(_joinedSelectQuery)
        .eq('is_deleted', false)
        .eq('semester.tahun_ajaran_id', normalizeIdValue(tahunAjaranId))
        .eq('semester.is_deleted', false);
    if (semesterId != null && semesterId.trim().isNotEmpty) {
      query = query.eq('semester_id', normalizeIdValue(semesterId));
    } else {
      query = query.eq('semester.semester_ke', semester);
    }
    query = guruIds.length == 1
        ? query.eq('guru_uid', guruIds.first)
        : query.inFilter('guru_uid', guruIds);
    final rows = await query;
    final records = await mapResponseList(rows);
    return records
        .map(
          (record) => record.copyWith(
            tahunAjaranId: tahunAjaranId,
            semester: semester,
          ),
        )
        .toList(growable: false);
  }

  Future<List<JurnalRecord>> getJurnalByTanggal(DateTime tanggal) async {
    final normalizedDate = ModelUtils.isoDate(tanggal)!;
    final rows = await client
        .from(table)
        .select(selectStatement)
        .eq('tanggal', normalizedDate)
        .eq('is_deleted', false);
    return mapResponseList(rows);
  }

  Future<List<JurnalRecord>> getJurnalByTanggalLite(DateTime tanggal) async {
    final normalizedDate = ModelUtils.isoDate(tanggal)!;
    final rows = await client
        .from(table)
        .select(
          'id, guru_uid, kelas_id, mapel_id, status_kehadiran, tanggal, jam_ke_awal, jam_ke_akhir, updated_at, is_deleted',
        )
        .eq('tanggal', normalizedDate)
        .eq('is_deleted', false);

    return (rows as List<dynamic>)
        .map((row) {
          final record = Map<String, dynamic>.from(row as Map);
          return JurnalRecord.fromJson(
            record,
            id: record['id']?.toString() ?? '',
          );
        })
        .toList(growable: false);
  }

  Future<JurnalHistoryPage> getHistoryPage({
    DateTime? tanggal,
    String? guruUid,
    String? kelasId,
    int limit = 20,
    int? offset,
  }) async {
    final safeOffset = offset ?? 0;
    const extraFetch = 1;
    dynamic query = client
        .from(table)
        .select(_joinedSelectQuery)
        .eq('is_deleted', false);

    if (tanggal != null) {
      query = query.eq('tanggal', ModelUtils.isoDate(tanggal)!);
    }

    final normalizedGuruUid = guruUid?.trim();
    if (normalizedGuruUid != null &&
        normalizedGuruUid.isNotEmpty &&
        normalizedGuruUid != 'all') {
      final guruIds = await _resolveGuruCandidateIds(normalizedGuruUid);
      if (guruIds.isEmpty) {
        return const JurnalHistoryPage(
          data: <JurnalRecord>[],
          nextOffset: 0,
          hasMore: false,
        );
      }
      query = guruIds.length == 1
          ? query.eq('guru_uid', guruIds.first)
          : query.inFilter('guru_uid', guruIds);
    }

    final normalizedKelasId = kelasId?.trim();
    if (normalizedKelasId != null &&
        normalizedKelasId.isNotEmpty &&
        normalizedKelasId != 'all') {
      query = query.eq('kelas_id', normalizeIdValue(normalizedKelasId));
    }

    final rows = await query
        .order('updated_at', ascending: false)
        .order('tanggal', ascending: false)
        .range(safeOffset, safeOffset + limit + extraFetch - 1);
    final records = await mapResponseList(rows);
    final hasMore = records.length > limit;
    final pageData = hasMore
        ? records.take(limit).toList(growable: false)
        : records;
    final nextOffset = safeOffset + pageData.length;

    return JurnalHistoryPage(
      data: pageData,
      nextOffset: nextOffset,
      hasMore: hasMore,
    );
  }

  Future<Map<String, dynamic>> _normalizePayloadAsync(
    Map<String, dynamic> payload, {
    JurnalRecord? existing,
  }) async {
    final normalized = <String, dynamic>{};

    final guruRef =
        payload['guru_uid'] ?? payload['guru_id'] ?? payload['user_id'];
    if (guruRef != null) {
      normalized['guru_uid'] = await _resolveGuruInternalId(guruRef);
    }
    if (payload.containsKey('kelas_id') || payload.containsKey('kelasId')) {
      normalized['kelas_id'] = normalizeIdValue(
        payload['kelas_id'] ?? payload['kelasId'],
      );
    }
    if (payload.containsKey('mapel_id') ||
        payload.containsKey('mata_pelajaran_id') ||
        payload.containsKey('mataPelajaranId')) {
      normalized['mapel_id'] = normalizeIdValue(
        payload['mapel_id'] ??
            payload['mata_pelajaran_id'] ??
            payload['mataPelajaranId'],
      );
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

    if (payload.containsKey('tanggal')) {
      normalized['tanggal'] = ModelUtils.isoDate(payload['tanggal']);
    }
    if (payload.containsKey('jam_awal') ||
        payload.containsKey('jam_ke_awal') ||
        payload.containsKey('jamAwal') ||
        payload.containsKey('jam_ke')) {
      normalized['jam_ke_awal'] = ModelUtils.integer(
        payload['jam_awal'] ??
            payload['jam_ke_awal'] ??
            payload['jamAwal'] ??
            payload['jam_ke'],
      );
    }
    if (payload.containsKey('jam_akhir') ||
        payload.containsKey('jam_ke_akhir') ||
        payload.containsKey('jamAkhir')) {
      normalized['jam_ke_akhir'] = ModelUtils.integer(
        payload['jam_akhir'] ?? payload['jam_ke_akhir'] ?? payload['jamAkhir'],
      );
    }
    if (payload.containsKey('materi_pembelajaran') ||
        payload.containsKey('materi')) {
      normalized['materi_pembelajaran'] = ModelUtils.nullableString(
        payload['materi_pembelajaran'] ?? payload['materi'],
      );
    }
    if (payload.containsKey('catatan')) {
      normalized['catatan'] = ModelUtils.nullableString(payload['catatan']);
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

  bool _needsExistingRecordForUpdate(dynamic value) {
    final payload = payloadFromValue(value);
    if (payload['semester_id'] != null) {
      return false;
    }

    final hasSemesterContext =
        (payload['tahun_ajaran_id'] != null || payload['tahunAjaranId'] != null) &&
        (payload['semester'] != null || payload['semester_ke'] != null);
    if (hasSemesterContext) {
      return false;
    }

    return true;
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
}
