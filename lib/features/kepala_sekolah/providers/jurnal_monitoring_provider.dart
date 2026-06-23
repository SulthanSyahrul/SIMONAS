import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/jurnal_model.dart';
import '../../../providers/supabase_providers.dart';
import '../../../services/jurnal_service.dart';
import '../../shared/providers/shared_academic_context_provider.dart';

class JurnalFilterOption {
  final String id;
  final String label;

  const JurnalFilterOption({required this.id, required this.label});
}

class KepsekAbsensiEditDraft {
  final String siswaId;
  final String statusKehadiran;
  final String? catatan;

  const KepsekAbsensiEditDraft({
    required this.siswaId,
    required this.statusKehadiran,
    this.catatan,
  });
}

class JurnalMonitoringItem {
  final String id;
  final String guruUid;
  final String guruName;
  final String kelasId;
  final String kelasName;
  final String mataPelajaranId;
  final String mataPelajaran;
  final String tahunAjaranId;
  final String tahunAjaranName;
  final int semester;
  final DateTime? tanggal;
  final int jamAwal;
  final int jamAkhir;
  final String materi;
  final String status;
  final String? catatan;
  final DateTime? updatedAt;

  const JurnalMonitoringItem({
    required this.id,
    required this.guruUid,
    required this.guruName,
    required this.kelasId,
    required this.kelasName,
    required this.mataPelajaranId,
    required this.mataPelajaran,
    required this.tahunAjaranId,
    required this.tahunAjaranName,
    required this.semester,
    required this.tanggal,
    required this.jamAwal,
    required this.jamAkhir,
    required this.materi,
    required this.status,
    this.catatan,
    this.updatedAt,
  });

  int get jamKe => jamAwal;

  String get statusKehadiran => status;

  String get jamLabel => 'Jam ke $jamAwal - $jamAkhir';

  Map<String, dynamic> toDisplayMap() {
    final tanggalValue = tanggal ?? DateTime.now();
    return {
      'jurnal_id': id,
      'guru_uid': guruUid,
      'user_id': guruUid,
      'nama_guru': guruName,
      'mata_pelajaran': mataPelajaran,
      'kelas': kelasName,
      'tahun_ajaran': tahunAjaranName,
      'semester': 'Semester $semester',
      'tanggal':
          '${tanggalValue.year.toString().padLeft(4, '0')}-${tanggalValue.month.toString().padLeft(2, '0')}-${tanggalValue.day.toString().padLeft(2, '0')}',
      'jam_awal': jamAwal,
      'jam_akhir': jamAkhir,
      'jam_ke': jamAwal,
      'materi': materi,
      'status': status,
      'status_kehadiran': status,
      'catatan': catatan ?? '',
    };
  }
}

class JurnalMonitoringState {
  final List<JurnalMonitoringItem> data;
  final List<JurnalFilterOption> guruOptions;
  final List<JurnalFilterOption> kelasOptions;
  final List<JurnalFilterOption> mapelOptions;
  final List<String> tahunAjaranOptions;
  final String? activeTahunAjaranName;
  final DateTime selectedDate;
  final bool showAllDates;
  final String selectedGuruId;
  final String selectedKelasId;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMoreData;
  final String? error;

  const JurnalMonitoringState({
    required this.data,
    required this.guruOptions,
    required this.kelasOptions,
    required this.mapelOptions,
    required this.tahunAjaranOptions,
    required this.activeTahunAjaranName,
    required this.selectedDate,
    required this.showAllDates,
    required this.selectedGuruId,
    required this.selectedKelasId,
    required this.isLoading,
    required this.isLoadingMore,
    required this.hasMoreData,
    this.error,
  });

