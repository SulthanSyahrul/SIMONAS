import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/supabase_providers.dart';

class TugasSiswaItem {
  final String id;
  final String kelasId;
  final String kelasNama;
  final String mapelId;
  final String mapelNama;
  final String judul;
  final String deskripsi;
  final DateTime? deadline;
  final double? nilai;

  const TugasSiswaItem({
    required this.id,
    required this.kelasId,
    required this.kelasNama,
    required this.mapelId,
    required this.mapelNama,
    required this.judul,
    required this.deskripsi,
    required this.deadline,
    required this.nilai,
  });
}

class TugasSiswaState {
  final List<TugasSiswaItem> data;
  final String? kelasNama;
  final bool isLoading;
  final String? error;

  const TugasSiswaState({
    required this.data,
    required this.kelasNama,
    required this.isLoading,
    required this.error,
  });

  factory TugasSiswaState.initial() {
    return const TugasSiswaState(
      data: <TugasSiswaItem>[],
      kelasNama: null,
      isLoading: false,
      error: null,
    );
  }

  TugasSiswaState copyWith({
    List<TugasSiswaItem>? data,
    Object? kelasNama = _tugasSiswaSentinel,
    bool? isLoading,
    Object? error = _tugasSiswaSentinel,
  }) {
    return TugasSiswaState(
      data: data ?? this.data,
      kelasNama: kelasNama == _tugasSiswaSentinel
          ? this.kelasNama
          : kelasNama as String?,
      isLoading: isLoading ?? this.isLoading,
      error: error == _tugasSiswaSentinel ? this.error : error as String?,
    );
  }
}

class TugasSiswaNotifier extends StateNotifier<TugasSiswaState> {
  TugasSiswaNotifier(this._ref, this._siswaUid)
    : super(TugasSiswaState.initial());

  final Ref _ref;
  final String _siswaUid;

  Future<void> getTugasBySiswa({
    required String tahunAjaranId,
    required int semester,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final membership = await _resolveMembership(tahunAjaranId);
      if (membership == null) {
        state = state.copyWith(
          data: const <TugasSiswaItem>[],
          kelasNama: null,
          isLoading: false,
          error: null,
        );
        return;
      }

      final results = await Future.wait<dynamic>([
        _ref.read(kelasServiceProvider).getById(membership.kelasId),
        _ref.read(mapelServiceProvider).getAllIncremental(),
        _ref
            .read(tugasServiceProvider)
            .getByKelasAndContext(
              kelasId: membership.kelasId,
              tahunAjaranId: tahunAjaranId,
              semester: semester,
            ),
      ]);
      final kelas = results[0] as dynamic;
      final mapelRows = results[1] as List<dynamic>;
      final tugasRows = results[2] as List<dynamic>;
      final mapelById = {for (final item in mapelRows) item.id: item.namaMapel};
      final tugasIds = tugasRows
          .where((item) => !item.isDeleted && item.kelasId == membership.kelasId)
          .map((item) => item.id.toString())
          .toList(growable: false);
      final nilaiRows = tugasIds.isEmpty
          ? const <dynamic>[]
          : await _ref
              .read(nilaiTugasServiceProvider)
              .getBySiswaAndTugasIds(
                siswaUid: _siswaUid,
                tugasIds: tugasIds,
              );
      final nilaiByTugasId = {
        for (final item in nilaiRows) item.tugasId: item.nilai,
      };

      final data =
          tugasRows
              .where(
                (item) => !item.isDeleted && item.kelasId == membership.kelasId,
              )
              .map(
                (item) => TugasSiswaItem(
                  id: item.id,
                  kelasId: item.kelasId,
                  kelasNama: kelas?.namaKelas ?? item.kelasId,
                  mapelId: item.mapelId,
                  mapelNama: mapelById[item.mapelId] ?? item.mapelId,
                  judul: item.judulTugas,
                  deskripsi: item.deskripsi,
                  deadline: item.deadline,
                  nilai: nilaiByTugasId[item.id],
                ),
              )
              .toList()
            ..sort((a, b) {
              final left = a.deadline ?? DateTime.fromMillisecondsSinceEpoch(0);
              final right =
                  b.deadline ?? DateTime.fromMillisecondsSinceEpoch(0);
              return left.compareTo(right);
            });

      state = state.copyWith(
        data: data,
        kelasNama: kelas?.namaKelas,
        isLoading: false,
        error: null,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: 'Gagal memuat tugas siswa: $error',
      );
    }
  }

  Future<void> refresh({
    required String tahunAjaranId,
    required int semester,
  }) async {
    await getTugasBySiswa(tahunAjaranId: tahunAjaranId, semester: semester);
  }

  Future<dynamic> _resolveMembership(String tahunAjaranId) async {
    final rows = await _ref
        .read(kelasSiswaServiceProvider)
        .getBySiswaUid(
          _siswaUid,
          tahunAjaranId: tahunAjaranId,
          onlyAktif: true,
        );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first;
  }
}

final tugasSiswaSupabaseProvider = StateNotifierProvider.autoDispose
    .family<TugasSiswaNotifier, TugasSiswaState, String>((ref, siswaUid) {
      return TugasSiswaNotifier(ref, siswaUid);
    });

const Object _tugasSiswaSentinel = Object();
