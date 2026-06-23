import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/kelas_model.dart';
import '../../../models/kelas_siswa_model.dart';
import '../../../models/siswa_model.dart';
import '../../../models/tahun_ajaran_model.dart';
import '../../../providers/supabase_providers.dart';

class BkKelasSiswaItem {
  final String id;
  final String siswaId;
  final String siswaNama;
  final String? siswaNis;
  final String kelasId;
  final String kelasNama;
  final String tahunAjaranId;
  final String tahunAjaranNama;
  final String status;

  const BkKelasSiswaItem({
    required this.id,
    required this.siswaId,
    required this.siswaNama,
    required this.siswaNis,
    required this.kelasId,
    required this.kelasNama,
    required this.tahunAjaranId,
    required this.tahunAjaranNama,
    required this.status,
  });

  bool get aktif => status.toLowerCase() == 'aktif';

  bool matchesSearch(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return true;
    }
    return siswaNama.toLowerCase().contains(normalized) ||
        (siswaNis ?? '').toLowerCase().contains(normalized);
  }
}

class BkSiswaBelumKelasItem {
  final String siswaId;
  final String siswaNama;
  final String? siswaNis;
  final String tahunAjaranId;
  final String tahunAjaranNama;

  const BkSiswaBelumKelasItem({
    required this.siswaId,
    required this.siswaNama,
    required this.siswaNis,
    required this.tahunAjaranId,
    required this.tahunAjaranNama,
  });

  bool matchesSearch(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return true;
    }
    return siswaNama.toLowerCase().contains(normalized) ||
        (siswaNis ?? '').toLowerCase().contains(normalized);
  }
}

class PengaturanKelasBkState {
  final List<TahunAjaranRecord> tahunAjaranOptions;
  final List<KelasRecord> kelasOptions;
  final List<BkKelasSiswaItem> assignedData;
  final List<BkSiswaBelumKelasItem> unassignedData;
  final Map<String, int> kelasStudentCounts;
  final int totalSiswa;
  final int assignedCount;
  final int unassignedCount;
  final int kelasCount;
  final bool isLoading;
  final String? error;

  const PengaturanKelasBkState({
    required this.tahunAjaranOptions,
    required this.kelasOptions,
    required this.assignedData,
    required this.unassignedData,
    required this.kelasStudentCounts,
    required this.totalSiswa,
    required this.assignedCount,
    required this.unassignedCount,
    required this.kelasCount,
    required this.isLoading,
    required this.error,
  });

  List<BkKelasSiswaItem> get data => assignedData;

  factory PengaturanKelasBkState.initial() {
    return const PengaturanKelasBkState(
      tahunAjaranOptions: <TahunAjaranRecord>[],
      kelasOptions: <KelasRecord>[],
      assignedData: <BkKelasSiswaItem>[],
      unassignedData: <BkSiswaBelumKelasItem>[],
      kelasStudentCounts: <String, int>{},
      totalSiswa: 0,
      assignedCount: 0,
      unassignedCount: 0,
      kelasCount: 0,
      isLoading: false,
      error: null,
    );
  }

  PengaturanKelasBkState copyWith({
    List<TahunAjaranRecord>? tahunAjaranOptions,
    List<KelasRecord>? kelasOptions,
    List<BkKelasSiswaItem>? assignedData,
    List<BkSiswaBelumKelasItem>? unassignedData,
    Map<String, int>? kelasStudentCounts,
    int? totalSiswa,
    int? assignedCount,
    int? unassignedCount,
    int? kelasCount,
    bool? isLoading,
    Object? error = _sentinelPengaturan,
  }) {
    return PengaturanKelasBkState(
      tahunAjaranOptions: tahunAjaranOptions ?? this.tahunAjaranOptions,
      kelasOptions: kelasOptions ?? this.kelasOptions,
      assignedData: assignedData ?? this.assignedData,
      unassignedData: unassignedData ?? this.unassignedData,
      kelasStudentCounts: kelasStudentCounts ?? this.kelasStudentCounts,
      totalSiswa: totalSiswa ?? this.totalSiswa,
      assignedCount: assignedCount ?? this.assignedCount,
      unassignedCount: unassignedCount ?? this.unassignedCount,
      kelasCount: kelasCount ?? this.kelasCount,
      isLoading: isLoading ?? this.isLoading,
      error: error == _sentinelPengaturan ? this.error : error as String?,
    );
  }
}

