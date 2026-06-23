import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/nilai_ujian_model.dart';
import '../../../providers/supabase_providers.dart';
import '../../../services/nilai_ujian_service.dart';

class NilaiGuruItem {
  final String id;
  final String siswaId;
  final String kelasId;
  final String mapelId;
  final String guruId;
  final String tahunAjaranId;
  final double? nilaiUts;
  final double? nilaiUas;
  final double? nilaiAkhir;

  const NilaiGuruItem({
    required this.id,
    required this.siswaId,
    required this.kelasId,
    required this.mapelId,
    required this.guruId,
    required this.tahunAjaranId,
    required this.nilaiUts,
    required this.nilaiUas,
    required this.nilaiAkhir,
  });
}

class NilaiGuruState {
  final List<NilaiGuruItem> data;
  final bool isLoading;
  final String? error;

  const NilaiGuruState({
    required this.data,
    required this.isLoading,
    required this.error,
  });

  factory NilaiGuruState.initial() {
    return const NilaiGuruState(
      data: <NilaiGuruItem>[],
      isLoading: false,
      error: null,
    );
  }

  NilaiGuruState copyWith({
    List<NilaiGuruItem>? data,
    bool? isLoading,
    Object? error = _nilaiGuruSentinel,
  }) {
    return NilaiGuruState(
      data: data ?? this.data,
      isLoading: isLoading ?? this.isLoading,
      error: error == _nilaiGuruSentinel ? this.error : error as String?,
    );
  }
}

class NilaiGuruNotifier extends StateNotifier<NilaiGuruState> {
  NilaiGuruNotifier(this._ref, this._guruUid) : super(NilaiGuruState.initial());

  final Ref _ref;
  final String _guruUid;
  Future<void>? _loadFuture;
  String? _loadKey;
  String? _loadedKey;

  Future<void> getNilaiByKelasMapel({
    required String kelasId,
    required String mapelId,
    required String tahunAjaranId,
    bool forceRefreshData = false,
    bool forceRefreshCache = false,
  }) async {
    final requestKey = [
      kelasId.trim(),
      mapelId.trim(),
      tahunAjaranId.trim(),
    ].join('|');
    final forceRefresh = forceRefreshData || forceRefreshCache;
    if (!forceRefresh && _loadedKey == requestKey && state.error == null) {
      return;
    }
    if (!forceRefresh && _loadKey == requestKey && _loadFuture != null) {
      return _loadFuture!;
    }

    final future = _fetchNilaiByKelasMapel(
      kelasId: kelasId,
      mapelId: mapelId,
      tahunAjaranId: tahunAjaranId,
      requestKey: requestKey,
    );
    _loadKey = requestKey;
    _loadFuture = future;
    try {
      await future;
    } finally {
      if (identical(_loadFuture, future)) {
        _loadFuture = null;
        _loadKey = null;
      }
    }
  }

  Future<void> _fetchNilaiByKelasMapel({
    required String kelasId,
    required String mapelId,
    required String tahunAjaranId,
    required String requestKey,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final rows = await _ref
          .read(nilaiServiceProvider)
          .getByGuruFilters(
            guruUid: _guruUid,
            kelasId: kelasId,
            mapelId: mapelId,
            tahunAjaranId: tahunAjaranId,
          );
      final filtered =
          rows.map(_toItem).toList()
            ..sort((a, b) => a.siswaId.compareTo(b.siswaId));

      if (!mounted) {
        return;
      }
      _loadedKey = requestKey;
      state = state.copyWith(data: filtered, isLoading: false, error: null);
    } catch (error) {
      if (!mounted) {
        return;
      }
      state = state.copyWith(
        isLoading: false,
        error: 'Gagal memuat nilai: $error',
      );
    }
  }

  Future<void> upsertNilai({
    required String siswaId,
    required String kelasId,
    required String mapelId,
    required String tahunAjaranId,
    double? nilaiUts,
    double? nilaiUas,
  }) async {
    final service = _ref.read(nilaiServiceProvider);
    NilaiGuruItem? existing;
    for (final item in state.data) {
      if (item.siswaId == siswaId &&
          item.kelasId == kelasId &&
          item.mapelId == mapelId &&
          item.tahunAjaranId == tahunAjaranId) {
        existing = item;
        break;
      }
    }

    final payload = <String, dynamic>{
      'siswa_uid': siswaId,
      'guru_uid': _guruUid,
      'kelas_id': kelasId,
      'mapel_id': mapelId,
      'tahun_ajaran_id': tahunAjaranId,
      'nilai_uts': nilaiUts,
      'nilai_uas': nilaiUas,
    };

    if (existing == null) {
      await service.create(payload);
    } else {
      await service.update(existing.id, payload);
    }
    _loadedKey = null;
  }

  Future<void> upsertNilaiMany({
    required String kelasId,
    required String mapelId,
    required String tahunAjaranId,
    required Iterable<NilaiUjianBatchInput> items,
  }) async {
    await _ref.read(nilaiServiceProvider).upsertManyByGuruContext(
      guruUid: _guruUid,
      kelasId: kelasId,
      mapelId: mapelId,
      tahunAjaranId: tahunAjaranId,
      items: items,
    );
    _loadedKey = null;
  }

  Future<void> clearNilaiByKelasMapel({
    required String kelasId,
    required String mapelId,
    required String tahunAjaranId,
  }) async {
    final service = _ref.read(nilaiServiceProvider);
    final rows = await service.getByGuruFilters(
      guruUid: _guruUid,
      kelasId: kelasId,
      mapelId: mapelId,
      tahunAjaranId: tahunAjaranId,
    );
    for (final item in rows) {
      if (!item.isDeleted) {
        await service.delete(item.id);
      }
    }
    _loadedKey = null;

    await getNilaiByKelasMapel(
      kelasId: kelasId,
      mapelId: mapelId,
      tahunAjaranId: tahunAjaranId,
      forceRefreshData: true,
      forceRefreshCache: true,
    );
  }

  NilaiGuruItem _toItem(NilaiRecord row) {
    return NilaiGuruItem(
      id: row.id,
      siswaId: row.siswaId,
      kelasId: row.kelasId,
      mapelId: row.mataPelajaranId,
      guruId: row.guruId,
      tahunAjaranId: row.tahunAjaranId,
      nilaiUts: row.nilaiUts,
      nilaiUas: row.nilaiUas,
      nilaiAkhir: row.nilaiAkhir,
    );
  }
}

final nilaiGuruSupabaseProvider = StateNotifierProvider.autoDispose
    .family<NilaiGuruNotifier, NilaiGuruState, String>((ref, guruUid) {
      return NilaiGuruNotifier(ref, guruUid);
    });

const Object _nilaiGuruSentinel = Object();
