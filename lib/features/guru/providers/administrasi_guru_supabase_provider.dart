import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/administrasi_pembelajaran_model.dart';
import '../../../providers/supabase_providers.dart';
import '../../../services/administrasi_storage_service.dart';
import '../../shared/providers/shared_academic_context_provider.dart';

class AdministrasiGuruItem {
  final String id;
  final String guruUid;
  final String tahunAjaranId;
  final String kelasId;
  final String kelasNama;
  final String mapelId;
  final String mapelNama;
  final int semester;
  final String jenis;
  final String? fileUrl;
  final String? filePath;
  final String? fileName;
  final String? statusVerifikasi;
  final String? catatanVerifikasi;
  final DateTime? createdAt;

  const AdministrasiGuruItem({
    required this.id,
    required this.guruUid,
    required this.tahunAjaranId,
    required this.kelasId,
    required this.kelasNama,
    required this.mapelId,
    required this.mapelNama,
    required this.semester,
    required this.jenis,
    required this.fileUrl,
    required this.filePath,
    required this.fileName,
    required this.statusVerifikasi,
    this.catatanVerifikasi,
    required this.createdAt,
  });
}

class AdministrasiGuruState {
  final List<AdministrasiGuruItem> data;
  final bool isLoading;
  final String? error;

  const AdministrasiGuruState({
    required this.data,
    required this.isLoading,
    required this.error,
  });

  factory AdministrasiGuruState.initial() {
    return const AdministrasiGuruState(
      data: <AdministrasiGuruItem>[],
      isLoading: false,
      error: null,
    );
  }

  AdministrasiGuruState copyWith({
    List<AdministrasiGuruItem>? data,
    bool? isLoading,
    Object? error = _administrasiGuruSentinel,
  }) {
    return AdministrasiGuruState(
      data: data ?? this.data,
      isLoading: isLoading ?? this.isLoading,
      error: error == _administrasiGuruSentinel ? this.error : error as String?,
    );
  }
}

class AdministrasiGuruNotifier extends StateNotifier<AdministrasiGuruState> {
  AdministrasiGuruNotifier(this._ref, this._guruUid)
    : super(AdministrasiGuruState.initial());

  final Ref _ref;
  final String _guruUid;
  Future<void>? _loadFuture;
  bool _hasLoaded = false;

  Future<void> getAdministrasiByGuru({
    bool forceRefreshData = false,
    bool forceRefreshCache = false,
  }) async {
    final forceRefresh = forceRefreshData || forceRefreshCache;
    if (!forceRefresh && _hasLoaded && state.error == null) {
      return;
    }
    if (!forceRefresh && _loadFuture != null) {
      return _loadFuture!;
    }

    final future = _fetchAdministrasiByGuru(
      forceRefreshData: forceRefreshData,
      forceRefreshCache: forceRefreshCache,
    );
    _loadFuture = future;
    try {
      await future;
    } finally {
      if (identical(_loadFuture, future)) {
        _loadFuture = null;
      }
    }
  }

  Future<void> _fetchAdministrasiByGuru({
    bool forceRefreshData = false,
    bool forceRefreshCache = false,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final rows = await _ref
          .read(administrasiPembelajaranServiceProvider)
          .getByGuru(_guruUid);
      final mapped = await _mapItems(
        rows,
        forceRefresh: forceRefreshData || forceRefreshCache,
      );
      if (!mounted) {
        return;
      }
      _hasLoaded = true;
      state = state.copyWith(data: mapped, isLoading: false, error: null);
    } catch (error) {
      if (!mounted) {
        return;
      }
      state = state.copyWith(
        isLoading: false,
        error: 'Gagal memuat administrasi: $error',
      );
    }
  }

  Future<AdministrasiStorageUploadResult> uploadAdministrasiFile({
    required Uint8List bytes,
    required String fileName,
    required String? localFilePath,
    String? contentType,
    void Function(double progress)? onProgress,
  }) async {
    return _ref
        .read(administrasiStorageServiceProvider)
        .uploadBytes(
          bytes: bytes,
          fileName: fileName,
          localFilePath: localFilePath,
          contentType: contentType,
          onProgress: onProgress,
        );
  }

