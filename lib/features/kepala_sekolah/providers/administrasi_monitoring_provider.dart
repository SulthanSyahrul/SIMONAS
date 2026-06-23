import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/administrasi_pembelajaran_model.dart';
import '../../../providers/supabase_providers.dart';

String _normalizeStatusVerifikasi(String? rawStatus) {
  final value = (rawStatus ?? '').trim().toLowerCase();
  switch (value) {
    case 'pending':
    case 'menunggu':
      return 'menunggu';
    case 'approved':
    case 'disetujui':
      return 'disetujui';
    case 'rejected':
    case 'revisi':
      return 'revisi';
    default:
      return 'menunggu';
  }
}

class TahunAjaranFilterOption {
  final String id;
  final String name;

  const TahunAjaranFilterOption({required this.id, required this.name});
}

class AdministrasiMonitoringItem {
  final String id;
  final String jenis;
  final String guruUid;
  final String guruName;
  final String kelasId;
  final String kelasName;
  final String mapelId;
  final String mapelName;
  final String tahunAjaranId;
  final String tahunAjaranName;
  final int semester;
  final String? fileName;
  final String? fileUrl;
  final String? filePath;
  final String statusVerifikasi;
  final String? catatanVerifikasi;
  final DateTime? updatedAt;

  const AdministrasiMonitoringItem({
    required this.id,
    required this.jenis,
    required this.guruUid,
    required this.guruName,
    required this.kelasId,
    required this.kelasName,
    required this.mapelId,
    required this.mapelName,
    required this.tahunAjaranId,
    required this.tahunAjaranName,
    required this.semester,
    this.fileName,
    this.fileUrl,
    this.filePath,
    required this.statusVerifikasi,
    this.catatanVerifikasi,
    this.updatedAt,
  });

  bool get sudahUpload {
    final hasFileName = fileName != null && fileName!.trim().isNotEmpty;
    final hasFileUrl = fileUrl != null && fileUrl!.trim().isNotEmpty;
    final hasFilePath = filePath != null && filePath!.trim().isNotEmpty;
    return hasFileName || hasFileUrl || hasFilePath;
  }
}

class AdministrasiMonitoringState {
  final String jenis;
  final List<AdministrasiMonitoringItem> data;
  final List<TahunAjaranFilterOption> tahunAjaranOptions;
  final String? selectedTahunAjaranId;
  final int? selectedSemester;
  final String selectedStatusVerifikasi;
  final bool isLoading;
  final String? error;

  const AdministrasiMonitoringState({
    required this.jenis,
    required this.data,
    required this.tahunAjaranOptions,
    required this.selectedTahunAjaranId,
    required this.selectedSemester,
    required this.selectedStatusVerifikasi,
    required this.isLoading,
    this.error,
  });

  factory AdministrasiMonitoringState.initial(String jenis) {
    return AdministrasiMonitoringState(
      jenis: jenis,
      data: const [],
      tahunAjaranOptions: const [],
      selectedTahunAjaranId: null,
      selectedSemester: null,
      selectedStatusVerifikasi: 'all',
      isLoading: false,
    );
  }

