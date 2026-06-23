import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/histori_wali_kelas_model.dart';
import '../../../models/kelas_model.dart';
import '../../../models/mapel_model.dart';
import '../../../models/user_model.dart';
import '../../../providers/supabase_providers.dart';
import '../../shared/providers/shared_academic_context_provider.dart';

class JadwalManajemenItem {
  final String id;
  final String guruUid;
  final String guruName;
  final String kelasId;
  final String kelasName;
  final String mapelId;
  final String mapelName;
  final String hari;
  final int jamAwal;
  final int jamAkhir;
  final int semester;

  const JadwalManajemenItem({
    required this.id,
    required this.guruUid,
    required this.guruName,
    required this.kelasId,
    required this.kelasName,
    required this.mapelId,
    required this.mapelName,
    required this.hari,
    required this.jamAwal,
    required this.jamAkhir,
    required this.semester,
  });

  int get jamKe => jamAwal;

  bool overlapsWithRange(int otherAwal, int otherAkhir) {
    return jamAwal <= otherAkhir && jamAkhir >= otherAwal;
  }

  List<int> expandJams() {
    if (jamAkhir < jamAwal) {
      return <int>[jamAwal];
    }
    return List<int>.generate(jamAkhir - jamAwal + 1, (index) => jamAwal + index);
  }
}

class JadwalRangeOperationResult {
  final List<int> createdJams;
  final List<int> updatedJams;
  final List<int> deletedJams;
  final List<int> skippedJams;

  const JadwalRangeOperationResult({
    required this.createdJams,
    required this.updatedJams,
    required this.deletedJams,
    required this.skippedJams,
  });
}

class JadwalManajemenState {
  final String tahunAjaranId;
  final List<JadwalManajemenItem> data;
  final List<UserRecord> guruOptions;
  final List<KelasRecord> kelasOptions;
  final List<MapelRecord> mapelOptions;
  final bool isLoading;
  final String? error;

  const JadwalManajemenState({
    required this.tahunAjaranId,
    required this.data,
    required this.guruOptions,
    required this.kelasOptions,
    required this.mapelOptions,
    required this.isLoading,
    this.error,
  });

  factory JadwalManajemenState.initial(String tahunAjaranId) {
    return JadwalManajemenState(
      tahunAjaranId: tahunAjaranId,
      data: const [],
      guruOptions: const [],
      kelasOptions: const [],
      mapelOptions: const [],
      isLoading: false,
    );
  }