  Future<AdministrasiStorageUploadResult> stageAdministrasiFile({
    required Uint8List bytes,
    required String fileName,
    required String? localFilePath,
  }) async {
    return _ref.read(administrasiStorageServiceProvider).stageFile(
      bytes: bytes,
      fileName: fileName,
      localFilePath: localFilePath,
    );
  }

  Future<void> createAdministrasi({
    required String jenis,
    required String kelasId,
    required String mapelId,
    required String tahunAjaranId,
    required int semester,
    required String fileUrl,
    String? filePath,
    String? fileName,
  }) async {
    await _ref.read(administrasiPembelajaranServiceProvider).create({
      'guru_uid': _guruUid,
      'kelas_id': kelasId,
      'mapel_id': mapelId,
      'tahun_ajaran_id': tahunAjaranId,
      'semester': semester,
      'tipe_dokumen': jenis,
      'judul_dokumen': fileName ?? jenis,
      'file_url': fileUrl,
      'file_path': filePath,
      'tanggal_upload': DateTime.now(),
    });
    _hasLoaded = false;

    await getAdministrasiByGuru(
      forceRefreshData: true,
      forceRefreshCache: true,
    );
  }

  Future<void> updateAdministrasi({
    required String administrasiId,
    String? jenis,
    int? semester,
    String? fileName,
    String? fileUrl,
    String? filePath,
    String? statusVerifikasi,
  }) async {
    await _ref
        .read(administrasiPembelajaranServiceProvider)
        .update(administrasiId, {
          if (jenis != null) 'tipe_dokumen': jenis,
          if (semester != null) 'semester': semester,
          if (fileName != null) 'judul_dokumen': fileName,
          if (fileUrl != null) 'file_url': fileUrl,
          if (filePath != null) 'file_path': filePath,
        });
    _hasLoaded = false;

    await getAdministrasiByGuru(
      forceRefreshData: true,
      forceRefreshCache: true,
    );
  }

  Future<void> deleteAdministrasi({required AdministrasiGuruItem item}) async {
    await _ref.read(administrasiPembelajaranServiceProvider).delete(item.id);
    _hasLoaded = false;
    await getAdministrasiByGuru(
      forceRefreshData: true,
      forceRefreshCache: true,
    );
  }

  Future<List<AdministrasiGuruItem>> _mapItems(
    List<AdministrasiPembelajaranRecord> rows, {
    bool forceRefresh = false,
  }) async {
    final cache = _ref.read(appMasterCacheProvider);
    final kelasFuture = cache.getKelas(
      _ref.read,
      forceRefresh: forceRefresh,
    );
    final mapelFuture = cache.getMapel(
      _ref.read,
      forceRefresh: forceRefresh,
    );
    final kelasRows = await kelasFuture;
    final mapelRows = await mapelFuture;
    final kelasById = {for (final item in kelasRows) item.id: item.namaKelas};
    final mapelById = {for (final item in mapelRows) item.id: item.namaMapel};

    final items =
        rows
            .map(
              (item) => AdministrasiGuruItem(
                id: item.id,
                guruUid: item.guruUid,
                tahunAjaranId: item.tahunAjaranId,
                kelasId: item.kelasId,
                kelasNama: kelasById[item.kelasId] ?? item.kelasId,
                mapelId: item.mapelId,
                mapelNama: mapelById[item.mapelId] ?? item.mapelId,
                semester: item.semester,
                jenis: item.jenis,
                fileUrl: item.fileUrl,
                filePath: item.filePath,
                fileName: item.fileName ?? item.judulDokumen,
                statusVerifikasi: item.statusVerifikasi ?? 'pending',
                catatanVerifikasi: item.catatanVerifikasi,
                createdAt: item.tanggalUpload ?? item.createdAt,
              ),
            )
            .toList()
          ..sort((a, b) {
            final left = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final right = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return right.compareTo(left);
          });
    return items;
  }
}

final administrasiGuruSupabaseProvider = StateNotifierProvider.autoDispose
    .family<AdministrasiGuruNotifier, AdministrasiGuruState, String>((
      ref,
      guruUid,
    ) {
      return AdministrasiGuruNotifier(ref, guruUid);
    });

const Object _administrasiGuruSentinel = Object();