  factory JurnalMonitoringState.initial({required bool showAllDates}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return JurnalMonitoringState(
      data: const [],
      guruOptions: const [JurnalFilterOption(id: 'all', label: 'Semua Guru')],
      kelasOptions: const [JurnalFilterOption(id: 'all', label: 'Semua Kelas')],
      mapelOptions: const [],
      tahunAjaranOptions: const [],
      activeTahunAjaranName: null,
      selectedDate: today,
      showAllDates: showAllDates,
      selectedGuruId: 'all',
      selectedKelasId: 'all',
      isLoading: false,
      isLoadingMore: false,
      hasMoreData: false,
    );
  }

  JurnalMonitoringState copyWith({
    List<JurnalMonitoringItem>? data,
    List<JurnalFilterOption>? guruOptions,
    List<JurnalFilterOption>? kelasOptions,
    List<JurnalFilterOption>? mapelOptions,
    List<String>? tahunAjaranOptions,
    String? activeTahunAjaranName,
    DateTime? selectedDate,
    bool? showAllDates,
    String? selectedGuruId,
    String? selectedKelasId,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMoreData,
    String? error,
  }) {
    return JurnalMonitoringState(
      data: data ?? this.data,
      guruOptions: guruOptions ?? this.guruOptions,
      kelasOptions: kelasOptions ?? this.kelasOptions,
      mapelOptions: mapelOptions ?? this.mapelOptions,
      tahunAjaranOptions: tahunAjaranOptions ?? this.tahunAjaranOptions,
      activeTahunAjaranName:
          activeTahunAjaranName ?? this.activeTahunAjaranName,
      selectedDate: selectedDate ?? this.selectedDate,
      showAllDates: showAllDates ?? this.showAllDates,
      selectedGuruId: selectedGuruId ?? this.selectedGuruId,
      selectedKelasId: selectedKelasId ?? this.selectedKelasId,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMoreData: hasMoreData ?? this.hasMoreData,
      error: error,
    );
  }
}

class JurnalMonitoringNotifier extends StateNotifier<JurnalMonitoringState> {
  static const int _pageSize = 40;

  final Ref _ref;
  final bool _todayOnly;
  List<JurnalRecord> _allJurnalRecords = const [];
  int? _nextOffset;
  bool _hasMoreRemoteData = false;
  bool _staticOptionsLoaded = false;
  Map<String, String> _guruByUid = const {};
  Map<String, String> _kelasById = const {};
  Map<String, String> _mapelById = const {};
  Map<String, String> _tahunById = const {};

  JurnalMonitoringNotifier(this._ref, {required bool todayOnly})
    : _todayOnly = todayOnly,
      super(JurnalMonitoringState.initial(showAllDates: !todayOnly));