  JadwalManajemenState copyWith({
    String? tahunAjaranId,
    List<JadwalManajemenItem>? data,
    List<UserRecord>? guruOptions,
    List<KelasRecord>? kelasOptions,
    List<MapelRecord>? mapelOptions,
    bool? isLoading,
    String? error,
  }) {
    return JadwalManajemenState(
      tahunAjaranId: tahunAjaranId ?? this.tahunAjaranId,
      data: data ?? this.data,
      guruOptions: guruOptions ?? this.guruOptions,
      kelasOptions: kelasOptions ?? this.kelasOptions,
      mapelOptions: mapelOptions ?? this.mapelOptions,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class JadwalManajemenNotifier extends StateNotifier<JadwalManajemenState> {
  final Ref _ref;
  bool _isDisposed = false;

  JadwalManajemenNotifier(this._ref, {required String tahunAjaranId})
    : super(JadwalManajemenState.initial(tahunAjaranId));

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  void _setStateIfActive(JadwalManajemenState nextState) {
    if (_isDisposed) {
      return;
    }
    state = nextState;
  }

  int _compareKelas(KelasRecord a, KelasRecord b) {
    final aGrade = _extractKelasGrade(a.namaKelas);
    final bGrade = _extractKelasGrade(b.namaKelas);
    if (aGrade != bGrade) {
      return aGrade.compareTo(bGrade);
    }

    final aSection = _extractKelasSection(a.namaKelas);
    final bSection = _extractKelasSection(b.namaKelas);
    if (aSection != bSection) {
      return aSection.compareTo(bSection);
    }

    return a.namaKelas.toLowerCase().compareTo(b.namaKelas.toLowerCase());
  }

  int _extractKelasGrade(String namaKelas) {
    final normalized = namaKelas.trim().toUpperCase();
    final match = RegExp(r'^(\d+)').firstMatch(normalized);
    return int.tryParse(match?.group(1) ?? '') ?? 999;
  }

  int _extractKelasSection(String namaKelas) {
    final normalized = namaKelas.trim().toUpperCase();
    final match = RegExp(r'^(\d+)\s*([A-Z])$').firstMatch(normalized);
    if (match == null) {
      return 999;
    }

    final section = match.group(2);
    if (section == null || section.isEmpty) {
      return 999;
    }

    return section.codeUnitAt(0) - 64;
  }

  Future<void> loadData({bool forceRefreshData = false}) async {
    _setStateIfActive(state.copyWith(isLoading: true, error: null));

    try {
      final appMasterCache = _ref.read(appMasterCacheProvider);
      final guruOptions = await appMasterCache.getGuru(
        _ref.read,
        forceRefresh: forceRefreshData,
      );
      final kelasAll = await appMasterCache.getKelas(
        _ref.read,
        forceRefresh: forceRefreshData,
      );
      final mapelOptions = await appMasterCache.getMapel(
        _ref.read,
        forceRefresh: forceRefreshData,
      );
      final jadwalAll = await _ref
          .read(jadwalServiceProvider)
          .getByTahunAjaranId(
            state.tahunAjaranId,
            forceFullFetch: forceRefreshData,
          );

      var kelasOptions = kelasAll
          .where((kelas) => kelas.tahunAjaranId == state.tahunAjaranId)
          .toList();
      if (kelasOptions.isEmpty) {
        kelasOptions = kelasAll;
      }
      kelasOptions.sort(_compareKelas);

      final guruByUid = {for (final guru in guruOptions) guru.uid: guru.nama};
      final kelasById = {
        for (final kelas in kelasAll) kelas.id: kelas.namaKelas,
      };
      final mapelById = {
        for (final mapel in mapelOptions) mapel.id: mapel.namaMapel,
      };

      var jadwalFiltered = jadwalAll
          .where((jadwal) => jadwal.tahunAjaranId == state.tahunAjaranId)
          .toList();
      if (jadwalFiltered.isEmpty) {
        jadwalFiltered = jadwalAll;
      }

      final dayOrder = {
        'Senin': 1,
        'Selasa': 2,
        'Rabu': 3,
        'Kamis': 4,
        'Jumat': 5,
        'Sabtu': 6,
      };

      final data =
          jadwalFiltered
              .map(
                (jadwal) => JadwalManajemenItem(
                  id: jadwal.id,
                  guruUid: jadwal.guruUid,
                  guruName: guruByUid[jadwal.guruUid] ?? jadwal.guruUid,
                  kelasId: jadwal.kelasId,
                  kelasName: kelasById[jadwal.kelasId] ?? jadwal.kelasId,
                  mapelId: jadwal.mapelId,
                  mapelName: mapelById[jadwal.mapelId] ?? jadwal.mapelId,
                  hari: jadwal.hari,
                  jamAwal: jadwal.jamAwal,
                  jamAkhir: jadwal.jamAkhir,
                  semester: jadwal.semester,
                ),
              )
              .toList()
            ..sort((a, b) {
              final aDay = dayOrder[a.hari] ?? 99;
              final bDay = dayOrder[b.hari] ?? 99;
              if (aDay != bDay) {
                return aDay.compareTo(bDay);
              }
              if (a.jamAwal != b.jamAwal) {
                return a.jamAwal.compareTo(b.jamAwal);
              }
              return a.jamAkhir.compareTo(b.jamAkhir);
            });

      _setStateIfActive(
        state.copyWith(
          data: data,
          guruOptions: guruOptions,
          kelasOptions: kelasOptions,
          mapelOptions: mapelOptions,
          isLoading: false,
        ),
      );
    } catch (e) {
      _setStateIfActive(
        state.copyWith(isLoading: false, error: 'Gagal memuat jadwal guru: $e'),
      );
    }
  }

  String? validateConflict({
    required String guruUid,
    required String kelasId,
    required String hari,
    required int jamKe,
    String? excludeJadwalId,
  }) {
    return _validateConflictForRange(
      guruUid: guruUid,
      kelasId: kelasId,
      hari: hari,
      jamMulai: jamKe,
      jamSelesai: jamKe,
      excludeJadwalIds: excludeJadwalId == null
          ? const <String>{}
          : <String>{excludeJadwalId},
    );
  }

  String? validateJamRange({required int jamMulai, required int jamSelesai}) {
    if (jamMulai < 1 || jamMulai > 8 || jamSelesai < 1 || jamSelesai > 8) {
      return 'Jam harus berada di rentang 1 sampai 8.';
    }
    if (jamSelesai < jamMulai) {
      return 'Jam selesai harus lebih besar atau sama dengan jam mulai.';
    }
    return null;
  }

  String? _validateConflictForRange({
    required String guruUid,
    required String kelasId,
    required String hari,
    required int jamMulai,
    required int jamSelesai,
    Set<String> excludeJadwalIds = const <String>{},
  }) {
    for (final item in state.data) {
      if (excludeJadwalIds.contains(item.id)) {
        continue;
      }
      if (item.hari != hari || !item.overlapsWithRange(jamMulai, jamSelesai)) {
        continue;
      }

      final overlapAwal = item.jamAwal > jamMulai ? item.jamAwal : jamMulai;
      final overlapAkhir = item.jamAkhir < jamSelesai ? item.jamAkhir : jamSelesai;
      final overlapText = overlapAwal == overlapAkhir
          ? 'jam ke-$overlapAwal'
          : 'jam ke-$overlapAwal s.d. ke-$overlapAkhir';

      if (item.kelasId == kelasId) {
        return 'Jadwal bentrok pada $overlapText: Hari + Kelas sudah terpakai.';
      }
      if (item.guruUid == guruUid) {
        return 'Guru bentrok pada $overlapText: guru tidak boleh mengajar dua kelas pada waktu yang sama.';
      }
    }

    return null;
  }

  Future<void> createJadwal({
    required String guruUid,
    required String kelasId,
    required String mapelId,
    required String hari,
    required int jamKe,
    int semester = 1,
  }) async {
    await createJadwalRange(
      guruUid: guruUid,
      kelasId: kelasId,
      mapelId: mapelId,
      hari: hari,
      jamMulai: jamKe,
      jamSelesai: jamKe,
      semester: semester,
    );
  }

  Future<JadwalRangeOperationResult> createJadwalRange({
    required String guruUid,
    required String kelasId,
    required String mapelId,
    required String hari,
    required int jamMulai,
    required int jamSelesai,
    int semester = 1,
  }) async {
    final rangeError = validateJamRange(
      jamMulai: jamMulai,
      jamSelesai: jamSelesai,
    );
    if (rangeError != null) {
      throw Exception(rangeError);
    }

    final localConflict = _validateConflictForRange(
      guruUid: guruUid,
      kelasId: kelasId,
      hari: hari,
      jamMulai: jamMulai,
      jamSelesai: jamSelesai,
    );
    if (localConflict != null) {
      throw Exception(localConflict);
    }

    final service = _ref.read(jadwalServiceProvider);

    try {
      final guruServerConflict = await service.existsGuruOverlapRange(
        guruUid: guruUid,
        hari: hari,
        jamMulai: jamMulai,
        jamSelesai: jamSelesai,
        tahunAjaranId: state.tahunAjaranId,
        semester: semester,
      );
      if (guruServerConflict) {
        throw Exception(
          'Guru bentrok dengan jadwal lain pada rentang jam yang dipilih.',
        );
      }

      final kelasServerConflict = await service.existsKelasOverlapRange(
        kelasId: kelasId,
        hari: hari,
        jamMulai: jamMulai,
        jamSelesai: jamSelesai,
        tahunAjaranId: state.tahunAjaranId,
        semester: semester,
      );
      if (kelasServerConflict) {
        throw Exception(
          'Kelas bentrok dengan jadwal lain pada rentang jam yang dipilih.',
        );
      }

      await service.create({
        'guru_uid': guruUid,
        'kelas_id': kelasId,
        'mapel_id': mapelId,
        'tahun_ajaran_id': state.tahunAjaranId,
        'semester': semester,
        'hari': hari,
        'jam_awal': jamMulai,
        'jam_akhir': jamSelesai,
      });

      await loadData(forceRefreshData: true);

      final created = List<int>.generate(
        jamSelesai - jamMulai + 1,
        (index) => jamMulai + index,
      );
      return JadwalRangeOperationResult(
        createdJams: created,
        updatedJams: const <int>[],
        deletedJams: const <int>[],
        skippedJams: const <int>[],
      );
    } catch (e) {
      throw Exception('Gagal menambah jadwal: $e');
    }
  }

  Future<void> updateJadwal({
    required String jadwalId,
    required String guruUid,
    required String kelasId,
    required String mapelId,
    required String hari,
    required int jamKe,
    int semester = 1,
  }) async {
    await updateJadwalRange(
      jadwalId: jadwalId,
      oldGuruUid: guruUid,
      oldKelasId: kelasId,
      oldMapelId: mapelId,
      oldHari: hari,
      oldSemester: semester,
      oldJamMulai: jamKe,
      oldJamSelesai: jamKe,
      guruUid: guruUid,
      kelasId: kelasId,
      mapelId: mapelId,
      hari: hari,
      jamMulai: jamKe,
      jamSelesai: jamKe,
      semester: semester,
    );
  }

  Future<JadwalRangeOperationResult> updateJadwalRange({
    required String jadwalId,
    required String oldGuruUid,
    required String oldKelasId,
    required String oldMapelId,
    required String oldHari,
    required int oldSemester,
    required int oldJamMulai,
    required int oldJamSelesai,
    required String guruUid,
    required String kelasId,
    required String mapelId,
    required String hari,
    required int jamMulai,
    required int jamSelesai,
    int semester = 1,
  }) async {
    final rangeError = validateJamRange(
      jamMulai: jamMulai,
      jamSelesai: jamSelesai,
    );
    if (rangeError != null) {
      throw Exception(rangeError);
    }

    final editableRows = state.data.where((item) {
      return item.guruUid == oldGuruUid &&
          item.kelasId == oldKelasId &&
          item.mapelId == oldMapelId &&
          item.hari == oldHari &&
          item.semester == oldSemester &&
          item.overlapsWithRange(oldJamMulai, oldJamSelesai);
    }).toList();

    final editableIds = editableRows.map((row) => row.id).toSet();
    if (editableIds.isEmpty) {
      editableIds.add(jadwalId);
    }

    final localConflict = _validateConflictForRange(
      guruUid: guruUid,
      kelasId: kelasId,
      hari: hari,
      jamMulai: jamMulai,
      jamSelesai: jamSelesai,
      excludeJadwalIds: editableIds,
    );
    if (localConflict != null) {
      throw Exception(localConflict);
    }

    final service = _ref.read(jadwalServiceProvider);
    final created = <int>[];
    final updated = <int>[];
    final deleted = <int>[];
    final skipped = <int>[];

    try {
      final guruServerConflict = await service.existsGuruOverlapRange(
        guruUid: guruUid,
        hari: hari,
        jamMulai: jamMulai,
        jamSelesai: jamSelesai,
        tahunAjaranId: state.tahunAjaranId,
        semester: semester,
        excludeIds: editableIds,
      );
      if (guruServerConflict) {
        throw Exception(
          'Guru bentrok dengan jadwal lain pada rentang jam yang dipilih.',
        );
      }

      final kelasServerConflict = await service.existsKelasOverlapRange(
        kelasId: kelasId,
        hari: hari,
        jamMulai: jamMulai,
        jamSelesai: jamSelesai,
        tahunAjaranId: state.tahunAjaranId,
        semester: semester,
        excludeIds: editableIds,
      );
      if (kelasServerConflict) {
        throw Exception(
          'Kelas bentrok dengan jadwal lain pada rentang jam yang dipilih.',
        );
      }

      final sameSingleDoc = editableRows.length == 1 && editableRows.first.id == jadwalId;
      final nextRange = List<int>.generate(
        jamSelesai - jamMulai + 1,
        (index) => jamMulai + index,
      );

      if (sameSingleDoc) {
        await service.update(jadwalId, {
          'guru_uid': guruUid,
          'kelas_id': kelasId,
          'mapel_id': mapelId,
          'tahun_ajaran_id': state.tahunAjaranId,
          'semester': semester,
          'hari': hari,
          'jam_awal': jamMulai,
          'jam_akhir': jamSelesai,
        });
        updated.addAll(nextRange);
      } else {
        for (final row in editableRows) {
          await service.delete(row.id);
          deleted.addAll(row.expandJams());
        }

        await service.create({
          'guru_uid': guruUid,
          'kelas_id': kelasId,
          'mapel_id': mapelId,
          'tahun_ajaran_id': state.tahunAjaranId,
          'semester': semester,
          'hari': hari,
          'jam_awal': jamMulai,
          'jam_akhir': jamSelesai,
        });
        created.addAll(nextRange);
      }

      await loadData(forceRefreshData: true);
      return JadwalRangeOperationResult(
        createdJams: created,
        updatedJams: updated,
        deletedJams: deleted,
        skippedJams: skipped,
      );
    } catch (e) {
      throw Exception('Gagal mengupdate jadwal: $e');
    }
  }

  Future<void> deleteJadwal(String jadwalId) async {
    try {
      await _ref.read(jadwalServiceProvider).delete(jadwalId);
      await loadData();
    } catch (e) {
      throw Exception('Gagal menghapus jadwal: $e');
    }
  }
}

class WaliKelasManajemenItem {
  final String kelasId;
  final String kelasName;
  final int lantai;
  final String? waliKelasUid;
  final String? waliKelasName;

  const WaliKelasManajemenItem({
    required this.kelasId,
    required this.kelasName,
    required this.lantai,
    required this.waliKelasUid,
    required this.waliKelasName,
  });

  bool get hasWaliKelas =>
      waliKelasUid != null && waliKelasUid!.trim().isNotEmpty;
}

class WaliKelasManajemenState {
  final String tahunAjaranId;
  final List<WaliKelasManajemenItem> data;
  final List<UserRecord> guruOptions;
  final List<KelasRecord> kelasOptions;
  final bool isLoading;
  final String? error;

  const WaliKelasManajemenState({
    required this.tahunAjaranId,
    required this.data,
    required this.guruOptions,
    required this.kelasOptions,
    required this.isLoading,
    this.error,
  });

  factory WaliKelasManajemenState.initial(String tahunAjaranId) {
    return WaliKelasManajemenState(
      tahunAjaranId: tahunAjaranId,
      data: const [],
      guruOptions: const [],
      kelasOptions: const [],
      isLoading: false,
    );
  }

  WaliKelasManajemenState copyWith({
    String? tahunAjaranId,
    List<WaliKelasManajemenItem>? data,
    List<UserRecord>? guruOptions,
    List<KelasRecord>? kelasOptions,
    bool? isLoading,
    String? error,
  }) {
    return WaliKelasManajemenState(
      tahunAjaranId: tahunAjaranId ?? this.tahunAjaranId,
      data: data ?? this.data,
      guruOptions: guruOptions ?? this.guruOptions,
      kelasOptions: kelasOptions ?? this.kelasOptions,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class WaliKelasManajemenNotifier
    extends StateNotifier<WaliKelasManajemenState> {
  final Ref _ref;
  bool _isDisposed = false;

  WaliKelasManajemenNotifier(this._ref, {required String tahunAjaranId})
    : super(WaliKelasManajemenState.initial(tahunAjaranId));

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  void _setStateIfActive(WaliKelasManajemenState nextState) {
    if (_isDisposed) {
      return;
    }
    state = nextState;
  }

  Future<void> loadData({bool forceRefreshData = false}) async {
    _setStateIfActive(state.copyWith(isLoading: true, error: null));

    try {
      final appMasterCache = _ref.read(appMasterCacheProvider);
      final guruOptions = await appMasterCache.getGuru(
        _ref.read,
        forceRefresh: forceRefreshData,
      );
      final kelasAll = await appMasterCache.getKelas(
        _ref.read,
        forceRefresh: forceRefreshData,
      );

      final kelasOptions = [...kelasAll]..sort((a, b) => a.namaKelas.compareTo(b.namaKelas));

      final historiRows = await _ref
          .read(historiWaliKelasServiceProvider)
          .getByTahunAjaranId(
            state.tahunAjaranId,
            forceFullFetch: forceRefreshData,
          );

      final activeAssignments = historiRows
          .where((row) => !row.isDeleted && row.isAktif)
          .toList(growable: false);
      final activeByKelasId = <String, HistoriWaliKelasRecord>{};
      for (final row in activeAssignments) {
        final existing = activeByKelasId[row.kelasId];
        if (existing == null || _sortByLatestAssignment(row, existing) < 0) {
          activeByKelasId[row.kelasId] = row;
        }
      }

      final guruByUid = {for (final guru in guruOptions) guru.uid: guru.nama};

      final data =
          kelasOptions
              .map(
                (kelas) => WaliKelasManajemenItem(
                  kelasId: kelas.id,
                  kelasName: kelas.namaKelas,
                  lantai: kelas.lantai,
                  waliKelasUid: activeByKelasId[kelas.id]?.guruUid,
                  waliKelasName: activeByKelasId[kelas.id] == null
                      ? null
                      : (guruByUid[activeByKelasId[kelas.id]!.guruUid] ??
                            activeByKelasId[kelas.id]!.guruUid),
                ),
              )
              .toList()
            ..sort((a, b) => a.kelasName.compareTo(b.kelasName));

      _setStateIfActive(
        state.copyWith(
          data: data,
          guruOptions: guruOptions,
          kelasOptions: kelasOptions,
          isLoading: false,
        ),
      );
    } catch (e) {
      _setStateIfActive(
        state.copyWith(
          isLoading: false,
          error: 'Gagal memuat data wali kelas: $e',
        ),
      );
    }
  }

  Future<void> assignWaliKelas({
    required String kelasId,
    required String guruUid,
  }) async {
    final duplicateGuru = state.data.any(
      (item) => item.kelasId != kelasId && item.waliKelasUid == guruUid,
    );
    if (duplicateGuru) {
      throw Exception('Guru sudah menjadi wali di kelas lain.');
    }

    try {
      final historiService = _ref.read(historiWaliKelasServiceProvider);
      final kelasService = _ref.read(kelasServiceProvider);

      final kelasHistory = await historiService.getByTahunAjaranAndKelas(
        state.tahunAjaranId,
        kelasId,
        forceFullFetch: true,
      );
      for (final row in kelasHistory) {
        if (!row.isDeleted && row.isAktif) {
          await historiService.update(row.id, <String, dynamic>{'isAktif': false});
        }
      }

      final guruHistory = await historiService.getByGuruAndTahunAjaran(
        guruUid,
        state.tahunAjaranId,
        onlyAktif: true,
        forceFullFetch: true,
      );
      for (final row in guruHistory) {
        if (!row.isDeleted && row.kelasId != kelasId) {
          await historiService.update(row.id, <String, dynamic>{'isAktif': false});
        }
      }

      await historiService.create(<String, dynamic>{
        'kelas_id': kelasId,
        'guru_uid': guruUid,
        'tahun_ajaran_id': state.tahunAjaranId,
        'isAktif': true,
      });

      // Mirror ke field lama sementara untuk kompatibilitas bertahap.
      await kelasService.update(kelasId, <String, dynamic>{'wali_kelas_uid': guruUid});
      await loadData(forceRefreshData: true);
    } catch (e) {
      throw Exception('Gagal menyimpan wali kelas: $e');
    }
  }

  Future<void> clearWaliKelas(String kelasId) async {
    try {
      final historiService = _ref.read(historiWaliKelasServiceProvider);
      final kelasHistory = await historiService.getByTahunAjaranAndKelas(
        state.tahunAjaranId,
        kelasId,
        forceFullFetch: true,
      );
      for (final row in kelasHistory) {
        if (!row.isDeleted && row.isAktif) {
          await historiService.update(row.id, <String, dynamic>{'isAktif': false});
        }
      }

      // Mirror ke field lama sementara untuk kompatibilitas bertahap.
      await _ref.read(kelasServiceProvider).update(kelasId, <String, dynamic>{
        'wali_kelas_uid': null,
      });
      await loadData(forceRefreshData: true);
    } catch (e) {
      throw Exception('Gagal menghapus wali kelas: $e');
    }
  }

  Future<void> deleteWaliKelas(String kelasId) async {
    await clearWaliKelas(kelasId);
  }

  int _sortByLatestAssignment(
    HistoriWaliKelasRecord a,
    HistoriWaliKelasRecord b,
  ) {
    final left = a.updatedAt ?? a.createdAt;
    final right = b.updatedAt ?? b.createdAt;
    if (left == null && right == null) {
      return 0;
    }
    if (left == null) {
      return 1;
    }
    if (right == null) {
      return -1;
    }
    return right.compareTo(left);
  }
}

final jadwalGuruManagementProvider = StateNotifierProvider
    .family<JadwalManajemenNotifier, JadwalManajemenState, String>((
      ref,
      tahunAjaranId,
    ) {
      final notifier = JadwalManajemenNotifier(
        ref,
        tahunAjaranId: tahunAjaranId,
      );
      Future.microtask(notifier.loadData);
      return notifier;
    });

final waliKelasManagementProvider = StateNotifierProvider
    .family<WaliKelasManajemenNotifier, WaliKelasManajemenState, String>((
      ref,
      tahunAjaranId,
    ) {
      final notifier = WaliKelasManajemenNotifier(
        ref,
        tahunAjaranId: tahunAjaranId,
      );
      Future.microtask(notifier.loadData);
      return notifier;
    });
