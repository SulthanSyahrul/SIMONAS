import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/jadwal_model.dart';
import '../../../providers/supabase_providers.dart';

class JadwalGuruLookupItem {
  final String id;
  final String label;

  const JadwalGuruLookupItem({required this.id, required this.label});
}

class JadwalGuruItem {
  final String id;
  final String guruUid;
  final String kelasId;
  final String kelasNama;
  final String mapelId;
  final String mapelNama;
  final String hari;
  final int jamKe;
  final int jamAwal;
  final int jamAkhir;
  final int semester;
  final String tahunAjaranId;
  final String? waktuMulai;
  final String? waktuSelesai;
  final String? ruangan;

  const JadwalGuruItem({
    required this.id,
    required this.guruUid,
    required this.kelasId,
    required this.kelasNama,
    required this.mapelId,
    required this.mapelNama,
    required this.hari,
    required this.jamKe,
    required this.jamAwal,
    required this.jamAkhir,
    required this.semester,
    required this.tahunAjaranId,
    required this.waktuMulai,
    required this.waktuSelesai,
    required this.ruangan,
  });

  List<int> expandJams() {
    if (jamAkhir < jamAwal) {
      return <int>[jamAwal];
    }
    return List<int>.generate(
      jamAkhir - jamAwal + 1,
      (index) => jamAwal + index,
    );
  }

  bool includesJam(int jam) => jam >= jamAwal && jam <= jamAkhir;
}

class JadwalGuruFilterState {
  final List<JadwalGuruItem> data;
  final bool isLoading;
  final String? error;

  const JadwalGuruFilterState({
    required this.data,
    required this.isLoading,
    required this.error,
  });

  factory JadwalGuruFilterState.initial() {
    return const JadwalGuruFilterState(
      data: <JadwalGuruItem>[],
      isLoading: false,
      error: null,
    );
  }

  Map<String, List<JadwalGuruItem>> get groupedByHari {
    final grouped = <String, List<JadwalGuruItem>>{};
    for (final item in data) {
      grouped.putIfAbsent(item.hari, () => <JadwalGuruItem>[]);
      grouped[item.hari]!.add(item);
    }

    const dayOrder = <String, int>{
      'Senin': 1,
      'Selasa': 2,
      'Rabu': 3,
      'Kamis': 4,
      'Jumat': 5,
      'Sabtu': 6,
      'Minggu': 7,
    };

    final entries = grouped.entries.toList()
      ..sort(
        (a, b) => (dayOrder[a.key] ?? 99).compareTo(dayOrder[b.key] ?? 99),
      );

    final sorted = <String, List<JadwalGuruItem>>{};
    for (final entry in entries) {
      entry.value.sort((a, b) {
        if (a.jamAwal != b.jamAwal) {
          return a.jamAwal.compareTo(b.jamAwal);
        }
        return a.jamAkhir.compareTo(b.jamAkhir);
      });
      sorted[entry.key] = entry.value;
    }
    return sorted;
  }

  JadwalGuruFilterState copyWith({
    List<JadwalGuruItem>? data,
    bool? isLoading,
    Object? error = _jadwalGuruSentinel,
  }) {
    return JadwalGuruFilterState(
      data: data ?? this.data,
      isLoading: isLoading ?? this.isLoading,
      error: error == _jadwalGuruSentinel ? this.error : error as String?,
    );
  }
}

typedef JadwalGuruState = JadwalGuruFilterState;

class JadwalGuruFilterNotifier extends StateNotifier<JadwalGuruFilterState> {
  JadwalGuruFilterNotifier(this._ref, this._guruUid)
    : super(JadwalGuruFilterState.initial());

  final Ref _ref;
  final String _guruUid;
  Future<void>? _loadFuture;
  String? _loadKey;
  String? _loadedKey;

