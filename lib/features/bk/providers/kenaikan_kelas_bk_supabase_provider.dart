import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/kelas_model.dart';
import '../../../models/kelas_siswa_model.dart';
import '../../../models/tahun_ajaran_model.dart';
import '../../../providers/supabase_providers.dart';

class KenaikanKelasBkCandidateItem {
  final String siswaId;
  final String siswaNama;
  final String kelasAsalNama;

  const KenaikanKelasBkCandidateItem({
    required this.siswaId,
    required this.siswaNama,
    required this.kelasAsalNama,
  });
}

class KenaikanKelasBkResult {
  final int total;
  final int naik;
  final int tinggal;
  final int lulus;

  const KenaikanKelasBkResult({
    required this.total,
    required this.naik,
    required this.tinggal,
    required this.lulus,
  });
}

class KenaikanKelasBkState {
  final List<TahunAjaranRecord> tahunAjaranOptions;
  final List<KelasRecord> kelasOptions;
  final List<KenaikanKelasBkCandidateItem> candidates;
  final bool isLoading;
  final String? error;

  const KenaikanKelasBkState({
    required this.tahunAjaranOptions,
    required this.kelasOptions,
    required this.candidates,
    required this.isLoading,
    required this.error,
  });

  factory KenaikanKelasBkState.initial() {
    return const KenaikanKelasBkState(
      tahunAjaranOptions: <TahunAjaranRecord>[],
      kelasOptions: <KelasRecord>[],
      candidates: <KenaikanKelasBkCandidateItem>[],
      isLoading: false,
      error: null,
    );
  }

  KenaikanKelasBkState copyWith({
    List<TahunAjaranRecord>? tahunAjaranOptions,
    List<KelasRecord>? kelasOptions,
    List<KenaikanKelasBkCandidateItem>? candidates,
    bool? isLoading,
    Object? error = _sentinelKenaikan,
  }) {
    return KenaikanKelasBkState(
      tahunAjaranOptions: tahunAjaranOptions ?? this.tahunAjaranOptions,
      kelasOptions: kelasOptions ?? this.kelasOptions,
      candidates: candidates ?? this.candidates,
      isLoading: isLoading ?? this.isLoading,
      error: error == _sentinelKenaikan ? this.error : error as String?,
    );
  }
}

