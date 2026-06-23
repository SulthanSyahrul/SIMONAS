import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/nilai_akhir_calculator.dart';
import '../../../models/nilai_ujian_model.dart';
import '../../../providers/supabase_providers.dart';

class RaportMapelNilai {
  final String mataPelajaranId;
  final double? nilaiTugas;
  final double? nilaiUts;
  final double? nilaiUas;
  final double? nilaiAkhir;
  final String? catatan;

  const RaportMapelNilai({
    required this.mataPelajaranId,
    required this.nilaiTugas,
    required this.nilaiUts,
    required this.nilaiUas,
    required this.nilaiAkhir,
    required this.catatan,
  });
}

class RaportSiswaRingkasan {
  final String siswaId;
  final String siswaNama;
  final List<RaportMapelNilai> nilai;

  const RaportSiswaRingkasan({
    required this.siswaId,
    required this.siswaNama,
    required this.nilai,
  });
}

class RaportGuruState {
  final List<RaportSiswaRingkasan> siswa;
  final bool isLoading;
  final String? error;

  const RaportGuruState({
    required this.siswa,
    required this.isLoading,
    required this.error,
  });

  factory RaportGuruState.initial() {
    return const RaportGuruState(
      siswa: <RaportSiswaRingkasan>[],
      isLoading: false,
      error: null,
    );
  }

  RaportGuruState copyWith({
    List<RaportSiswaRingkasan>? siswa,
    bool? isLoading,
    Object? error = _raportGuruSentinel,
  }) {
    return RaportGuruState(
      siswa: siswa ?? this.siswa,
      isLoading: isLoading ?? this.isLoading,
      error: error == _raportGuruSentinel ? this.error : error as String?,
    );
  }
}

class RaportGuruNotifier extends StateNotifier<RaportGuruState> {
  RaportGuruNotifier(this._ref, this._guruUid)
    : super(RaportGuruState.initial());

  final Ref _ref;
  final String _guruUid;
  Future<void>? _loadFuture;
  String? _loadKey;
  String? _loadedKey;

