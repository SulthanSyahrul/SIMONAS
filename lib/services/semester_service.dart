import '../models/model_utils.dart';
import '../models/semester_model.dart';
import 'supabase_crud_service.dart';

class SemesterService extends SupabaseCrudService<SemesterRecord> {
  SemesterService({super.client}) : super('semester');

  @override
  SemesterRecord fromJson(String id, Map<String, dynamic> json) =>
      SemesterRecord.fromJson(json, id: id);

  @override
  Map<String, dynamic> toJson(SemesterRecord value) => value.toJson();

  @override
  Map<String, dynamic> preparePayload(
    Map<String, dynamic> payload, {
    required bool isUpdate,
  }) {
    final normalized = <String, dynamic>{};
    if (payload.containsKey('tahun_ajaran_id')) {
      normalized['tahun_ajaran_id'] = normalizeIdValue(
        payload['tahun_ajaran_id'],
      );
    }
    if (payload.containsKey('semester_ke')) {
      normalized['semester_ke'] = ModelUtils.integerOrNull(
        payload['semester_ke'],
      );
    } else if (payload.containsKey('semester')) {
      normalized['semester_ke'] = ModelUtils.integerOrNull(payload['semester']);
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

  Future<SemesterRecord?> getActiveSemester() async {
    try {
      final row = await client
          .from(table)
          .select(selectStatement)
          .eq('is_aktif', true)
          .eq('is_deleted', false)
          .order('updated_at', ascending: false)
          .maybeSingle();
      if (row == null) return null;
      return mapResponseSingle(row);
    } catch (error) {
      throw Exception('Gagal mengambil semester aktif: $error');
    }
  }

  Future<SemesterRecord?> getActiveSemesterForTahunAjaran(
    String tahunAjaranId,
  ) async {
    try {
      final row = await client
          .from(table)
          .select(selectStatement)
          .eq('tahun_ajaran_id', normalizeIdValue(tahunAjaranId))
          .eq('is_aktif', true)
          .eq('is_deleted', false)
          .order('updated_at', ascending: false)
          .maybeSingle();
      if (row == null) return null;
      return mapResponseSingle(row);
    } catch (error) {
      throw Exception(
        'Gagal mengambil semester aktif untuk tahun ajaran $tahunAjaranId: $error',
      );
    }
  }

  Future<SemesterRecord?> getByTahunAjaranDanSemester({
    required String tahunAjaranId,
    required int semesterKe,
  }) async {
    try {
      final row = await client
          .from(table)
          .select(selectStatement)
          .eq('tahun_ajaran_id', normalizeIdValue(tahunAjaranId))
          .eq('semester_ke', semesterKe)
          .eq('is_deleted', false)
          .maybeSingle();
      if (row == null) return null;
      return mapResponseSingle(row);
    } catch (error) {
      throw Exception(
        'Gagal mengambil semester $semesterKe untuk tahun ajaran $tahunAjaranId: $error',
      );
    }
  }

  Future<List<SemesterRecord>> getByTahunAjaran(String tahunAjaranId) async {
    try {
      final rows = await client
          .from(table)
          .select(selectStatement)
          .eq('tahun_ajaran_id', normalizeIdValue(tahunAjaranId))
          .eq('is_deleted', false)
          .order('semester_ke');
      return mapResponseList(rows);
    } catch (error) {
      throw Exception(
        'Gagal mengambil semester untuk tahun ajaran $tahunAjaranId: $error',
      );
    }
  }
}
