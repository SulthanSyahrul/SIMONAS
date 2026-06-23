import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/monitoring_kelas_model.dart';
import '../../../providers/supabase_providers.dart';

class MonitoringKelasState {
  final List<MonitoringKelasModel> monitoringList;
  final List<int> jamOptions;
  final DateTime selectedDate;
  final int selectedJamKe;
  final bool isLoading;
  final String? error;

  const MonitoringKelasState({
    required this.monitoringList,
    required this.jamOptions,
    required this.selectedDate,
    required this.selectedJamKe,
    required this.isLoading,
    this.error,
  });

  factory MonitoringKelasState.initial() {
    final now = DateTime.now();
    final dateOnly = DateTime(now.year, now.month, now.day);
    return MonitoringKelasState(
      monitoringList: const [],
      jamOptions: const [1, 2, 3, 4, 5, 6, 7, 8],
      selectedDate: dateOnly,
      selectedJamKe: 1,
      isLoading: false,
    );
  }

  MonitoringKelasState copyWith({
    List<MonitoringKelasModel>? monitoringList,
    List<int>? jamOptions,
    DateTime? selectedDate,
    int? selectedJamKe,
    bool? isLoading,
    String? error,
  }) {
    return MonitoringKelasState(
      monitoringList: monitoringList ?? this.monitoringList,
      jamOptions: jamOptions ?? this.jamOptions,
      selectedDate: selectedDate ?? this.selectedDate,
      selectedJamKe: selectedJamKe ?? this.selectedJamKe,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class MonitoringKelasNotifier extends StateNotifier<MonitoringKelasState> {
  final Ref _ref;

  MonitoringKelasNotifier(this._ref) : super(MonitoringKelasState.initial());

  Future<void> loadData({bool forceRefreshData = false}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final selectedDate = _normalizeDate(state.selectedDate);

      final kelasRecords = await _ref
          .read(kelasServiceProvider)
          .getAllIncremental(forceFullFetch: forceRefreshData);
      final jurnalRecords = await _ref
          .read(jurnalServiceProvider)
          .getJurnalByTanggalLite(selectedDate);

      final kelasSorted = [...kelasRecords]
        ..sort((a, b) => a.namaKelas.compareTo(b.namaKelas));

      final result = <MonitoringKelasModel>[];

      for (final kelas in kelasSorted) {
        final kelasJurnal = jurnalRecords
            .where(
              (jurnal) =>
                  jurnal.kelasId == kelas.id &&
                  _isSameDay(jurnal.tanggal, selectedDate) &&
                  jurnal.includesJamKe(state.selectedJamKe),
            )
            .toList()
          ..sort((a, b) {
            final aTime = a.updatedAt ?? a.tanggal ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bTime = b.updatedAt ?? b.tanggal ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bTime.compareTo(aTime);
          });

        if (kelasJurnal.isEmpty) {
          result.add(
            MonitoringKelasModel(
              kelasId: kelas.id,
              kelasNama: kelas.namaKelas,
              lantai: kelas.lantai,
              status: StatusMonitoring.belumIsi,
              tanggal: selectedDate,
              jamKe: state.selectedJamKe,
            ),
          );
          continue;
        }

        final latest = kelasJurnal.first;
        final status = _mapStatus(latest.statusKehadiran);

        result.add(
          MonitoringKelasModel(
            kelasId: kelas.id,
            kelasNama: kelas.namaKelas,
            lantai: kelas.lantai,
            status: status,
            guruUid: latest.userId,
            mataPelajaranId: latest.mataPelajaranId,
            tanggal: selectedDate,
            jamKe: latest.jamKe,
          ),
        );
      }

      state = state.copyWith(
        monitoringList: result,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Gagal memuat monitoring kelas: $e',
      );
    }
  }

  Future<void> setDate(DateTime date) async {
    state = state.copyWith(selectedDate: _normalizeDate(date));
    await loadData();
  }

  Future<void> setJamKe(int jamKe) async {
    state = state.copyWith(selectedJamKe: jamKe);
    await loadData();
  }

  Future<void> refresh() async {
    await loadData(forceRefreshData: true);
  }

  StatusMonitoring _mapStatus(String statusKehadiran) {
    final status = statusKehadiran.trim().toLowerCase();
    if (status == 'izin') {
      return StatusMonitoring.izin;
    }
    if (status == 'masuk' || status == 'hadir') {
      return StatusMonitoring.masuk;
    }
    return StatusMonitoring.belumIsi;
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  bool _isSameDay(DateTime? value, DateTime target) {
    if (value == null) {
      return false;
    }
    return value.year == target.year &&
        value.month == target.month &&
        value.day == target.day;
  }
}

final monitoringKelasProvider = StateNotifierProvider.autoDispose<
  MonitoringKelasNotifier,
  MonitoringKelasState
>((ref) {
  final notifier = MonitoringKelasNotifier(ref);
  Future.microtask(notifier.loadData);
  return notifier;
});
