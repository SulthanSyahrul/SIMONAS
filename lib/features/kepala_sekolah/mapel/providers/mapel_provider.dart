import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../models/mapel_model.dart';
import '../../../../providers/supabase_providers.dart';
import '../../../../services/mapel_service.dart';

class MapelState {
  final List<MapelRecord> data;
  final bool isLoading;
  final String? error;

  const MapelState({required this.data, required this.isLoading, this.error});

  factory MapelState.initial() {
    return const MapelState(data: <MapelRecord>[], isLoading: false);
  }

  MapelState copyWith({
    List<MapelRecord>? data,
    bool? isLoading,
    String? error,
  }) {
    return MapelState(
      data: data ?? this.data,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class MapelNotifier extends StateNotifier<MapelState> {
  final MapelService _service;

  MapelNotifier(this._service) : super(MapelState.initial());

  Future<void> loadMapel({bool forceRefreshData = false}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final rows = await _fetchSortedMapel(forceRefreshData: forceRefreshData);
      state = state.copyWith(data: rows, isLoading: false, error: null);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Gagal memuat mata pelajaran: $e',
      );
    }
  }

  Future<void> addMapel(String namaMapel) async {
    final normalized = namaMapel.trim();
    if (normalized.isEmpty) {
      throw Exception('Nama mata pelajaran tidak boleh kosong.');
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      await _service.create(<String, dynamic>{'nama_mapel': normalized});
      final rows = await _fetchSortedMapel(forceRefreshData: true);
      state = state.copyWith(data: rows, isLoading: false, error: null);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Gagal menambah mata pelajaran: $e',
      );
      rethrow;
    }
  }

  Future<void> updateMapel({
    required String id,
    required String namaMapel,
  }) async {
    final normalized = namaMapel.trim();
    if (normalized.isEmpty) {
      throw Exception('Nama mata pelajaran tidak boleh kosong.');
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      await _service.update(id, <String, dynamic>{'nama_mapel': normalized});
      final rows = await _fetchSortedMapel(forceRefreshData: true);
      state = state.copyWith(data: rows, isLoading: false, error: null);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Gagal mengubah mata pelajaran: $e',
      );
      rethrow;
    }
  }

  Future<void> deleteMapel(String id) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _service.delete(id);
      final rows = await _fetchSortedMapel(forceRefreshData: true);
      state = state.copyWith(data: rows, isLoading: false, error: null);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Gagal menghapus mata pelajaran: $e',
      );
      rethrow;
    }
  }

  Future<List<MapelRecord>> _fetchSortedMapel({
    bool forceRefreshData = false,
  }) async {
    final rows = await _service.getAllIncremental(
      forceFullFetch: forceRefreshData,
    );
    final sorted = <MapelRecord>[...rows]
      ..sort(
        (a, b) =>
            a.namaMapel.toLowerCase().compareTo(b.namaMapel.toLowerCase()),
      );
    return sorted;
  }
}

final mapelProvider = StateNotifierProvider<MapelNotifier, MapelState>((ref) {
  final service = ref.read(mapelServiceProvider);
  return MapelNotifier(service);
});
