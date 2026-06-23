import '../models/model_utils.dart';
import '../models/siswa_model.dart';
import 'supabase_crud_service.dart';
import 'user_service.dart';

class SiswaService extends SupabaseCrudService<SiswaRecord> {
  SiswaService({super.client}) : super('siswa');

  static const int _liteBatchSize = 50;

  @override
  SiswaRecord fromJson(String id, Map<String, dynamic> json) =>
      SiswaRecord.fromJson(json, id: id);

  @override
  Map<String, dynamic> toJson(SiswaRecord value) => value.toJson();

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
    if (payload.containsKey('nis')) {
      normalized['nis'] = ModelUtils.nullableString(payload['nis']);
    }
    if (payload.containsKey('nama')) {
      normalized['nama'] = ModelUtils.nullableString(payload['nama']);
    }
    if (payload.containsKey('jenis_kelamin') || payload.containsKey('gender')) {
      normalized['jenis_kelamin'] = ModelUtils.nullableString(
        payload['jenis_kelamin'] ?? payload['gender'],
      );
    }
    if (payload.containsKey('tempat_lahir') ||
        payload.containsKey('tempatLahir')) {
      normalized['tempat_lahir'] = ModelUtils.nullableString(
        payload['tempat_lahir'] ?? payload['tempatLahir'],
      );
    }
    if (payload.containsKey('tanggal_lahir')) {
      normalized['tanggal_lahir'] = ModelUtils.isoDate(
        payload['tanggal_lahir'],
      );
    }
    if (payload.containsKey('alamat')) {
      normalized['alamat'] = ModelUtils.nullableString(payload['alamat']);
    }
    if (payload.containsKey('no_hp') || payload.containsKey('noHp')) {
      normalized['no_hp'] = ModelUtils.nullableString(
        payload['no_hp'] ?? payload['noHp'],
      );
    }
    if (payload.containsKey('is_deleted')) {
      normalized['is_deleted'] = ModelUtils.boolean(payload['is_deleted']);
    }

    return super.preparePayload(normalized, isUpdate: isUpdate);
  }

  @override
  Future<SiswaRecord> create(dynamic value, {String? id}) async {
    final payload = preparePayload(payloadFromValue(value), isUpdate: false);
    await _ensureRequiredName(payload);
    return super.create(payload, id: id);
  }

  Future<SiswaRecord?> getFirstByUid(String uid) async {
    final rows = await getByUid(uid);
    if (rows.isEmpty) {
      return null;
    }
    return rows.first;
  }

  Future<List<SiswaRecord>> getByUidsLite(Iterable<String> uids) async {
    final normalized = uids
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (normalized.isEmpty) {
      return const <SiswaRecord>[];
    }

    try {
      final recordsById = <String, SiswaRecord>{};
      for (final batch in _chunkIds(normalized, _liteBatchSize)) {
        final rows = await client
            .from(table)
            .select('id, user_id, nama, nis, is_deleted')
            .inFilter('user_id', batch)
            .eq('is_deleted', false);
        final batchRecords = await mapResponseList(rows);
        for (final record in batchRecords) {
          recordsById[record.uid] = record;
        }
      }
      return normalized
          .map((id) => recordsById[id])
          .whereType<SiswaRecord>()
          .toList(growable: false);
    } catch (error) {
      throw Exception(
        'Gagal mengambil profil siswa ringan berdasarkan daftar UID: $error',
      );
    }
  }

  Iterable<List<String>> _chunkIds(List<String> ids, int size) sync* {
    if (ids.isEmpty) {
      return;
    }
    for (var i = 0; i < ids.length; i += size) {
      final end = (i + size) < ids.length ? (i + size) : ids.length;
      yield ids.sublist(i, end);
    }
  }

  Future<List<SiswaRecord>> getByUid(String uid) async {
    try {
      final rows = await client
          .from(table)
          .select(selectStatement)
          .eq('user_id', uid.trim())
          .eq('is_deleted', false)
          .limit(1);
      return mapResponseList(rows);
    } catch (error) {
      throw Exception('Gagal mengambil profil siswa $uid: $error');
    }
  }

  Future<String?> getDisplayNameByUid(String uid) async {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) {
      return null;
    }

    try {
      final rows = await client
          .from(table)
          .select('nama, users!siswa_user_id_fkey(username)')
          .eq('user_id', normalizedUid)
          .eq('is_deleted', false)
          .limit(1);
      final list = rows as List<dynamic>;
      if (list.isEmpty) {
        return null;
      }

      final row = Map<String, dynamic>.from(list.first as Map);
      final nama = ModelUtils.nullableString(row['nama'])?.trim();
      if (nama != null && nama.isNotEmpty) {
        return nama;
      }

      final usersRaw = row['users'];
      final usersMap = usersRaw is Map
          ? Map<String, dynamic>.from(usersRaw)
          : usersRaw is List && usersRaw.isNotEmpty
          ? Map<String, dynamic>.from(usersRaw.first as Map)
          : null;
      final username = ModelUtils.nullableString(usersMap?['username'])?.trim();
      return username;
    } catch (error) {
      throw Exception(
        'Gagal mengambil nama tampilan siswa $normalizedUid: $error',
      );
    }
  }

  Future<void> _ensureRequiredName(Map<String, dynamic> payload) async {
    final currentName = ModelUtils.nullableString(payload['nama']);
    if (currentName != null) {
      return;
    }

    final uid = ModelUtils.nullableString(payload['user_id']);
    if (uid == null) {
      payload['nama'] = '';
      return;
    }

    final users = await UserService(client: client).getByUserId(uid);
    if (users.isNotEmpty) {
      payload['nama'] = users.first.nama;
      return;
    }

    payload['nama'] = uid;
  }
}