class KenaikanKelasBkNotifier
    extends StateNotifier<KenaikanKelasBkState> {
  KenaikanKelasBkNotifier(this._ref)
    : super(KenaikanKelasBkState.initial());

  final Ref _ref;

  Future<void> loadMasterData() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final results = await Future.wait<dynamic>([
        _ref.read(tahunAjaranServiceProvider).getAllIncremental(),
        _ref.read(kelasServiceProvider).getAllIncremental(),
      ]);
      final tahun = results[0] as List<TahunAjaranRecord>;
      final kelas = results[1] as List<KelasRecord>;
      final sortedTahun = [...tahun.where((row) => !row.isDeleted)]
        ..sort((a, b) => b.nama.toLowerCase().compareTo(a.nama.toLowerCase()));
      final sortedKelas = [...kelas.where((row) => !row.isDeleted)]
        ..sort(
          (a, b) =>
              a.namaKelas.toLowerCase().compareTo(b.namaKelas.toLowerCase()),
        );
      state = state.copyWith(
        tahunAjaranOptions: sortedTahun,
        kelasOptions: sortedKelas,
        isLoading: false,
        error: null,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: 'Gagal memuat master kenaikan kelas: $error',
      );
    }
  }

  Future<void> loadCandidates({
    required String kelasAsalId,
    required String tahunAjaranAsalId,
    bool forceRefresh = false,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final service = _ref.read(kelasSiswaServiceProvider);
      final rawRows = await service.client
          .from('kelas_siswa')
          .select(
            'id, kelas_id, tahun_ajaran_id, status_aktif, is_deleted, siswa:siswa_uid(id, user_id, nama)',
          )
          .eq('kelas_id', service.normalizeIdValue(kelasAsalId))
          .eq('tahun_ajaran_id', service.normalizeIdValue(tahunAjaranAsalId))
          .eq('is_deleted', false)
          .eq('status_aktif', true);
      final filtered = (rawRows as List<dynamic>)
          .map((row) => _KenaikanSourceRow.fromRaw(row as Map))
          .where((row) => row.siswaUid.isNotEmpty)
          .toList(growable: false);
      final kelas = state.kelasOptions.isEmpty
          ? await _ref.read(kelasServiceProvider).getAllIncremental()
          : state.kelasOptions;
      final kelasNama =
          {for (final item in kelas) item.id: item.namaKelas}[kelasAsalId] ??
          kelasAsalId;

      final candidates =
          filtered
              .map((row) {
                return KenaikanKelasBkCandidateItem(
                  siswaId: row.siswaUid,
                  siswaNama: row.siswaNama.trim().isNotEmpty
                      ? row.siswaNama.trim()
                      : row.siswaUid,
                  kelasAsalNama: kelasNama,
                );
              })
              .toList(growable: false)
            ..sort(
              (a, b) => a.siswaNama.toLowerCase().compareTo(
                b.siswaNama.toLowerCase(),
              ),
            );

      state = state.copyWith(
        candidates: candidates,
        isLoading: false,
        error: null,
      );
    } catch (error) {
      state = state.copyWith(
        candidates: const <KenaikanKelasBkCandidateItem>[],
        isLoading: false,
        error: 'Gagal memuat kandidat kenaikan kelas: $error',
      );
    }
  }

  Future<KenaikanKelasBkResult> prosesKenaikan({
    required String kelasAsalId,
    required String? kelasTujuanId,
    required String tahunAjaranAsalId,
    required String tahunAjaranTujuanId,
    required Map<String, bool> keputusanNaikBySiswaId,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final kelasSiswaService = _ref.read(kelasSiswaServiceProvider);
      final rawSourceRows = await kelasSiswaService.client
          .from('kelas_siswa')
          .select(
            'id, kelas_id, tahun_ajaran_id, status_aktif, is_deleted, siswa:siswa_uid(id, user_id, nama)',
          )
          .eq('kelas_id', kelasSiswaService.normalizeIdValue(kelasAsalId))
          .eq(
            'tahun_ajaran_id',
            kelasSiswaService.normalizeIdValue(tahunAjaranAsalId),
          )
          .eq('is_deleted', false)
          .eq('status_aktif', true);
      final sourceRows = (rawSourceRows as List<dynamic>)
          .map((row) => _KenaikanSourceRow.fromRaw(row as Map))
          .where((row) => keputusanNaikBySiswaId.containsKey(row.siswaUid))
          .toList(growable: false);

      var naik = 0;
      var tinggal = 0;
      var lulus = 0;

      final siswaUids = sourceRows
          .map((row) => row.siswaUid)
          .toList(growable: false);
      final resolvedSiswaIdByUid = <String, Object>{
        for (final row in sourceRows) row.siswaUid: row.siswaInternalId,
      };
      final targetYearRowsBySiswa = await kelasSiswaService
          .getBySiswaUidsInTahunAjaran(
            siswaUids,
            tahunAjaranId: tahunAjaranTujuanId,
            includeDeleted: true,
            resolvedSiswaIdByUid: resolvedSiswaIdByUid,
          );
      final studentsWithTargetEnrollment = <String>[];
      final exactTargetRowIds = <String>[];
      final rowsToCreate = <Map<String, dynamic>>[];

      for (final row in sourceRows) {
        final shouldPromote = keputusanNaikBySiswaId[row.siswaUid] ?? false;

        if (kelasTujuanId == null) {
          if (shouldPromote) {
            lulus += 1;
          } else {
            tinggal += 1;
            studentsWithTargetEnrollment.add(row.siswaUid);
            final desiredKelasId = kelasAsalId;
            final targetRows =
                targetYearRowsBySiswa[row.siswaUid] ??
                const <KelasSiswaRecord>[];
            final exact = _findExactRow(targetRows, desiredKelasId);
            if (exact != null) {
              exactTargetRowIds.add(exact.id);
            } else {
              rowsToCreate.add(<String, dynamic>{
                'siswa_uid': row.siswaUid,
                'kelas_id': desiredKelasId,
                'tahun_ajaran_id': tahunAjaranTujuanId,
              });
            }
          }
          continue;
        }

        final nextKelasId = shouldPromote ? kelasTujuanId : kelasAsalId;
        if (shouldPromote) {
          naik += 1;
        } else {
          tinggal += 1;
        }
        studentsWithTargetEnrollment.add(row.siswaUid);
        final targetRows =
            targetYearRowsBySiswa[row.siswaUid] ?? const <KelasSiswaRecord>[];
        final exact = _findExactRow(targetRows, nextKelasId);
        if (exact != null) {
          exactTargetRowIds.add(exact.id);
        } else {
          rowsToCreate.add(<String, dynamic>{
            'siswa_uid': row.siswaUid,
            'kelas_id': nextKelasId,
            'tahun_ajaran_id': tahunAjaranTujuanId,
          });
        }
      }

      await kelasSiswaService.deactivateRowsByIds(
        sourceRows.map((row) => row.id),
      );
      if (studentsWithTargetEnrollment.isNotEmpty) {
        await kelasSiswaService.deactivateTargetYearRowsByUserIds(
          siswaUids: studentsWithTargetEnrollment,
          tahunAjaranId: tahunAjaranTujuanId,
          resolvedSiswaIdByUid: resolvedSiswaIdByUid,
        );
      }
      if (exactTargetRowIds.isNotEmpty) {
        await kelasSiswaService.activateRowsByIds(exactTargetRowIds);
      }
      if (rowsToCreate.isNotEmpty) {
        await kelasSiswaService.bulkCreateEnrollmentsByUserIds(
          rowsToCreate,
          resolvedSiswaIdByUid: resolvedSiswaIdByUid,
        );
      }

      await loadCandidates(
        kelasAsalId: kelasAsalId,
        tahunAjaranAsalId: tahunAjaranAsalId,
        forceRefresh: true,
      );
      return KenaikanKelasBkResult(
        total: sourceRows.length,
        naik: naik,
        tinggal: tinggal,
        lulus: lulus,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: 'Gagal memproses kenaikan kelas: $error',
      );
      rethrow;
    }
  }

  KelasSiswaRecord? _findExactRow(List<KelasSiswaRecord> rows, String kelasId) {
    for (final row in rows) {
      if (row.kelasId == kelasId) {
        return row;
      }
    }
    return null;
  }
}

