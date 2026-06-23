import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/supabase_providers.dart';

class HistoriPresensiItem {
  final String id;
  final String jurnalId;
  final String statusKehadiran;
  final String? catatan;
  final DateTime? tanggal;

  const HistoriPresensiItem({
    required this.id,
    required this.jurnalId,
    required this.statusKehadiran,
    required this.catatan,
    required this.tanggal,
  });
}

class HistoriPresensiSiswaState {
  final List<HistoriPresensiItem> data;
  final bool isLoading;
  final String? error;

  const HistoriPresensiSiswaState({
    required this.data,
    required this.isLoading,
    required this.error,
  });

  factory HistoriPresensiSiswaState.initial() {
    return const HistoriPresensiSiswaState(
      data: <HistoriPresensiItem>[],
      isLoading: false,
      error: null,
    );
  }

  HistoriPresensiSiswaState copyWith({
    List<HistoriPresensiItem>? data,
    bool? isLoading,
    Object? error = _historiSiswaSentinel,
  }) {
    return HistoriPresensiSiswaState(
      data: data ?? this.data,
      isLoading: isLoading ?? this.isLoading,
      error: error == _historiSiswaSentinel ? this.error : error as String?,
    );
  }
}

class HistoriPresensiSiswaNotifier
    extends StateNotifier<HistoriPresensiSiswaState> {
  HistoriPresensiSiswaNotifier(this._ref, this._siswaUid)
    : super(HistoriPresensiSiswaState.initial());

  final Ref _ref;
  final String _siswaUid;

  Future<void> getHistoriPresensi() async {
    await refresh();
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final rows = await _ref
          .read(absensiJurnalServiceProvider)
          .getBySiswaUid(_siswaUid);
      final data =
          rows
              .where((item) => !item.isDeleted)
              .map(
                (item) => HistoriPresensiItem(
                  id: item.id,
                  jurnalId: item.jurnalId,
                  statusKehadiran: item.statusKehadiran,
                  catatan: item.catatan,
                  tanggal: item.tanggal,
                ),
              )
              .toList()
            ..sort((a, b) {
              final left = a.tanggal ?? DateTime.fromMillisecondsSinceEpoch(0);
              final right = b.tanggal ?? DateTime.fromMillisecondsSinceEpoch(0);
              return right.compareTo(left);
            });

      state = state.copyWith(data: data, isLoading: false, error: null);
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: 'Gagal memuat histori presensi: $error',
      );
    }
  }
}

final historiPresensiSiswaSupabaseProvider = StateNotifierProvider.autoDispose
    .family<HistoriPresensiSiswaNotifier, HistoriPresensiSiswaState, String>((
      ref,
      siswaUid,
    ) {
      final notifier = HistoriPresensiSiswaNotifier(ref, siswaUid);
      Future.microtask(notifier.refresh);
      return notifier;
    });

const Object _historiSiswaSentinel = Object();