  Future<void> loadData({bool forceRefreshData = false}) async {
    state = state.copyWith(
      isLoading: true,
      isLoadingMore: false,
      error: null,
    );

    try {
      await _ensureStaticOptionsLoaded(forceRefreshData: forceRefreshData);
      _nextOffset = 0;
      _hasMoreRemoteData = false;

      final firstPage = await _fetchHistoryPage(limit: _pageSize);
      final jurnalRecords = firstPage.data;
      _nextOffset = firstPage.nextOffset;
      _hasMoreRemoteData = firstPage.hasMore;

      final selectedGuruId =
          state.guruOptions.any((item) => item.id == state.selectedGuruId)
          ? state.selectedGuruId
          : 'all';
      final selectedKelasId =
          state.kelasOptions.any((item) => item.id == state.selectedKelasId)
          ? state.selectedKelasId
          : 'all';

      _allJurnalRecords = jurnalRecords;
      final tahunAjaranOptions = <String>{
        ...state.tahunAjaranOptions,
        ...jurnalRecords.map(
          (jurnal) => _tahunById[jurnal.tahunAjaranId] ?? jurnal.tahunAjaranId,
        ),
      }.where((item) => item.trim().isNotEmpty).toList()..sort();

      state = state.copyWith(
        tahunAjaranOptions: tahunAjaranOptions,
        selectedGuruId: selectedGuruId,
        selectedKelasId: selectedKelasId,
        selectedDate: _todayOnly ? _dateOnly(DateTime.now()) : _dateOnly(state.selectedDate),
        isLoading: false,
        isLoadingMore: false,
        hasMoreData: _hasMoreRemoteData,
      );
      _applyFilters();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Gagal memuat jurnal monitoring: $e',
      );
    }
  }

  Future<void> setDate(DateTime date) async {
    if (_todayOnly) {
      return;
    }
    state = state.copyWith(selectedDate: _dateOnly(date), showAllDates: false);
    await loadData();
  }

  Future<void> setShowAllDates(bool showAllDates) async {
    if (_todayOnly) {
      return;
    }
    state = state.copyWith(showAllDates: showAllDates);
    await loadData();
  }

  Future<void> setGuruId(String guruId) async {
    state = state.copyWith(selectedGuruId: guruId);
    await loadData();
  }

  Future<void> setKelasId(String kelasId) async {
    state = state.copyWith(selectedKelasId: kelasId);
    await loadData();
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !_hasMoreRemoteData) {
      return;
    }

    if (_nextOffset == null) {
      _hasMoreRemoteData = false;
      state = state.copyWith(hasMoreData: false);
      return;
    }

    state = state.copyWith(isLoadingMore: true, error: null);
    try {
      final page = await _fetchHistoryPage(
        limit: _pageSize,
        offset: _nextOffset,
      );

      _nextOffset = page.nextOffset;
      _hasMoreRemoteData = page.hasMore;

      if (page.data.isNotEmpty) {
        final mergedById = <String, JurnalRecord>{
          for (final row in _allJurnalRecords) row.id: row,
          for (final row in page.data) row.id: row,
        };
        _allJurnalRecords = mergedById.values.toList(growable: false)
          ..sort((a, b) {
            final aTime =
                a.updatedAt ?? a.tanggal ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bTime =
                b.updatedAt ?? b.tanggal ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bTime.compareTo(aTime);
          });
      }

      _applyFilters(
        isLoading: false,
        isLoadingMore: false,
        hasMoreData: _hasMoreRemoteData,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingMore: false,
        hasMoreData: _hasMoreRemoteData,
        error: 'Gagal memuat data tambahan jurnal: $e',
      );
    }
  }

  Future<void> refresh() async {
    await loadData(forceRefreshData: true);
  }

  Future<void> updateJurnalByKepsek({
    required String jurnalId,
    required String kelasId,
    required String mataPelajaranId,
    required DateTime tanggal,
    required int jamAwal,
    required int jamAkhir,
    required String materi,
    String? catatan,
    required String statusKehadiran,
  }) async {
    final normalizedMateri = materi.trim();
    if (normalizedMateri.isEmpty) {
      throw Exception('Materi tidak boleh kosong.');
    }
    if (jamAwal < 1 || jamAkhir > 8 || jamAkhir < jamAwal) {
      throw Exception('Rentang jam harus berada di rentang 1 sampai 8.');
    }

    final normalizedDate = _dateOnly(tanggal);
    final payload = <String, dynamic>{
      'kelas_id': kelasId,
      'mata_pelajaran_id': mataPelajaranId,
      'tanggal': normalizedDate,
      'jam_awal': jamAwal,
      'jam_akhir': jamAkhir,
      'jam_ke': jamAwal,
      'materi': normalizedMateri,
      'catatan': (catatan == null || catatan.trim().isEmpty)
          ? null
          : catatan.trim(),
      'status': _normalizeStatusKehadiran(statusKehadiran),
      'status_kehadiran': _normalizeStatusKehadiran(statusKehadiran),
    };

    await _ref.read(jurnalServiceProvider).update(jurnalId, payload);
    await _patchJurnalInMemory(
      jurnalId: jurnalId,
      kelasId: kelasId,
      mataPelajaranId: mataPelajaranId,
      tanggal: normalizedDate,
      jamAwal: jamAwal,
      jamAkhir: jamAkhir,
      materi: normalizedMateri,
      catatan: payload['catatan'] as String?,
      statusKehadiran: _normalizeStatusKehadiran(statusKehadiran),
    );
  }

  Future<void> updateJurnalDanAbsensiByKepsek({
    required String jurnalId,
    required String kelasId,
    required String mataPelajaranId,
    required DateTime tanggal,
    required int jamAwal,
    required int jamAkhir,
    required String materi,
    String? catatan,
    required String statusKehadiran,
    required List<KepsekAbsensiEditDraft> absensi,
  }) async {
    final normalizedMateri = materi.trim();
    if (normalizedMateri.isEmpty) {
      throw Exception('Materi tidak boleh kosong.');
    }
    if (jamAwal < 1 || jamAkhir > 8 || jamAkhir < jamAwal) {
      throw Exception('Rentang jam harus berada di rentang 1 sampai 8.');
    }

    final normalizedDate = _dateOnly(tanggal);
    final normalizedCatatan = (catatan == null || catatan.trim().isEmpty)
        ? null
        : catatan.trim();

    final jurnalService = _ref.read(jurnalServiceProvider);
    final absensiService = _ref.read(absensiJurnalServiceProvider);
    await jurnalService.update(jurnalId, {
      'kelas_id': kelasId,
      'mata_pelajaran_id': mataPelajaranId,
      'tanggal': normalizedDate,
      'jam_awal': jamAwal,
      'jam_akhir': jamAkhir,
      'jam_ke': jamAwal,
      'materi': normalizedMateri,
      'catatan': normalizedCatatan,
      'status': _normalizeStatusKehadiran(statusKehadiran),
      'status_kehadiran': _normalizeStatusKehadiran(statusKehadiran),
    });

    final absensiRows = absensi
        .map(
          (row) => <String, dynamic>{
            'siswa_uid': row.siswaId,
            'siswa_id': row.siswaId,
            'status': _normalizeStatusKehadiran(row.statusKehadiran)
                .toLowerCase(),
            'status_kehadiran':
                _normalizeStatusKehadiran(row.statusKehadiran).toLowerCase(),
            'keterangan': (row.catatan == null || row.catatan!.trim().isEmpty)
                ? null
                : row.catatan!.trim(),
            'catatan': (row.catatan == null || row.catatan!.trim().isEmpty)
                ? null
                : row.catatan!.trim(),
          },
        )
        .toList(growable: false);

    await absensiService.upsertByJurnalAndSiswaBatch(
      jurnalId: jurnalId,
      rows: absensiRows,
      tanggal: normalizedDate,
    );

    await jurnalService.cacheService.clearCollectionCacheByPrefix('jurnal');

    await _patchJurnalInMemory(
      jurnalId: jurnalId,
      kelasId: kelasId,
      mataPelajaranId: mataPelajaranId,
      tanggal: normalizedDate,
      jamAwal: jamAwal,
      jamAkhir: jamAkhir,
      materi: normalizedMateri,
      catatan: normalizedCatatan,
      statusKehadiran: _normalizeStatusKehadiran(statusKehadiran),
    );
  }

  Future<void> forceDeleteJurnalByKepsek(String jurnalId) async {
    final jurnalService = _ref.read(jurnalServiceProvider);
    final absensiService = _ref.read(absensiJurnalServiceProvider);

    final absensiByLink = await absensiService.getByJurnalId(jurnalId);
    for (final row in absensiByLink) {
      await absensiService.delete(row.id);
    }

    await jurnalService.delete(jurnalId);

    await absensiService.cacheService.clearCollectionCacheByPrefix(
      'absensi_jurnal',
    );
    await jurnalService.cacheService.clearCollectionCacheByPrefix('jurnal');

    _allJurnalRecords = _allJurnalRecords
        .where((item) => item.id != jurnalId)
        .toList(growable: false);
    _applyFilters();
  }

  Future<void> _ensureStaticOptionsLoaded({
    required bool forceRefreshData,
  }) async {
    if (_staticOptionsLoaded && !forceRefreshData) {
      return;
    }

    final sharedCache = _ref.read(sharedAcademicContextCacheProvider);
    final guruRecords = await sharedCache.getGuru(
      _ref.read,
      forceRefresh: forceRefreshData,
    );
    final kelasRecords = await sharedCache.getKelas(
      _ref.read,
      forceRefresh: forceRefreshData,
    );
    final mapelRecords = await sharedCache.getMapel(
      _ref.read,
      forceRefresh: forceRefreshData,
    );
    final tahunAjaranRecords = await sharedCache.getTahunAjaranLite(
      _ref.read,
      forceRefresh: forceRefreshData,
    );

    final guruOptions = <JurnalFilterOption>[
      const JurnalFilterOption(id: 'all', label: 'Semua Guru'),
      ...guruRecords
          .map((guru) => JurnalFilterOption(id: guru.uid, label: guru.nama))
          .toList()
        ..sort((a, b) => a.label.compareTo(b.label)),
    ];

    final kelasOptions = <JurnalFilterOption>[
      const JurnalFilterOption(id: 'all', label: 'Semua Kelas'),
      ...kelasRecords
          .map(
            (kelas) =>
                JurnalFilterOption(id: kelas.id, label: kelas.namaKelas),
          )
          .toList()
        ..sort((a, b) => a.label.compareTo(b.label)),
    ];

    final mapelOptions =
        mapelRecords
            .map(
              (mapel) =>
                  JurnalFilterOption(id: mapel.id, label: mapel.namaMapel),
            )
            .toList()
          ..sort((a, b) => a.label.compareTo(b.label));

    _guruByUid = {for (final guru in guruRecords) guru.uid: guru.nama};
    _kelasById = {for (final kelas in kelasRecords) kelas.id: kelas.namaKelas};
    _mapelById = {for (final mapel in mapelRecords) mapel.id: mapel.namaMapel};
    _tahunById = {for (final tahun in tahunAjaranRecords) tahun.id: tahun.nama};

    String? activeTahunAjaranName;
    for (final tahun in tahunAjaranRecords) {
      if (tahun.aktif) {
        activeTahunAjaranName = tahun.nama;
        break;
      }
    }

    state = state.copyWith(
      guruOptions: guruOptions,
      kelasOptions: kelasOptions,
      mapelOptions: mapelOptions,
      tahunAjaranOptions: tahunAjaranRecords
        .map((tahun) => tahun.nama)
        .where((item) => item.trim().isNotEmpty)
        .toList()
        ..sort(),
      activeTahunAjaranName: activeTahunAjaranName,
      error: null,
    );
    _staticOptionsLoaded = true;
  }

  void _applyFilters({
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMoreData,
  }) {
    final todayDate = _dateOnly(DateTime.now());
    final selectedDate = _dateOnly(state.selectedDate);

    final filtered = _allJurnalRecords.where((jurnal) {
      if (_todayOnly) {
        if (!_isSameDate(jurnal.tanggal, todayDate)) {
          return false;
        }
      } else if (!state.showAllDates) {
        if (!_isSameDate(jurnal.tanggal, selectedDate)) {
          return false;
        }
      }
      if (state.selectedGuruId != 'all' && jurnal.guruUid != state.selectedGuruId) {
        return false;
      }
      if (state.selectedKelasId != 'all' &&
          jurnal.kelasId != state.selectedKelasId) {
        return false;
      }
      return true;
    }).toList()
      ..sort((a, b) {
        final aTime =
            a.updatedAt ?? a.tanggal ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime =
            b.updatedAt ?? b.tanggal ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

    state = state.copyWith(
      data: filtered
          .map(
            (jurnal) => JurnalMonitoringItem(
              id: jurnal.id,
              guruUid: jurnal.guruUid,
              guruName: _guruByUid[jurnal.guruUid] ?? jurnal.guruUid,
              kelasId: jurnal.kelasId,
              kelasName: _kelasById[jurnal.kelasId] ?? jurnal.kelasId,
              mataPelajaranId: jurnal.mataPelajaranId,
              mataPelajaran:
                  _mapelById[jurnal.mataPelajaranId] ?? jurnal.mataPelajaranId,
              tahunAjaranId: jurnal.tahunAjaranId,
              tahunAjaranName:
                  _tahunById[jurnal.tahunAjaranId] ?? jurnal.tahunAjaranId,
              semester: jurnal.semester,
              tanggal: jurnal.tanggal,
              jamAwal: jurnal.jamAwal,
              jamAkhir: jurnal.jamAkhir,
              materi: jurnal.materi,
              status: jurnal.status,
              catatan: jurnal.catatan,
              updatedAt: jurnal.updatedAt,
            ),
          )
          .toList(growable: false),
      isLoading: isLoading ?? state.isLoading,
      isLoadingMore: isLoadingMore ?? state.isLoadingMore,
      hasMoreData: hasMoreData ?? state.hasMoreData,
    );
  }

  Future<JurnalHistoryPage> _fetchHistoryPage({
    required int limit,
    int? offset,
  }) {
    final selectedDate = _todayOnly
        ? _dateOnly(DateTime.now())
        : _dateOnly(state.selectedDate);

    return _ref.read(jurnalServiceProvider).getHistoryPage(
      tanggal: (_todayOnly || !state.showAllDates) ? selectedDate : null,
      guruUid: state.selectedGuruId,
      kelasId: state.selectedKelasId,
      limit: limit,
      offset: offset,
    );
  }

  Future<void> _patchJurnalInMemory({
    required String jurnalId,
    required String kelasId,
    required String mataPelajaranId,
    required DateTime tanggal,
    required int jamAwal,
    required int jamAkhir,
    required String materi,
    required String? catatan,
    required String statusKehadiran,
  }) async {
    JurnalRecord? original;
    for (final item in _allJurnalRecords) {
      if (item.id == jurnalId) {
        original = item;
        break;
      }
    }
    if (original == null) {
      await loadData(forceRefreshData: true);
      return;
    }

    final updated = original.copyWith(
      kelasId: kelasId,
      mataPelajaranId: mataPelajaranId,
      tanggal: tanggal,
      jamAwal: jamAwal,
      jamAkhir: jamAkhir,
      materi: materi,
      status: statusKehadiran,
      catatan: catatan,
      updatedAt: DateTime.now(),
    );

    _allJurnalRecords = _allJurnalRecords
        .map((item) => item.id == jurnalId ? updated : item)
        .toList(growable: false);
    _applyFilters();
  }

  String _normalizeStatusKehadiran(String raw) {
    final value = raw.trim().toLowerCase();
    switch (value) {
      case 'hadir':
        return 'Hadir';
      case 'masuk':
        return 'Masuk';
      case 'izin':
        return 'Izin';
      case 'sakit':
        return 'Sakit';
      case 'alpa':
      case 'alpha':
        return 'Alpa';
      default:
        return raw.trim().isEmpty ? 'Hadir' : raw.trim();
    }
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  bool _isSameDate(DateTime? value, DateTime expected) {
    if (value == null) {
      return false;
    }
    return value.year == expected.year &&
        value.month == expected.month &&
        value.day == expected.day;
  }
}

final hariIniJurnalMonitoringProvider =
    StateNotifierProvider<
      JurnalMonitoringNotifier,
      JurnalMonitoringState
    >((ref) {
      return JurnalMonitoringNotifier(ref, todayOnly: true);
    });

final historyJurnalMonitoringProvider =
    StateNotifierProvider<
      JurnalMonitoringNotifier,
      JurnalMonitoringState
    >((ref) {
      return JurnalMonitoringNotifier(ref, todayOnly: false);
    });
