import '../models/kelas_model.dart';
import '../models/model_utils.dart';
import 'guru_service.dart';
import 'supabase_crud_service.dart';
import 'tahun_ajaran_service.dart';

class KelasService extends SupabaseCrudService<KelasRecord> {
  KelasService({super.client}) : super('kelas');

  @override
  KelasRecord fromJson(String id, Map<String, dynamic> json) =>
      KelasRecord.fromJson(json, id: id);

  @override
  Map<String, dynamic> toJson(KelasRecord value) => value.toJson();

  @override
  Map<String, dynamic> preparePayload(
    Map<String, dynamic> payload, {
    required bool isUpdate,
  }) {
    final normalized = <String, dynamic>{};
    if (payload.containsKey('nama_kelas') || payload.containsKey('namaKelas')) {
      normalized['nama_kelas'] = ModelUtils.nullableString(
        payload['nama_kelas'] ?? payload['namaKelas'],
      );
    }
    if (payload.containsKey('tingkat')) {
      normalized['tingkat'] = ModelUtils.integerOrNull(payload['tingkat']);
    } else if (payload.containsKey('nama_kelas') || payload.containsKey('namaKelas')) {
      final nama = ModelUtils.string(payload['nama_kelas'] ?? payload['namaKelas']);
      final inferred = RegExp(r'(\d+)').firstMatch(nama);
      if (inferred != null) {
        normalized['tingkat'] = int.tryParse(inferred.group(1)!);
      }
    }
    if (payload.containsKey('is_deleted')) {
      normalized['is_deleted'] = ModelUtils.boolean(payload['is_deleted']);
    }
    return super.preparePayload(normalized, isUpdate: isUpdate);
  }

  Future<List<KelasRecord>> getByUserId(
    String uid, {
    bool forceFullFetch = false,
  }) async {
    final guru = await GuruService(client: client).getFirstByUid(uid);
    if (guru == null) {
      return const <KelasRecord>[];
    }

    final activeYear = await TahunAjaranService(client: client).getActiveTahunAjaran();
    final histQuery = client
        .from('histori_wali_kelas')
        .select('kelas_id, tahun_ajaran_id')
        .eq('guru_uid', normalizeIdValue(guru.id))
        .eq('is_deleted', false);

    dynamic rows = histQuery;
    if (activeYear.isNotEmpty) {
      rows = rows.eq(
        'tahun_ajaran_id',
        normalizeIdValue(activeYear.first.id),
      );
    }

    final history = await rows;
    final kelasIds = (history as List<dynamic>)
        .map((row) => ModelUtils.integerOrNull((row as Map)['kelas_id']))
        .whereType<int>()
        .toList(growable: false);
    if (kelasIds.isEmpty) {
      return const <KelasRecord>[];
    }

    final kelasRows = await client
        .from(table)
        .select(selectStatement)
        .inFilter('id', kelasIds)
        .eq('is_deleted', false);
    final result = await mapResponseList(kelasRows);
    return result
        .map(
          (item) => item.copyWith(
            waliKelasUid: uid,
            tahunAjaranId: activeYear.isEmpty ? item.tahunAjaranId : activeYear.first.id,
          ),
        )
        .toList(growable: false);
  }
}
