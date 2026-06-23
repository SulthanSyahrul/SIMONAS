import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/supabase_providers.dart';

class JadwalSiswaItem {
  final String id;
  final String hari;
  final int jamKe;
  final int jamAkhir;
  final String mapelNama;
  final String? waktuMulai;
  final String? waktuSelesai;
  final String? ruangan;

  const JadwalSiswaItem({
    required this.id,
    required this.hari,
    required this.jamKe,
    required this.jamAkhir,
    required this.mapelNama,
    required this.waktuMulai,
    required this.waktuSelesai,
    required this.ruangan,
  });
}

class JadwalSiswaState {
  final List<JadwalSiswaItem> data;
  final String? kelasNama;
  final bool isLoading;
  final String? error;

  const JadwalSiswaState({
    required this.data,
    required this.kelasNama,
    required this.isLoading,
    required this.error,
  });

  factory JadwalSiswaState.initial() {
    return const JadwalSiswaState(
      data: <JadwalSiswaItem>[],
      kelasNama: null,
      isLoading: false,
      error: null,
    );
  }

  JadwalSiswaState copyWith({
    List<JadwalSiswaItem>? data,
    Object? kelasNama = _jadwalSiswaSentinel,
    bool? isLoading,
    Object? error = _jadwalSiswaSentinel,
  }) {
    return JadwalSiswaState(
      data: data ?? this.data,
      kelasNama: kelasNama == _jadwalSiswaSentinel
          ? this.kelasNama
          : kelasNama as String?,
      isLoading: isLoading ?? this.isLoading,
      error: error == _jadwalSiswaSentinel ? this.error : error as String?,
    );
  }
}

class JadwalSiswaNotifier extends StateNotifier<JadwalSiswaState> {
  JadwalSiswaNotifier(this._ref, this._siswaUid)
    : super(JadwalSiswaState.initial());

  final Ref _ref;
  final String _siswaUid;

  Future<void> getJadwalBySiswa({
    required String tahunAjaranId,
    required int semester,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final membership = await _resolveMembership(tahunAjaranId);
      if (membership == null) {
        state = state.copyWith(
          data: const <JadwalSiswaItem>[],
          kelasNama: null,
          isLoading: false,
          error: null,
        );
        return;
      }

      final results = await Future.wait<dynamic>([
        _ref.read(kelasServiceProvider).getById(membership.kelasId),
        _ref
            .read(jadwalServiceProvider)
            .getByTahunAjaranId(
              tahunAjaranId,
              forceFullFetch: true,
              semester: semester,
            ),
        _ref.read(mapelServiceProvider).getAllIncremental(),
      ]);
      final kelas = results[0] as dynamic;
      final jadwalRows = results[1] as List<dynamic>;
      final mapelRows = results[2] as List<dynamic>;
      final mapelById = {for (final item in mapelRows) item.id: item.namaMapel};

      final data =
          jadwalRows
              .where(
                (item) => !item.isDeleted && item.kelasId == membership.kelasId,
              )
              .map(
                (item) => JadwalSiswaItem(
                  id: item.id,
                  hari: item.hari,
                  jamKe: item.jamKe,
                  jamAkhir: item.jamAkhir,
                  mapelNama: mapelById[item.mapelId] ?? item.mapelId,
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
              return a.jamKe.compareTo(b.jamKe);
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
        error: 'Gagal memuat jadwal siswa: $error',
      );
    }
  }

  Future<void> refresh({
    required String tahunAjaranId,
    required int semester,
  }) async {
    await getJadwalBySiswa(tahunAjaranId: tahunAjaranId, semester: semester);
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

final jadwalSiswaSupabaseProvider = StateNotifierProvider.autoDispose
    .family<JadwalSiswaNotifier, JadwalSiswaState, String>((ref, siswaUid) {
      return JadwalSiswaNotifier(ref, siswaUid);
    });

const Object _jadwalSiswaSentinel = Object();