  Future<void> getRaport({
    String? kelasId,
    String? tahunAjaranId,
    String? mataPelajaranId,
    bool forceRefreshData = false,
  }) async {
    final requestKey = [
      kelasId?.trim() ?? '',
      tahunAjaranId?.trim() ?? '',
      mataPelajaranId?.trim() ?? '',
    ].join('|');
    if (!forceRefreshData && _loadedKey == requestKey && state.error == null) {
      return;
    }
    if (!forceRefreshData && _loadKey == requestKey && _loadFuture != null) {
      return _loadFuture!;
    }

    final future = _fetchRaport(
      kelasId: kelasId,
      tahunAjaranId: tahunAjaranId,
      mataPelajaranId: mataPelajaranId,
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

  Future<void> _fetchRaport({
    String? kelasId,
    String? tahunAjaranId,
    String? mataPelajaranId,
    required String requestKey,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final historiWaliKelas = await _ref
          .read(historiWaliKelasServiceProvider)
          .getScopeByGuru(_guruUid, onlyAktif: true);
      final waliAssignments = historiWaliKelas
          .where((item) => !item.isDeleted && item.isAktif)
          .toList(growable: false);

      if (waliAssignments.isEmpty) {
        if (!mounted) {
          return;
        }
        _loadedKey = requestKey;
        state = state.copyWith(
          siswa: const <RaportSiswaRingkasan>[],
          isLoading: false,
          error: null,
        );
        return;
      }

      final normalizedTahunAjaranId = tahunAjaranId?.trim();
      final scopedAssignments =
          normalizedTahunAjaranId != null && normalizedTahunAjaranId.isNotEmpty
          ? waliAssignments
                .where((item) => item.tahunAjaranId == normalizedTahunAjaranId)
                .toList(growable: false)
          : waliAssignments;

      if (scopedAssignments.isEmpty) {
        if (!mounted) {
          return;
        }
        _loadedKey = requestKey;
        state = state.copyWith(
          siswa: const <RaportSiswaRingkasan>[],
          isLoading: false,
          error: null,
        );
        return;
      }

      final allowedKelasIds = scopedAssignments
          .map((item) => item.kelasId)
          .where((item) => item.trim().isNotEmpty)
          .toSet();
      final allowedTahunAjaranIds = scopedAssignments
          .map((item) => item.tahunAjaranId)
          .where((item) => item.trim().isNotEmpty)
          .toSet();

      final filtered = await _ref
          .read(nilaiServiceProvider)
          .getByWaliKelasScope(
            allowedKelasIds: allowedKelasIds,
            allowedTahunAjaranIds: allowedTahunAjaranIds,
            kelasId: kelasId,
            mapelId: mataPelajaranId,
            tahunAjaranId: tahunAjaranId,
          );
      final nilaiTugasByKey = await _loadNilaiTugasByNilaiKey(filtered);

      final siswaRows = await _ref
          .read(siswaServiceProvider)
          .getByUidsLite(filtered.map((item) => item.siswaId));
      final siswaNames = {
        for (final item in siswaRows)
          item.uid: item.nama?.trim().isNotEmpty == true
              ? item.nama!.trim()
              : item.uid,
      };

      final grouped = <String, List<RaportMapelNilai>>{};
      for (final item in filtered) {
        final nilaiTugas = nilaiTugasByKey[_nilaiKey(item)];
        grouped.putIfAbsent(item.siswaId, () => <RaportMapelNilai>[]);
        grouped[item.siswaId]!.add(
          RaportMapelNilai(
            mataPelajaranId: item.mataPelajaranId,
            nilaiTugas: nilaiTugas,
            nilaiUts: item.nilaiUts,
            nilaiUas: item.nilaiUas,
            nilaiAkhir: calculateNilaiAkhirRaport(
              nilaiTugas: nilaiTugas,
              nilaiUts: item.nilaiUts,
              nilaiUas: item.nilaiUas,
            ),
            catatan: item.catatan,
          ),
        );
      }

      final siswa =
          grouped.entries
              .map(
                (entry) => RaportSiswaRingkasan(
                  siswaId: entry.key,
                  siswaNama: siswaNames[entry.key] ?? entry.key,
                  nilai: entry.value,
                ),
              )
              .toList()
            ..sort(
              (a, b) => a.siswaNama.toLowerCase().compareTo(
                b.siswaNama.toLowerCase(),
              ),
            );

      if (!mounted) {
        return;
      }
      _loadedKey = requestKey;
      state = state.copyWith(siswa: siswa, isLoading: false, error: null);
    } catch (error) {
      if (!mounted) {
        return;
      }
      state = state.copyWith(
        isLoading: false,
        error: 'Gagal memuat raport: $error',
      );
    }
  }

  Future<Map<String, double?>> _loadNilaiTugasByNilaiKey(
    List<NilaiRecord> nilaiRows,
  ) async {
    final result = <String, double?>{};
    for (final item in nilaiRows) {
      final key = _nilaiKey(item);
      if (result.containsKey(key)) {
        continue;
      }

      final tugasRows = await _ref
          .read(tugasServiceProvider)
          .getByKelasMapelTahunAjaran(
            kelasId: item.kelasId,
            mapelId: item.mataPelajaranId,
            tahunAjaranId: item.tahunAjaranId,
          );
      if (tugasRows.isEmpty) {
        result[key] = null;
        continue;
      }

      final nilaiTugasRows = await _ref
          .read(nilaiTugasServiceProvider)
          .getByTugasIds(tugasRows.map((tugas) => tugas.id));
      result[key] = averageNilai(
        nilaiTugasRows
            .where((nilai) => nilai.siswaUid == item.siswaId)
            .map((nilai) => nilai.nilai),
      );
    }
    return result;
  }

  String _nilaiKey(NilaiRecord item) {
    return [
      item.siswaId,
      item.kelasId,
      item.mataPelajaranId,
      item.tahunAjaranId,
    ].join('|');
  }
}

final raportGuruSupabaseProvider = StateNotifierProvider.autoDispose
    .family<RaportGuruNotifier, RaportGuruState, String>((ref, guruUid) {
      return RaportGuruNotifier(ref, guruUid);
    });

const Object _raportGuruSentinel = Object();
