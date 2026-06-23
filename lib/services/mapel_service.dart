import '../models/mapel_model.dart';
import '../models/model_utils.dart';
import 'supabase_crud_service.dart';

class MapelService extends SupabaseCrudService<MapelRecord> {
  MapelService({super.client}) : super('mapel');

  @override
  MapelRecord fromJson(String id, Map<String, dynamic> json) =>
      MapelRecord.fromJson(json, id: id);

  @override
  Map<String, dynamic> toJson(MapelRecord value) => value.toJson();

  @override
  Map<String, dynamic> preparePayload(
    Map<String, dynamic> payload, {
    required bool isUpdate,
  }) {
    final normalized = <String, dynamic>{};
    if (payload.containsKey('nama_mapel') || payload.containsKey('namaMapel') || payload.containsKey('nama')) {
      normalized['nama_mapel'] = ModelUtils.nullableString(
        payload['nama_mapel'] ?? payload['namaMapel'] ?? payload['nama'],
      );
    }
    if (payload.containsKey('is_deleted')) {
      normalized['is_deleted'] = ModelUtils.boolean(payload['is_deleted']);
    }
    return super.preparePayload(normalized, isUpdate: isUpdate);
  }
}