  AdministrasiMonitoringState copyWith({
    String? jenis,
    List<AdministrasiMonitoringItem>? data,
    List<TahunAjaranFilterOption>? tahunAjaranOptions,
    String? selectedTahunAjaranId,
    int? selectedSemester,
    String? selectedStatusVerifikasi,
    bool? isLoading,
    String? error,
    bool forceNullSemester = false,
  }) {
    return AdministrasiMonitoringState(
      jenis: jenis ?? this.jenis,
      data: data ?? this.data,
      tahunAjaranOptions: tahunAjaranOptions ?? this.tahunAjaranOptions,
      selectedTahunAjaranId:
          selectedTahunAjaranId ?? this.selectedTahunAjaranId,
      selectedSemester: forceNullSemester
          ? null
          : (selectedSemester ?? this.selectedSemester),
      selectedStatusVerifikasi:
          selectedStatusVerifikasi ?? this.selectedStatusVerifikasi,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AdministrasiMonitoringNotifier
    extends StateNotifier<AdministrasiMonitoringState> {
  final Ref _ref;
  List<AdministrasiPembelajaranRecord> _allRecords = const [];

  AdministrasiMonitoringNotifier(this._ref, {required String jenis})
    : super(AdministrasiMonitoringState.initial(jenis));

  Future<void> loadData({bool forceRefreshData = false}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final allRecords = await _ref
          .read(administrasiPembelajaranServiceProvider)
          .getMonitoringByJenis(state.jenis);

      _allRecords = allRecords;

      final tahunAjaranMap = <String, TahunAjaranFilterOption>{};
      String? activeTahunAjaranId;
      for (final record in _allRecords) {
        final tahunAjaranId = record.tahunAjaranId.trim();
        if (tahunAjaranId.isEmpty) {
          continue;
        }
        tahunAjaranMap[tahunAjaranId] = TahunAjaranFilterOption(
          id: tahunAjaranId,
          name: record.tahunAjaranName?.trim().isNotEmpty == true
              ? record.tahunAjaranName!.trim()
              : tahunAjaranId,
        );
        if (record.tahunAjaranAktif && activeTahunAjaranId == null) {
          activeTahunAjaranId = tahunAjaranId;
        }
      }

      final tahunAjaranOptions = tahunAjaranMap.values.toList()
        ..sort((a, b) => b.name.compareTo(a.name));

      String? selectedTahunAjaranId = state.selectedTahunAjaranId;
      if (tahunAjaranOptions.isNotEmpty &&
          !tahunAjaranOptions.any((item) => item.id == selectedTahunAjaranId)) {
        selectedTahunAjaranId =
            activeTahunAjaranId ?? tahunAjaranOptions.first.id;
      }

      state = state.copyWith(
        tahunAjaranOptions: tahunAjaranOptions,
        selectedTahunAjaranId: selectedTahunAjaranId,
        isLoading: false,
      );
      _applyFilters();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Gagal memuat monitoring administrasi: $e',
      );
    }
  }

  Future<void> setTahunAjaranId(String? tahunAjaranId) async {
    state = state.copyWith(selectedTahunAjaranId: tahunAjaranId);
    _applyFilters();
  }

  Future<void> setSemester(int? semester) async {
    state = state.copyWith(
      selectedSemester: semester,
      forceNullSemester: semester == null,
    );
    _applyFilters();
  }

  Future<void> setStatusVerifikasi(String status) async {
    final normalized = status.trim().toLowerCase() == 'all'
        ? 'all'
        : _normalizeStatusVerifikasi(status);
    state = state.copyWith(selectedStatusVerifikasi: normalized);
    _applyFilters();
  }

  Future<void> updateVerifikasi({
    required String administrasiId,
    required String statusVerifikasi,
    String? catatanVerifikasi,
  }) async {
    try {
      final updatedRecord = await _ref
          .read(administrasiPembelajaranServiceProvider)
          .update(administrasiId, {
            'status_verifikasi': _normalizeStatusVerifikasi(statusVerifikasi),
            'catatan_verifikasi': catatanVerifikasi,
          });
      _allRecords = _allRecords.map((item) {
        if (item.id != administrasiId) {
          return item;
        }
        return updatedRecord.copyWith(
          guruName: item.guruName,
          kelasName: item.kelasName,
          mapelName: item.mapelName,
          tahunAjaranName: item.tahunAjaranName,
          tahunAjaranAktif: item.tahunAjaranAktif,
        );
      }).toList(growable: false);
      state = state.copyWith(error: null);
      _applyFilters();
    } catch (e) {
      state = state.copyWith(error: 'Gagal memperbarui verifikasi: $e');
    }
  }

  Future<void> refresh() async {
    await loadData(forceRefreshData: true);
  }

  void _applyFilters() {
    final filtered = _allRecords.where((record) {
      if (record.jenis != state.jenis) {
        return false;
      }
      if (state.selectedTahunAjaranId != null &&
          record.tahunAjaranId != state.selectedTahunAjaranId) {
        return false;
      }
      if (state.selectedSemester != null &&
          record.semester != state.selectedSemester) {
        return false;
      }
      if (state.selectedStatusVerifikasi != 'all') {
        final currentStatus = _normalizeStatusVerifikasi(record.statusVerifikasi);
        final selectedStatus = _normalizeStatusVerifikasi(
          state.selectedStatusVerifikasi,
        );
        if (currentStatus != selectedStatus) {
          return false;
        }
      }
      return true;
    }).toList()
      ..sort((a, b) {
        final aTime = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

    state = state.copyWith(
      data: filtered
          .map(
            (record) => AdministrasiMonitoringItem(
              id: record.id,
              jenis: record.jenis,
              guruUid: record.guruUid,
              guruName: record.guruName ?? record.guruUid,
              kelasId: record.kelasId,
              kelasName: record.kelasName ?? record.kelasId,
              mapelId: record.mapelId,
              mapelName: record.mapelName ?? record.mapelId,
              tahunAjaranId: record.tahunAjaranId,
              tahunAjaranName:
                  record.tahunAjaranName ?? record.tahunAjaranId,
              semester: record.semester,
              fileName: record.fileName ?? record.judulDokumen,
              fileUrl: record.fileUrl,
              filePath: record.filePath,
              statusVerifikasi: _normalizeStatusVerifikasi(
                record.statusVerifikasi,
              ),
              catatanVerifikasi: record.catatanVerifikasi,
              updatedAt: record.updatedAt,
            ),
          )
          .toList(growable: false),
      isLoading: false,
    );
  }
}

final administrasiMonitoringProvider = StateNotifierProvider
    .family<
      AdministrasiMonitoringNotifier,
      AdministrasiMonitoringState,
      String
    >((ref, jenis) {
      return AdministrasiMonitoringNotifier(ref, jenis: jenis);
    });
