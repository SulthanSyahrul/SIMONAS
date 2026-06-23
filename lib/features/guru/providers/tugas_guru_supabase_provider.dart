import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/nilai_tugas_model.dart';
import '../../../models/tugas_model.dart';
import '../../../providers/supabase_providers.dart';
import '../../../services/nilai_tugas_service.dart';
import '../../shared/providers/shared_academic_context_provider.dart';

class TugasGuruItem {
  final String id;
  final String kelasId;
  final String kelasNama;
  final String mapelId;
  final String mapelNama;
  final String tahunAjaranId;
  final int semester;
  final String judulTugas;
  final String deskripsi;
  final DateTime? deadline;
  final DateTime? tanggalDibuat;
  final int totalSiswa;
  final int totalDinilai;
  final int belumDinilaiCount;

  const TugasGuruItem({
    required this.id,
    required this.kelasId,
    required this.kelasNama,
    required this.mapelId,
    required this.mapelNama,
    required this.tahunAjaranId,
    required this.semester,
    required this.judulTugas,
    required this.deskripsi,
    required this.deadline,
    required this.tanggalDibuat,
    required this.totalSiswa,
    required this.totalDinilai,
    required this.belumDinilaiCount,
  });
}

class TugasGuruState {
  final List<TugasGuruItem> data;
  final bool isLoading;
  final String? error;

  const TugasGuruState({
    required this.data,
    required this.isLoading,
    required this.error,
  });

  factory TugasGuruState.initial() {
    return const TugasGuruState(
      data: <TugasGuruItem>[],
      isLoading: false,
      error: null,
    );
  }

  TugasGuruState copyWith({
    List<TugasGuruItem>? data,
    bool? isLoading,
    Object? error = _tugasGuruSentinel,
  }) {
    return TugasGuruState(
      data: data ?? this.data,
      isLoading: isLoading ?? this.isLoading,
      error: error == _tugasGuruSentinel ? this.error : error as String?,
    );
  }
}

class TugasGuruNotifier extends StateNotifier<TugasGuruState> {
  TugasGuruNotifier(this._ref, this._guruUid) : super(TugasGuruState.initial());

  final Ref _ref;
  final String _guruUid;
  Future<void>? _loadFuture;
  String? _loadKey;
  String? _loadedKey;

