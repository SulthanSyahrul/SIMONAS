import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/absensi_jurnal_model.dart';
import '../../../models/kelas_siswa_model.dart';
import '../../../models/jurnal_model.dart';
import '../../../providers/supabase_providers.dart';

class AbsensiDraft {
  final String siswaId;
  final String statusKehadiran;

  const AbsensiDraft({required this.siswaId, required this.statusKehadiran});
}

class AbsensiEditDraft {
  final String siswaId;
  final String statusKehadiran;
  final String? catatan;

  const AbsensiEditDraft({
    required this.siswaId,
    required this.statusKehadiran,
    required this.catatan,
  });
}

class JurnalCreateResult {
  final List<int> createdJams;
  final List<int> skippedDuplicateJams;
  final List<int> failedJams;

  const JurnalCreateResult({
    required this.createdJams,
    required this.skippedDuplicateJams,
    required this.failedJams,
  });
}

class JurnalAbsensiItem {
  final String id;
  final String guruUid;
  final String kelasId;
  final String kelasNama;
  final String mapelId;
  final String mapelNama;
  final String tahunAjaranId;
  final String tahunAjaranNama;
  final int semester;
  final DateTime? tanggal;
  final int jamAwal;
  final int jamAkhir;
  final String materi;
  final String statusKehadiran;
  final String? catatan;

  const JurnalAbsensiItem({
    required this.id,
    required this.guruUid,
    required this.kelasId,
    required this.kelasNama,
    required this.mapelId,
    required this.mapelNama,
    required this.tahunAjaranId,
    required this.tahunAjaranNama,
    required this.semester,
    required this.tanggal,
    required this.jamAwal,
    required this.jamAkhir,
    required this.materi,
    required this.statusKehadiran,
    required this.catatan,
  });
}

class JurnalAbsensiState {
  final List<JurnalAbsensiItem> jurnal;
  final Map<String, List<AbsensiJurnalRecord>> absensiByJurnalId;
  final List<KelasSiswaRecord> siswaKelasAktif;
  final Map<String, String> siswaNamaById;
  final bool isLoading;
  final String? error;

  const JurnalAbsensiState({
    required this.jurnal,
    required this.absensiByJurnalId,
    required this.siswaKelasAktif,
    required this.siswaNamaById,
    required this.isLoading,
    required this.error,
  });

  factory JurnalAbsensiState.initial() {
    return const JurnalAbsensiState(
      jurnal: <JurnalAbsensiItem>[],
      absensiByJurnalId: <String, List<AbsensiJurnalRecord>>{},
      siswaKelasAktif: <KelasSiswaRecord>[],
      siswaNamaById: <String, String>{},
      isLoading: false,
      error: null,
    );
  }

  List<JurnalAbsensiItem> get data => jurnal;

  JurnalAbsensiState copyWith({
    List<JurnalAbsensiItem>? jurnal,
    Map<String, List<AbsensiJurnalRecord>>? absensiByJurnalId,
    List<KelasSiswaRecord>? siswaKelasAktif,
    Map<String, String>? siswaNamaById,
    bool? isLoading,
    Object? error = _jurnalAbsensiSentinel,
  }) {
    return JurnalAbsensiState(
      jurnal: jurnal ?? this.jurnal,
      absensiByJurnalId: absensiByJurnalId ?? this.absensiByJurnalId,
      siswaKelasAktif: siswaKelasAktif ?? this.siswaKelasAktif,
      siswaNamaById: siswaNamaById ?? this.siswaNamaById,
      isLoading: isLoading ?? this.isLoading,
      error: error == _jurnalAbsensiSentinel ? this.error : error as String?,
    );
  }
}

class JurnalAbsensiNotifier extends StateNotifier<JurnalAbsensiState> {
  JurnalAbsensiNotifier(this._ref, this._guruUid)
    : super(JurnalAbsensiState.initial());