class _KenaikanSourceRow {
  final String id;
  final String siswaUid;
  final Object siswaInternalId;
  final String siswaNama;

  const _KenaikanSourceRow({
    required this.id,
    required this.siswaUid,
    required this.siswaInternalId,
    required this.siswaNama,
  });

  factory _KenaikanSourceRow.fromRaw(Map raw) {
    final row = Map<String, dynamic>.from(raw.cast<String, dynamic>());
    final siswaRaw = row['siswa'];
    final siswa = siswaRaw is Map
        ? Map<String, dynamic>.from(siswaRaw.cast<String, dynamic>())
        : siswaRaw is List && siswaRaw.isNotEmpty
        ? Map<String, dynamic>.from(
            (siswaRaw.first as Map).cast<String, dynamic>(),
          )
        : const <String, dynamic>{};
    final internalId = siswa['id'];
    if (internalId == null) {
      throw Exception('Relasi siswa tidak lengkap.');
    }
    return _KenaikanSourceRow(
      id: row['id']?.toString() ?? '',
      siswaUid: siswa['user_id']?.toString() ?? '',
      siswaInternalId: internalId,
      siswaNama: siswa['nama']?.toString() ?? '',
    );
  }
}

final kenaikanKelasBkProvider =
    StateNotifierProvider.autoDispose<
      KenaikanKelasBkNotifier,
      KenaikanKelasBkState
    >((ref) {
      return KenaikanKelasBkNotifier(ref);
    });

const Object _sentinelKenaikan = Object();