  Future<void> getTugasByGuru({
    required String tahunAjaranId,
    required int semester,
    bool forceRefreshData = false,
    bool forceRefreshCache = false,
  }) async {
    final requestKey = '${tahunAjaranId.trim()}|$semester';
    final forceRefresh = forceRefreshData || forceRefreshCache;
    if (!forceRefresh && _loadedKey == requestKey && state.error == null) {
      return;
    }
    if (!forceRefresh && _loadKey == requestKey && _loadFuture != null) {
      return _loadFuture!;
    }

    final future = _fetchTugasByGuru(
      tahunAjaranId: tahunAjaranId,
      semester: semester,
      requestKey: requestKey,
      forceRefreshData: forceRefreshData,
      forceRefreshCache: forceRefreshCache,
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

  Future<void> _fetchTugasByGuru({
    required String tahunAjaranId,
    required int semester,
    required String requestKey,
    bool forceRefreshData = false,
    bool forceRefreshCache = false,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final rows = await _ref
          .read(tugasServiceProvider)
          .getByGuruAndContext(
            guruUid: _guruUid,
            tahunAjaranId: tahunAjaranId,
            semester: semester,
          );
      final mapped = await _mapItems(
        rows,
        forceRefresh: forceRefreshData || forceRefreshCache,
      );
      if (!mounted) {
        return;
      }
      _loadedKey = requestKey;
      state = state.copyWith(data: mapped, isLoading: false, error: null);
    } catch (error) {
      if (!mounted) {
        return;
      }
      state = state.copyWith(
        isLoading: false,
        error: 'Gagal memuat tugas: $error',
      );
    }
  }

  Future<void> createTugas({
    required String kelasId,
    required String mapelId,
    required String tahunAjaranId,
    required int semester,
    required String judul,
    required String deskripsi,
    DateTime? deadline,
  }) async {
    await _ref.read(tugasServiceProvider).create({
      'guru_uid': _guruUid,
      'kelas_id': kelasId,
      'mapel_id': mapelId,
      'tahun_ajaran_id': tahunAjaranId,
      'semester': semester,
      'judul_tugas': judul,
      'deskripsi': deskripsi,
      'tanggal_dibuat': DateTime.now(),
      'tanggal_deadline': deadline,
    });
    _loadedKey = null;
  }

  Future<void> updateTugas({
    required String tugasId,
    required String tahunAjaranId,
    required int semester,
    required String judul,
    required String deskripsi,
    DateTime? deadline,
  }) async {
    await _ref.read(tugasServiceProvider).update(tugasId, {
      'tahun_ajaran_id': tahunAjaranId,
      'semester': semester,
      'judul_tugas': judul,
      'deskripsi': deskripsi,
      'tanggal_deadline': deadline,
    });
    _loadedKey = null;
  }

  Future<void> softDeleteTugas({
    required String tugasId,
    required String tahunAjaranId,
    required int semester,
  }) async {
    await _ref.read(tugasServiceProvider).delete(tugasId);
    await getTugasByGuru(
      tahunAjaranId: tahunAjaranId,
      semester: semester,
      forceRefreshData: true,
      forceRefreshCache: true,
    );
  }

  Future<List<NilaiTugasRecord>> getNilaiTugasByTugas(String tugasId) async {
    return _ref.read(nilaiTugasServiceProvider).getByTugas(tugasId);
  }

  Future<void> upsertNilaiTugas({
    required String tugasId,
    required String siswaId,
    double? nilai,
  }) async {
    await _ref
        .read(nilaiTugasServiceProvider)
        .upsertByTugasAndSiswa(
          tugasId: tugasId,
          siswaUid: siswaId,
          nilai: nilai,
        );
  }

  Future<void> upsertNilaiTugasBatch({
    required String tugasId,
    required List<({String siswaId, double? nilai})> items,
  }) async {
    await _ref.read(nilaiTugasServiceProvider).upsertManyByTugasAndSiswa(
      tugasId: tugasId,
      items: items
          .map(
            (item) => NilaiTugasBatchInput(
              siswaUid: item.siswaId,
              nilai: item.nilai,
            ),
          )
          .toList(growable: false),
    );
  }

  Future<List<TugasGuruItem>> _mapItems(
    List<TugasRecord> rows, {
    bool forceRefresh = false,
  }) async {
    final cache = _ref.read(appMasterCacheProvider);
    final kelasFuture = cache.getKelas(_ref.read, forceRefresh: forceRefresh);
    final mapelFuture = cache.getMapel(_ref.read, forceRefresh: forceRefresh);
    final kelasRows = await kelasFuture;
    final mapelRows = await mapelFuture;
    final kelasById = {for (final item in kelasRows) item.id: item.namaKelas};
    final mapelById = {for (final item in mapelRows) item.id: item.namaMapel};

    final data = <TugasGuruItem>[];
    for (final item in rows) {
      final status = await _loadPenilaianStatus(
        item,
        forceRefresh: forceRefresh,
      );
      data.add(
        TugasGuruItem(
          id: item.id,
          kelasId: item.kelasId,
          kelasNama: kelasById[item.kelasId] ?? item.kelasId,
          mapelId: item.mapelId,
          mapelNama: mapelById[item.mapelId] ?? item.mapelId,
          tahunAjaranId: item.tahunAjaranId,
          semester: item.semester,
          judulTugas: item.judulTugas,
          deskripsi: item.deskripsi,
          deadline: item.deadline,
          tanggalDibuat: item.tanggalDibuat,
          totalSiswa: status.totalSiswa,
          totalDinilai: status.totalDinilai,
          belumDinilaiCount: status.belumDinilaiCount,
        ),
      );
    }

    data.sort((a, b) {
      final left =
          a.deadline ??
          a.tanggalDibuat ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final right =
          b.deadline ??
          b.tanggalDibuat ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return right.compareTo(left);
    });
    return data;
  }

  Future<_TugasPenilaianStatus> _loadPenilaianStatus(
    TugasRecord item, {
    required bool forceRefresh,
  }) async {
    final siswaRows = await _ref
        .read(appMasterCacheProvider)
        .getActiveKelasSiswaRoster(
          _ref.read,
          item.kelasId,
          forceRefresh: forceRefresh,
        );
    final siswaUids = siswaRows.map((siswa) => siswa.uid).toSet();
    if (siswaUids.isEmpty) {
      return const _TugasPenilaianStatus(
        totalSiswa: 0,
        totalDinilai: 0,
        belumDinilaiCount: 0,
      );
    }

    final nilaiRows = await _ref
        .read(nilaiTugasServiceProvider)
        .getByTugas(item.id);
    final dinilai = nilaiRows
        .where((row) => siswaUids.contains(row.siswaUid) && row.nilai != null)
        .map((row) => row.siswaUid)
        .toSet()
        .length;

    return _TugasPenilaianStatus(
      totalSiswa: siswaUids.length,
      totalDinilai: dinilai,
      belumDinilaiCount: siswaUids.length - dinilai,
    );
  }
}

class _TugasPenilaianStatus {
  final int totalSiswa;
  final int totalDinilai;
  final int belumDinilaiCount;

  const _TugasPenilaianStatus({
    required this.totalSiswa,
    required this.totalDinilai,
    required this.belumDinilaiCount,
  });
}

final tugasGuruSupabaseProvider = StateNotifierProvider.autoDispose
    .family<TugasGuruNotifier, TugasGuruState, String>((ref, guruUid) {
      return TugasGuruNotifier(ref, guruUid);
    });

const Object _tugasGuruSentinel = Object();