  Future<void> getJadwalByGuru({
    required String tahunAjaranId,
    int? semester,
    String? semesterId,
    bool forceRefreshData = false,
    bool forceRefreshCache = false,
  }) async {
    final requestKey = [
      tahunAjaranId.trim(),
      semester?.toString() ?? 'all',
      semesterId?.trim() ?? '',
    ].join('|');
    final forceRefresh = forceRefreshData || forceRefreshCache;
    if (!forceRefresh && _loadedKey == requestKey && state.error == null) {
      return;
    }
    if (!forceRefresh && _loadKey == requestKey && _loadFuture != null) {
      return _loadFuture!;
    }

    final future = _fetchJadwalByGuru(
      tahunAjaranId: tahunAjaranId,
      semester: semester,
      semesterId: semesterId,
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

  Future<void> _fetchJadwalByGuru({
    required String tahunAjaranId,
    required String requestKey,
    int? semester,
    String? semesterId,
    bool forceRefreshData = false,
    bool forceRefreshCache = false,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final jadwalRows = await _ref
          .read(jadwalServiceProvider)
          .getByGuruAndTahunAjaran(
            _guruUid,
            tahunAjaranId,
            forceFullFetch: forceRefreshData || forceRefreshCache,
            semester: semester,
            semesterId: semesterId,
          );
      final items = await _mapItems(jadwalRows);
      if (!mounted) {
        return;
      }
      _loadedKey = requestKey;
      state = state.copyWith(data: items, isLoading: false, error: null);
    } catch (error) {
      if (!mounted) {
        return;
      }
      state = state.copyWith(
        isLoading: false,
        error: 'Gagal memuat jadwal guru: $error',
      );
    }
  }

  Future<void> loadJadwalGuruByTahunAjaran(
    String tahunAjaranId, {
    bool forceRefreshData = false,
    bool forceRefreshCache = false,
    int? semester,
    String? semesterId,
  }) async {
    await getJadwalByGuru(
      tahunAjaranId: tahunAjaranId,
      semester: semester,
      semesterId: semesterId,
      forceRefreshData: forceRefreshData,
      forceRefreshCache: forceRefreshCache,
    );
  }

  Future<void> loadJadwalByTahunAjaran(
    String tahunAjaranId, {
    bool forceRefreshData = false,
    bool forceRefreshCache = false,
    int? semester,
    String? semesterId,
  }) async {
    await loadJadwalGuruByTahunAjaran(
      tahunAjaranId,
      forceRefreshData: forceRefreshData,
      forceRefreshCache: forceRefreshCache,
      semester: semester,
      semesterId: semesterId,
    );
  }

  List<JadwalGuruLookupItem> getAvailableKelas() {
    final unique = <String, String>{};
    for (final item in state.data) {
      unique[item.kelasId] = item.kelasNama;
    }
    final result =
        unique.entries
            .map(
              (entry) =>
                  JadwalGuruLookupItem(id: entry.key, label: entry.value),
            )
            .toList()
          ..sort(
            (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
          );
    return result;
  }

  List<JadwalGuruLookupItem> getMapelByKelas(String kelasId) {
    final unique = <String, String>{};
    for (final item in state.data) {
      if (item.kelasId != kelasId) {
        continue;
      }
      unique[item.mapelId] = item.mapelNama;
    }
    final result =
        unique.entries
            .map(
              (entry) =>
                  JadwalGuruLookupItem(id: entry.key, label: entry.value),
            )
            .toList()
          ..sort(
            (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
          );
    return result;
  }

  bool isPairValid({required String kelasId, required String mapelId}) {
    return state.data.any(
      (item) => item.kelasId == kelasId && item.mapelId == mapelId,
    );
  }

  List<JadwalGuruItem> getByHariJam(String hari, int jamKe) {
    return state.data
        .where((item) => item.hari == hari && item.includesJam(jamKe))
        .toList()
      ..sort((a, b) => a.jamAwal.compareTo(b.jamAwal));
  }

  Future<List<JadwalGuruItem>> _mapItems(List<JadwalRecord> jadwalRows) async {
    final items =
        jadwalRows
            .where((item) => !item.isDeleted)
            .map(
              (item) => JadwalGuruItem(
                id: item.id,
                guruUid: item.guruUid,
                kelasId: item.kelasId,
                kelasNama: item.kelasNama ?? item.kelasId,
                mapelId: item.mapelId,
                mapelNama: item.mapelNama ?? item.mapelId,
                hari: item.hari,
                jamKe: item.jamKe,
                jamAwal: item.jamAwal,
                jamAkhir: item.jamAkhir,
                semester: item.semester,
                tahunAjaranId: item.tahunAjaranId,
                waktuMulai: item.waktuMulai,
                waktuSelesai: item.waktuSelesai,
                ruangan: item.ruangan,
              ),
            )
            .toList()
          ..sort((a, b) {
            if (a.hari != b.hari) {
              return a.hari.compareTo(b.hari);
            }
            if (a.jamAwal != b.jamAwal) {
              return a.jamAwal.compareTo(b.jamAwal);
            }
            return a.jamAkhir.compareTo(b.jamAkhir);
          });

    return items;
  }
}

final jadwalGuruProvider = StateNotifierProvider.autoDispose
    .family<JadwalGuruFilterNotifier, JadwalGuruFilterState, String>((
      ref,
      guruUid,
    ) {
      return JadwalGuruFilterNotifier(ref, guruUid);
    });

final jadwalGuruSupabaseProvider = jadwalGuruProvider;

const Object _jadwalGuruSentinel = Object();
