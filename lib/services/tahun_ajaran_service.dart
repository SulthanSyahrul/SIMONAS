import '../models/model_utils.dart';
import '../models/tahun_ajaran_model.dart';
import 'supabase_crud_service.dart';

class TahunAjaranService extends SupabaseCrudService<TahunAjaranRecord> {
  TahunAjaranService({super.client}) : super('tahun_ajaran');

  @override
  String get selectStatement =>
      '*, semester_aktif:semester(id, tahun_ajaran_id, semester_ke, updated_at, is_aktif, is_deleted)';

  @override
  TahunAjaranRecord fromJson(String id, Map<String, dynamic> json) =>
      TahunAjaranRecord.fromJson(json, id: id);

  @override
  Map<String, dynamic> toJson(TahunAjaranRecord value) => value.toJson();

  @override
  Future<List<Map<String, dynamic>>> transformRows(
    List<Map<String, dynamic>> rows,
  ) async {
    return rows.map((row) {
      final rawSemesters = row['semester_aktif'];
      final candidates = rawSemesters is List
          ? rawSemesters
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .where(
                (item) =>
                    ModelUtils.boolean(item['is_aktif']) &&
                    !ModelUtils.boolean(item['is_deleted']),
              )
              .toList()
          : <Map<String, dynamic>>[];

      candidates.sort((a, b) {
        final aUpdated = ModelUtils.dateTime(a['updated_at']);
        final bUpdated = ModelUtils.dateTime(b['updated_at']);
        if (aUpdated == null && bUpdated == null) {
          return 0;
        }
        if (aUpdated == null) {
          return 1;
        }
        if (bUpdated == null) {
          return -1;
        }
        return bUpdated.compareTo(aUpdated);
      });

      return {
        ...row,
        'semester_aktif': candidates.isEmpty
            ? row['semester_aktif']
            : candidates.first['semester_ke'],
      };
    }).toList(growable: false);
  }

  @override
  Map<String, dynamic> preparePayload(
    Map<String, dynamic> payload, {
    required bool isUpdate,
  }) {
    final normalized = <String, dynamic>{};
    if (payload.containsKey('tahun_ajaran') || payload.containsKey('nama')) {
      normalized['tahun_ajaran'] = ModelUtils.nullableString(
        payload['tahun_ajaran'] ?? payload['nama'],
      );
    }
    if (payload.containsKey('is_aktif') || payload.containsKey('aktif')) {
      normalized['is_aktif'] = ModelUtils.boolean(
        payload['is_aktif'] ?? payload['aktif'],
      );
    }
    if (payload.containsKey('is_deleted')) {
      normalized['is_deleted'] = ModelUtils.boolean(payload['is_deleted']);
    }
    return super.preparePayload(normalized, isUpdate: isUpdate);
  }

  Future<List<TahunAjaranRecord>> getActiveTahunAjaran() async {
    try {
      final rows = await client
          .from(table)
          .select(selectStatement)
          .eq('is_aktif', true)
          .eq('is_deleted', false)
          .order('updated_at', ascending: false);
      return _attachSemesterAktif(await mapResponseList(rows));
    } catch (error) {
      throw Exception('Gagal mengambil tahun ajaran aktif: $error');
    }
  }

  Future<List<TahunAjaranRecord>> getAllLite({bool includeDeleted = false}) async {
    return super.getAll(includeDeleted: includeDeleted);
  }

  Future<List<TahunAjaranRecord>> _attachSemesterAktif(
    List<TahunAjaranRecord> rows,
  ) async {
    return rows;
  }

  @override
  Future<List<TahunAjaranRecord>> getAllIncremental({
    bool forceFullFetch = false,
    bool includeDeleted = false,
  }) async {
    final rows = await super.getAllIncremental(
      forceFullFetch: forceFullFetch,
      includeDeleted: includeDeleted,
    );
    return _attachSemesterAktif(rows);
  }

  @override
  Future<List<TahunAjaranRecord>> getAll({bool includeDeleted = false}) async {
    final rows = await super.getAll(includeDeleted: includeDeleted);
    return _attachSemesterAktif(rows);
  }
}