class PengaturanKelasBkNotifier
    extends StateNotifier<PengaturanKelasBkState> {
  PengaturanKelasBkNotifier(this._ref)
    : super(PengaturanKelasBkState.initial());

  final Ref _ref;
  List<KelasSiswaRecord> _allRows = const <KelasSiswaRecord>[];
  String? _allRowsTahunAjaranId;
  List<SiswaRecord> _siswaCache = const <SiswaRecord>[];
  Map<String, SiswaRecord> _siswaByUid = <String, SiswaRecord>{};

  Future<void> loadMasterData() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final results = await Future.wait<dynamic>([
        _ref.read(tahunAjaranServiceProvider).getAllIncremental(),
        _ref.read(kelasServiceProvider).getAllIncremental(),
      ]);
      final tahun = results[0] as List<TahunAjaranRecord>;
      final kelas = results[1] as List<KelasRecord>;
      state = state.copyWith(
        tahunAjaranOptions: [
          ...tahun.where((row) => !row.isDeleted),
        ]..sort((a, b) => b.nama.toLowerCase().compareTo(a.nama.toLowerCase())),
        kelasOptions: [...kelas.where((row) => !row.isDeleted)]
          ..sort(
            (a, b) =>
                a.namaKelas.toLowerCase().compareTo(b.namaKelas.toLowerCase()),
          ),
        kelasCount: kelas.where((row) => !row.isDeleted).length,
        isLoading: false,
        error: null,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: 'Gagal memuat master pengaturan kelas: $error',
      );
    }
  }

  Future<void> getKelasSiswa({
    required String tahunAjaranId,
    required String? kelasId,
    bool forceRefresh = false,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await Future.wait<void>([
        _ensureKelasSiswaCache(
          tahunAjaranId: tahunAjaranId,
          forceRefresh: forceRefresh,
        ),
        _ensureSiswaCache(forceRefresh: forceRefresh),
      ]);
      await _publishForTahunAjaran(
        tahunAjaranId: tahunAjaranId,
        kelasId: kelasId,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: 'Gagal memuat assignment kelas siswa: $error',
      );
    }
  }

  Future<void> loadMoreKelasSiswa({
    required String tahunAjaranId,
    required String? kelasId,
  }) async {
    await applyFilter(tahunAjaranId: tahunAjaranId, kelasId: kelasId);
  }

  Future<void> applyFilter({
    required String tahunAjaranId,
    required String? kelasId,
  }) async {
    if (_allRows.isEmpty) {
      await getKelasSiswa(tahunAjaranId: tahunAjaranId, kelasId: kelasId);
      return;
    }
    await _ensureSiswaCache();
    await _publishForTahunAjaran(
      tahunAjaranId: tahunAjaranId,
      kelasId: kelasId,
    );
  }

  Future<List<SiswaRecord>> getAvailableSiswa({
    required String tahunAjaranId,
  }) async {
    await _ensureSiswaCache();
    await _ensureKelasSiswaCache(tahunAjaranId: tahunAjaranId);
    final assigned = _allRows
        .where(
          (row) =>
              row.tahunAjaranId == tahunAjaranId &&
              !row.isDeleted &&
              row.statusAktif,
        )
        .map((row) => row.siswaId)
        .toSet();
    final available =
        _siswaCache
            .where((row) => !row.isDeleted && !assigned.contains(row.uid))
            .toList(growable: false)
          ..sort((a, b) {
            final aName = (a.nama ?? a.uid).toLowerCase();
            final bName = (b.nama ?? b.uid).toLowerCase();
            return aName.compareTo(bName);
          });
    return available;
  }

  Future<void> assignSiswaToKelas({
    required String siswaId,
    required String kelasId,
    required String tahunAjaranId,
    required String? refreshKelasId,
  }) async {
    await assignSiswaListToKelas(
      siswaIds: <String>[siswaId],
      kelasId: kelasId,
      tahunAjaranId: tahunAjaranId,
      refreshKelasId: refreshKelasId,
    );
  }

  Future<void> assignSiswaListToKelas({
    required List<String> siswaIds,
    required String kelasId,
    required String tahunAjaranId,
    required String? refreshKelasId,
  }) async {
    final uniqueSiswaIds = siswaIds.toSet().toList(growable: false);
    if (uniqueSiswaIds.isEmpty) {
      return;
    }

    await _ensureKelasSiswaCache(tahunAjaranId: tahunAjaranId);
    await _ensureSiswaCache();

    final assignedBySiswa = <String, KelasSiswaRecord>{
      for (final row in _activeRowsForYear(tahunAjaranId)) row.siswaId: row,
    };
    final alreadyAssigned = uniqueSiswaIds
        .where((siswaId) => assignedBySiswa.containsKey(siswaId))
        .toList(growable: false);
    if (alreadyAssigned.isNotEmpty) {
      final first = _siswaByUid[alreadyAssigned.first];
      final name = first?.nama?.trim().isNotEmpty == true
          ? first!.nama!.trim()
          : alreadyAssigned.first;
      throw Exception('$name sudah memiliki kelas pada tahun ajaran ini.');
    }

    final service = _ref.read(kelasSiswaServiceProvider);
    for (final siswaId in uniqueSiswaIds) {
      await service.create(<String, dynamic>{
        'kelas_id': kelasId,
        'siswa_uid': siswaId,
        'tahun_ajaran_id': tahunAjaranId,
        'status_aktif': true,
        'is_deleted': false,
      });
    }

    await getKelasSiswa(
      tahunAjaranId: tahunAjaranId,
      kelasId: refreshKelasId,
      forceRefresh: true,
    );
  }

  Future<void> moveSiswaToKelas({
    required String kelasSiswaId,
    required String siswaId,
    required String tahunAjaranId,
    required String kelasId,
    required String? refreshKelasId,
  }) async {
    await _ensureKelasSiswaCache(tahunAjaranId: tahunAjaranId);

    final duplicate = _activeRowsForYear(tahunAjaranId).where(
      (row) =>
          row.id != kelasSiswaId &&
          row.siswaId == siswaId &&
          row.kelasId == kelasId,
    );
    if (duplicate.isNotEmpty) {
      throw Exception('Siswa sudah memiliki assignment aktif di kelas tujuan.');
    }

    await _ref.read(kelasSiswaServiceProvider).update(
      kelasSiswaId,
      <String, dynamic>{'kelas_id': kelasId, 'status_aktif': true},
    );
    await getKelasSiswa(
      tahunAjaranId: tahunAjaranId,
      kelasId: refreshKelasId,
      forceRefresh: true,
    );
  }

  Future<void> updateKelasSiswa({
    required String kelasSiswaId,
    required String tahunAjaranId,
    required String kelasId,
    required String status,
    required String? refreshKelasId,
  }) async {
    await _ref.read(kelasSiswaServiceProvider).update(
      kelasSiswaId,
      <String, dynamic>{
        'kelas_id': kelasId,
        'status_aktif': status.trim().toLowerCase() == 'aktif',
      },
    );
    await getKelasSiswa(
      tahunAjaranId: tahunAjaranId,
      kelasId: refreshKelasId,
      forceRefresh: true,
    );
  }

  Future<void> softDeleteKelasSiswa({
    required String kelasSiswaId,
    required String tahunAjaranId,
    required String? refreshKelasId,
  }) async {
    await _ref.read(kelasSiswaServiceProvider).delete(kelasSiswaId);
    await getKelasSiswa(
      tahunAjaranId: tahunAjaranId,
      kelasId: refreshKelasId,
      forceRefresh: true,
    );
  }

  Future<List<BkKelasSiswaItem>> _mapRows(
    Iterable<KelasSiswaRecord> rows, {
    required String? kelasId,
    required Map<String, SiswaRecord> siswaById,
  }) async {
    final kelasRows = state.kelasOptions.isEmpty
        ? await _ref.read(kelasServiceProvider).getAllIncremental()
        : state.kelasOptions;
    final tahunRows = state.tahunAjaranOptions.isEmpty
        ? await _ref.read(tahunAjaranServiceProvider).getAllIncremental()
        : state.tahunAjaranOptions;
    final kelasById = {for (final item in kelasRows) item.id: item.namaKelas};
    final tahunById = {for (final item in tahunRows) item.id: item.nama};

    final filtered = rows.where(
      (row) => kelasId == null || row.kelasId == kelasId,
    );
    final items =
        filtered
            .map(
              (row) => BkKelasSiswaItem(
                id: row.id,
                siswaId: row.siswaId,
                siswaNama:
                    siswaById[row.siswaId]?.nama?.trim().isNotEmpty == true
                    ? siswaById[row.siswaId]!.nama!.trim()
                    : row.siswaId,
                siswaNis: siswaById[row.siswaId]?.nis,
                kelasId: row.kelasId,
                kelasNama: kelasById[row.kelasId] ?? row.kelasId,
                tahunAjaranId: row.tahunAjaranId,
                tahunAjaranNama:
                    tahunById[row.tahunAjaranId] ?? row.tahunAjaranId,
                status: row.status,
              ),
            )
            .toList(growable: false)
          ..sort(
            (a, b) =>
                a.siswaNama.toLowerCase().compareTo(b.siswaNama.toLowerCase()),
          );
    return items;
  }

  Future<void> _publishForTahunAjaran({
    required String tahunAjaranId,
    required String? kelasId,
  }) async {
    final activeRows = _activeRowsForYear(
      tahunAjaranId,
    ).toList(growable: false);
    final assignedSiswaIds = activeRows.map((row) => row.siswaId).toSet();
    final tahunNama = _tahunAjaranName(tahunAjaranId);

    final kelasCounts = <String, int>{};
    for (final row in activeRows) {
      kelasCounts[row.kelasId] = (kelasCounts[row.kelasId] ?? 0) + 1;
    }

    final assignedItems = await _mapRows(
      activeRows,
      kelasId: kelasId,
      siswaById: _siswaByUid,
    );

    final unassignedItems =
        _siswaCache
            .where(
              (row) => !row.isDeleted && !assignedSiswaIds.contains(row.uid),
            )
            .map(
              (row) => BkSiswaBelumKelasItem(
                siswaId: row.uid,
                siswaNama: row.nama?.trim().isNotEmpty == true
                    ? row.nama!.trim()
                    : row.uid,
                siswaNis: row.nis,
                tahunAjaranId: tahunAjaranId,
                tahunAjaranNama: tahunNama,
              ),
            )
            .toList(growable: false)
          ..sort(
            (a, b) =>
                a.siswaNama.toLowerCase().compareTo(b.siswaNama.toLowerCase()),
          );

    final totalSiswa = _siswaCache.where((row) => !row.isDeleted).length;

    state = state.copyWith(
      assignedData: assignedItems,
      unassignedData: unassignedItems,
      kelasStudentCounts: kelasCounts,
      totalSiswa: totalSiswa,
      assignedCount: assignedSiswaIds.length,
      unassignedCount: unassignedItems.length,
      kelasCount: state.kelasOptions.where((row) => !row.isDeleted).length,
      isLoading: false,
      error: null,
    );
  }

  Iterable<KelasSiswaRecord> _activeRowsForYear(String tahunAjaranId) {
    return _allRows.where(
      (row) =>
          !row.isDeleted &&
          row.statusAktif &&
          row.tahunAjaranId == tahunAjaranId,
    );
  }

  String _tahunAjaranName(String id) {
    for (final item in state.tahunAjaranOptions) {
      if (item.id == id) {
        return item.nama;
      }
    }
    return id;
  }

  Future<void> _ensureKelasSiswaCache({
    required String tahunAjaranId,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        _allRows.isNotEmpty &&
        _allRowsTahunAjaranId == tahunAjaranId) {
      return;
    }
    _allRows = await _ref
        .read(kelasSiswaServiceProvider)
        .getByTahunAjaranIncremental(
          tahunAjaranId,
          forceFullFetch: forceRefresh,
        );
    _allRowsTahunAjaranId = tahunAjaranId;
  }

  Future<void> _ensureSiswaCache({bool forceRefresh = false}) async {
    if (!forceRefresh && _siswaCache.isNotEmpty) {
      return;
    }
    _siswaCache = await _ref.read(siswaServiceProvider).getAllIncremental();
    _siswaByUid = {for (final item in _siswaCache) item.uid: item};
  }
}

final pengaturanKelasBkProvider =
    StateNotifierProvider.autoDispose<
      PengaturanKelasBkNotifier,
      PengaturanKelasBkState
    >((ref) {
      return PengaturanKelasBkNotifier(ref);
    });

const Object _sentinelPengaturan = Object();