  final Ref _ref;
  final String _guruUid;
  Future<void>? _loadFuture;
  String? _loadKey;
  String? _loadedKey;

  Future<void> getJurnalByGuru({
    required String tahunAjaranId,
    required int semester,
    String? semesterId,
    bool includeAbsensi = true,
    bool forceRefreshData = false,
    bool forceRefreshCache = false,
  }) async {
    final requestKey = [
      tahunAjaranId.trim(),
      semester,
      semesterId?.trim() ?? '',
      includeAbsensi,
    ].join('|');
    final forceRefresh = forceRefreshData || forceRefreshCache;
    if (!forceRefresh && _loadedKey == requestKey && state.error == null) {
      return;
    }
    if (!forceRefresh && _loadKey == requestKey && _loadFuture != null) {
      return _loadFuture!;
    }

    final future = _fetchJurnalByGuru(
      tahunAjaranId: tahunAjaranId,
      semester: semester,
      semesterId: semesterId,
      includeAbsensi: includeAbsensi,
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

  Future<void> _fetchJurnalByGuru({
    required String tahunAjaranId,
    required int semester,
    String? semesterId,
    required bool includeAbsensi,
    required String requestKey,
    bool forceRefreshData = false,
    bool forceRefreshCache = false,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final filtered =
          await _ref
                .read(jurnalServiceProvider)
                .getJurnalByGuruAndContext(
                  guruUid: _guruUid,
                  tahunAjaranId: tahunAjaranId,
                  semester: semester,
                  semesterId: semesterId,
                )
            ..sort((a, b) {
              final left = a.tanggal ?? DateTime.fromMillisecondsSinceEpoch(0);
              final right = b.tanggal ?? DateTime.fromMillisecondsSinceEpoch(0);
              final dateCompare = right.compareTo(left);
              if (dateCompare != 0) {
                return dateCompare;
              }
              if (a.jamAwal != b.jamAwal) {
                return a.jamAwal.compareTo(b.jamAwal);
              }
              return a.jamAkhir.compareTo(b.jamAkhir);
            });

      final items = await _mapItems(filtered);
      final absensiMap = includeAbsensi
          ? await _loadAbsensiMap(filtered.map((item) => item.id))
          : state.absensiByJurnalId;

      if (!mounted) {
        return;
      }
      _loadedKey = requestKey;
      state = state.copyWith(
        jurnal: items,
        absensiByJurnalId: absensiMap,
        isLoading: false,
        error: null,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      state = state.copyWith(
        isLoading: false,
        error: 'Gagal memuat jurnal: $error',
      );
    }
  }

  Future<void> getSiswaByKelas(String kelasId) async {
    final active = await _ref
        .read(kelasSiswaServiceProvider)
        .getActiveRosterByKelas(kelasId);
    active.sort((a, b) {
      final left = (a.siswaNama ?? a.siswaId).toLowerCase();
      final right = (b.siswaNama ?? b.siswaId).toLowerCase();
      return left.compareTo(right);
    });
    final siswaNamaById = <String, String>{
      for (final item in active)
        if (item.siswaNama != null && item.siswaNama!.trim().isNotEmpty)
          item.siswaId: item.siswaNama!.trim(),
    };

    state = state.copyWith(
      siswaKelasAktif: active,
      siswaNamaById: siswaNamaById,
    );
  }

  Future<JurnalCreateResult> createJurnalMultiJam({
    required String kelasId,
    required String mapelId,
    required String tahunAjaranId,
    required int semester,
    String? semesterId,
    required DateTime tanggal,
    required int jamMulai,
    required int jamSelesai,
    required String materi,
    required String statusKehadiran,
    required String? catatan,
    required List<AbsensiDraft> absensi,
  }) async {
    final existing = await _ref
        .read(jurnalServiceProvider)
        .getJurnalByGuruAndContext(
          guruUid: _guruUid,
          tahunAjaranId: tahunAjaranId,
          semester: semester,
          semesterId: semesterId,
        );
    final sameDate = existing.where((item) {
      if (item.isDeleted) {
        return false;
      }
      final rowDate = item.tanggal;
      if (rowDate == null) {
        return false;
      }
      return rowDate.year == tanggal.year &&
          rowDate.month == tanggal.month &&
          rowDate.day == tanggal.day;
    }).toList();

    final duplicateJams = <int>{};
    for (final item in sameDate) {
      final overlaps = item.jamAwal <= jamSelesai && item.jamAkhir >= jamMulai;
      if (!overlaps) {
        continue;
      }
      for (final jam
          in item.jamAwal <= item.jamAkhir
              ? List<int>.generate(
                  item.jamAkhir - item.jamAwal + 1,
                  (i) => item.jamAwal + i,
                )
              : <int>[item.jamAwal]) {
        if (jam >= jamMulai && jam <= jamSelesai) {
          duplicateJams.add(jam);
        }
      }
    }

    final freeJams = <int>[];
    for (var jam = jamMulai; jam <= jamSelesai; jam++) {
      if (!duplicateJams.contains(jam)) {
        freeJams.add(jam);
      }
    }

    final failedJams = <int>[];
    for (final segment in _buildSegments(freeJams)) {
      try {
        final created = await _ref.read(jurnalServiceProvider).create({
          'guru_uid': _guruUid,
          'kelas_id': kelasId,
          'mapel_id': mapelId,
          'tahun_ajaran_id': tahunAjaranId,
          'semester': semester,
          'tanggal': tanggal,
          'jam_awal': segment.start,
          'jam_akhir': segment.end,
          'materi': materi,
          'status': statusKehadiran,
          'catatan': catatan,
        });

        if (absensi.isNotEmpty) {
          await _ref
              .read(absensiJurnalServiceProvider)
              .upsertByJurnalAndSiswaBatch(
                jurnalId: created.id,
                rows: absensi
                    .map(
                      (item) => <String, dynamic>{
                        'siswa_uid': item.siswaId,
                        'status_kehadiran': item.statusKehadiran,
                      },
                    )
                    .toList(growable: false),
              );
        }
      } catch (_) {
        failedJams.addAll(segment.expand());
      }
    }
    _loadedKey = null;

    await getJurnalByGuru(
      tahunAjaranId: tahunAjaranId,
      semester: semester,
      semesterId: semesterId,
      includeAbsensi: true,
      forceRefreshData: true,
      forceRefreshCache: true,
    );

    return JurnalCreateResult(
      createdJams: freeJams
          .where((item) => !failedJams.contains(item))
          .toList(),
      skippedDuplicateJams: duplicateJams.toList()..sort(),
      failedJams: failedJams,
    );
  }

  Future<void> updateJurnalWithAbsensi({
    required String jurnalId,
    required String kelasId,
    required String mapelId,
    required String tahunAjaranId,
    required int semester,
    String? semesterId,
    required DateTime tanggal,
    required int jamAwal,
    required int jamAkhir,
    required String materi,
    required String statusKehadiran,
    required String? catatan,
    required List<AbsensiEditDraft> absensi,
  }) async {
    await _ref.read(jurnalServiceProvider).update(jurnalId, {
      'kelas_id': kelasId,
      'mapel_id': mapelId,
      'tahun_ajaran_id': tahunAjaranId,
      'semester': semester,
      'tanggal': tanggal,
      'jam_awal': jamAwal,
      'jam_akhir': jamAkhir,
      'materi': materi,
      'status': statusKehadiran,
      'catatan': catatan,
    });

    await _ref
        .read(absensiJurnalServiceProvider)
        .upsertByJurnalAndSiswaBatch(
          jurnalId: jurnalId,
          rows: absensi
              .map(
                (item) => <String, dynamic>{
                  'siswa_uid': item.siswaId,
                  'status_kehadiran': item.statusKehadiran,
                  'catatan': item.catatan,
                },
              )
              .toList(growable: false),
        );
    _loadedKey = null;

    await getJurnalByGuru(
      tahunAjaranId: tahunAjaranId,
      semester: semester,
      semesterId: semesterId,
      includeAbsensi: true,
      forceRefreshData: true,
      forceRefreshCache: true,
    );
  }

  Future<void> deleteJurnal({
    required String jurnalId,
    required String? tahunAjaranId,
    required int semester,
    String? semesterId,
  }) async {
    await _ref.read(absensiJurnalServiceProvider).softDeleteByJurnalId(jurnalId);
    await _ref.read(jurnalServiceProvider).delete(jurnalId);
    _loadedKey = null;

    if (tahunAjaranId != null && tahunAjaranId.trim().isNotEmpty) {
      await getJurnalByGuru(
        tahunAjaranId: tahunAjaranId,
        semester: semester,
        semesterId: semesterId,
        includeAbsensi: true,
        forceRefreshData: true,
        forceRefreshCache: true,
      );
    }
  }

  Future<Map<String, List<AbsensiJurnalRecord>>> _loadAbsensiMap(
    Iterable<String> jurnalIds,
  ) async {
    final map = <String, List<AbsensiJurnalRecord>>{};
    final rows = await _ref
        .read(absensiJurnalServiceProvider)
        .getByJurnalIds(jurnalIds);
    for (final row in rows) {
      if (row.isDeleted) {
        continue;
      }
      map.putIfAbsent(row.jurnalId, () => <AbsensiJurnalRecord>[]);
      map[row.jurnalId]!.add(row);
    }
    return map;
  }

  Future<List<JurnalAbsensiItem>> _mapItems(List<JurnalRecord> rows) async {
    final tahunAjaranRows = await _ref
        .read(tahunAjaranServiceProvider)
        .getAllIncremental();
    final tahunAjaranNamaById = <String, String>{
      for (final item in tahunAjaranRows) item.id: item.nama,
    };

    return rows
        .map(
          (item) => JurnalAbsensiItem(
            id: item.id,
            guruUid: item.guruUid,
            kelasId: item.kelasId,
            kelasNama: item.kelasNama ?? item.kelasId,
            mapelId: item.mataPelajaranId,
            mapelNama: item.mapelNama ?? item.mataPelajaranId,
            tahunAjaranId: item.tahunAjaranId,
            tahunAjaranNama:
                tahunAjaranNamaById[item.tahunAjaranId] ?? item.tahunAjaranId,
            semester: item.semester,
            tanggal: item.tanggal,
            jamAwal: item.jamAwal,
            jamAkhir: item.jamAkhir,
            materi: item.materi,
            statusKehadiran: item.statusKehadiran,
            catatan: item.catatan,
          ),
        )
        .toList(growable: false);
  }

  List<_JamSegment> _buildSegments(List<int> jams) {
    if (jams.isEmpty) {
      return const <_JamSegment>[];
    }

    final sorted = [...jams]..sort();
    final segments = <_JamSegment>[];
    var start = sorted.first;
    var end = sorted.first;

    for (var index = 1; index < sorted.length; index++) {
      final current = sorted[index];
      if (current == end + 1) {
        end = current;
        continue;
      }
      segments.add(_JamSegment(start: start, end: end));
      start = current;
      end = current;
    }
    segments.add(_JamSegment(start: start, end: end));
    return segments;
  }
}

class _JamSegment {
  final int start;
  final int end;

  const _JamSegment({required this.start, required this.end});

  List<int> expand() {
    return List<int>.generate(end - start + 1, (index) => start + index);
  }
}

final jurnalAbsensiSupabaseProvider = StateNotifierProvider.autoDispose
    .family<JurnalAbsensiNotifier, JurnalAbsensiState, String>((ref, guruUid) {
      return JurnalAbsensiNotifier(ref, guruUid);
    });

const Object _jurnalAbsensiSentinel = Object();
