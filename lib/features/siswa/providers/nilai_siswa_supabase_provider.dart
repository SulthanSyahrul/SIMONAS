import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/supabase_providers.dart';
import '../../shared/providers/shared_academic_context_provider.dart';

class NilaiSiswaItem {
  final String id;
  final String mapelId;
  final String mapelNama;
  final String kelasNama;
  final double? nilaiUts;
  final double? nilaiUas;
  final String? catatan;

  const NilaiSiswaItem({
    required this.id,
    required this.mapelId,
    required this.mapelNama,
    required this.kelasNama,
    required this.nilaiUts,
    required this.nilaiUas,
    required this.catatan,
  });
}

class NilaiSiswaSupabaseState {
  final List<NilaiSiswaItem> data;
  final bool isLoading;
  final String? error;

  const NilaiSiswaSupabaseState({
    required this.data,
    required this.isLoading,
    required this.error,
  });

  factory NilaiSiswaSupabaseState.initial() {
    return const NilaiSiswaSupabaseState(
      data: <NilaiSiswaItem>[],
      isLoading: false,
      error: null,
    );
  }

  NilaiSiswaSupabaseState copyWith({
    List<NilaiSiswaItem>? data,
    bool? isLoading,
    Object? error = _nilaiSiswaSentinel,
  }) {
    return NilaiSiswaSupabaseState(
      data: data ?? this.data,
      isLoading: isLoading ?? this.isLoading,
      error: error == _nilaiSiswaSentinel ? this.error : error as String?,
    );
  }
}

class NilaiSiswaNotifier extends StateNotifier<NilaiSiswaSupabaseState> {
  NilaiSiswaNotifier(this._ref, this._siswaUid)
    : super(NilaiSiswaSupabaseState.initial());

  final Ref _ref;
  final String _siswaUid;

  Future<void> getNilaiBySiswa({
    required String tahunAjaranId,
    required int semester,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final cache = _ref.read(appMasterCacheProvider);
      final results = await Future.wait<dynamic>([
        _ref
            .read(nilaiServiceProvider)
            .getNilaiBySiswaDanTahunAjaran(_siswaUid, tahunAjaranId),
        cache.getMapel(_ref.read),
        cache.getKelas(_ref.read),
      ]);
      final rows = (results[0] as List<dynamic>)
          .where((item) => !item.isDeleted && item.semester == semester)
          .toList(growable: false);
      final mapelRows = results[1] as List<dynamic>;
      final kelasRows = results[2] as List<dynamic>;
      final mapelById = {for (final item in mapelRows) item.id: item.namaMapel};
      final kelasById = {for (final item in kelasRows) item.id: item.namaKelas};

      final data =
          rows.map((item) {
            return NilaiSiswaItem(
              id: item.id,
              mapelId: item.mataPelajaranId,
              mapelNama:
                  mapelById[item.mataPelajaranId] ?? item.mataPelajaranId,
              kelasNama: kelasById[item.kelasId] ?? item.kelasId,
              nilaiUts: item.nilaiUts,
              nilaiUas: item.nilaiUas,
              catatan: item.catatan,
            );
          }).toList()..sort(
            (a, b) =>
                a.mapelNama.toLowerCase().compareTo(b.mapelNama.toLowerCase()),
          );

      state = state.copyWith(data: data, isLoading: false, error: null);
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: 'Gagal memuat nilai siswa: $error',
      );
    }
  }

  Future<void> refresh({
    required String tahunAjaranId,
    required int semester,
  }) async {
    await getNilaiBySiswa(tahunAjaranId: tahunAjaranId, semester: semester);
  }
}

final nilaiSiswaSupabaseProvider = StateNotifierProvider.autoDispose
    .family<NilaiSiswaNotifier, NilaiSiswaSupabaseState, String>((
      ref,
      siswaUid,
    ) {
      return NilaiSiswaNotifier(ref, siswaUid);
    });

const Object _nilaiSiswaSentinel = Object();
