import '../models/model_utils.dart';
import '../models/guru_model.dart';
import 'supabase_crud_service.dart';
import 'user_service.dart';

class GuruService extends SupabaseCrudService<GuruRecord> {
  GuruService({super.client}) : super('guru');

  @override
  GuruRecord fromJson(String id, Map<String, dynamic> json) =>
      GuruRecord.fromJson(json, id: id);

  @override
  Map<String, dynamic> toJson(GuruRecord value) => value.toJson();

  @override
  Map<String, dynamic> preparePayload(
    Map<String, dynamic> payload, {
    required bool isUpdate,
  }) {
    final normalized = <String, dynamic>{};
    final uid = ModelUtils.nullableString(payload['user_id'] ?? payload['uid']);

    if (uid != null) {
      normalized['user_id'] = uid;
    }
    if (payload.containsKey('nama_lengkap') || payload.containsKey('nama')) {
      normalized['nama_lengkap'] = ModelUtils.nullableString(
        payload['nama_lengkap'] ?? payload['nama'],
      );
    }
    if (payload.containsKey('nip')) normalized['nip'] = ModelUtils.nullableString(payload['nip']);
    if (payload.containsKey('nuptk')) normalized['nuptk'] = ModelUtils.nullableString(payload['nuptk']);
    if (payload.containsKey('golongan')) normalized['golongan'] = ModelUtils.nullableString(payload['golongan']);
    if (payload.containsKey('no_hp') || payload.containsKey('noHp')) {
      normalized['no_hp'] = ModelUtils.nullableString(payload['no_hp'] ?? payload['noHp']);
    }
    if (payload.containsKey('alamat')) normalized['alamat'] = ModelUtils.nullableString(payload['alamat']);
    if (payload.containsKey('tanggal_lahir')) {
      normalized['tanggal_lahir'] = ModelUtils.isoDate(payload['tanggal_lahir']);
    }
    if (payload.containsKey('tempat_lahir') || payload.containsKey('tempatLahir')) {
      normalized['tempat_lahir'] = ModelUtils.nullableString(
        payload['tempat_lahir'] ?? payload['tempatLahir'],
      );
    }
    if (payload.containsKey('jenis_kelamin') || payload.containsKey('gender')) {
      normalized['jenis_kelamin'] = ModelUtils.nullableString(
        payload['jenis_kelamin'] ?? payload['gender'],
      );
    }
    if (payload.containsKey('is_deleted')) {
      normalized['is_deleted'] = ModelUtils.boolean(payload['is_deleted']);
    }

    return super.preparePayload(normalized, isUpdate: isUpdate);
  }

  @override
  Future<GuruRecord> create(dynamic value, {String? id}) async {
    final payload = preparePayload(payloadFromValue(value), isUpdate: false);
    await _ensureRequiredName(payload);
    return super.create(payload, id: id);
  }

  Future<GuruRecord?> getFirstByUid(String uid) async {
    final rows = await getByUid(uid);
    if (rows.isEmpty) {
      return null;
    }
    return rows.first;
  }

  Future<List<GuruRecord>> getAllLite({bool includeDeleted = false}) async {
    return super.getAll(includeDeleted: includeDeleted);
  }

  Future<List<GuruRecord>> getByUid(String uid) async {
    try {
      final rows = await client
          .from(table)
          .select(selectStatement)
          .eq('user_id', uid.trim())
          .eq('is_deleted', false)
          .limit(1);
      return mapResponseList(rows);
    } catch (error) {
      throw Exception('Gagal mengambil profil guru $uid: $error');
    }
  }

  Future<List<GuruRecord>> getByUids(Iterable<String> uids) async {
    final normalized = uids
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (normalized.isEmpty) {
      return const <GuruRecord>[];
    }

    try {
      final rows = await client
          .from(table)
          .select(selectStatement)
          .inFilter('user_id', normalized)
          .eq('is_deleted', false);
      return mapResponseList(rows);
    } catch (error) {
      throw Exception('Gagal mengambil profil guru berdasarkan daftar UID: $error');
    }
  }

  Future<void> _ensureRequiredName(Map<String, dynamic> payload) async {
    final currentName = ModelUtils.nullableString(payload['nama_lengkap']);
    if (currentName != null) {
      return;
    }

    final uid = ModelUtils.nullableString(payload['user_id']);
    if (uid == null) {
      payload['nama_lengkap'] = '';
      return;
    }

    final users = await UserService(client: client).getByUserId(uid);
    if (users.isNotEmpty) {
      payload['nama_lengkap'] = users.first.nama;
      return;
    }

    payload['nama_lengkap'] = uid;
  }
}
