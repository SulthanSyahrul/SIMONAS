import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/tahun_ajaran_model.dart';
import '../services/auth_service.dart';
import '../services/absensi_service.dart';
import '../services/administrasi_pembelajaran_service.dart';
import '../services/guru_service.dart';
import '../services/histori_wali_kelas_service.dart';
import '../services/jadwal_service.dart';
import '../services/jurnal_service.dart';
import '../services/kepala_sekolah_service.dart';
import '../services/kelas_service.dart';
import '../services/kelas_siswa_service.dart';
import '../services/mapel_service.dart';
import '../services/nilai_tugas_service.dart';
import '../services/nilai_ujian_service.dart';
import '../services/semester_service.dart';
import '../services/tahun_ajaran_service.dart';
import '../services/tugas_service.dart';
import '../services/siswa_service.dart';
import '../services/user_role_service.dart';
import '../services/user_service.dart';

final kepalaSekolahSupabaseServiceProvider = Provider<KepalaSekolahService>(
  (ref) => KepalaSekolahService(),
);

final tahunAjaranServiceProvider = Provider<TahunAjaranService>(
  (ref) => ref.read(kepalaSekolahSupabaseServiceProvider).tahunAjaranService,
);

final semesterServiceProvider = Provider<SemesterService>(
  (ref) => ref.read(kepalaSekolahSupabaseServiceProvider).semesterService,
);

final kelasServiceProvider = Provider<KelasService>(
  (ref) => ref.read(kepalaSekolahSupabaseServiceProvider).kelasService,
);

final mapelServiceProvider = Provider<MapelService>(
  (ref) => ref.read(kepalaSekolahSupabaseServiceProvider).mapelService,
);

final guruServiceProvider = Provider<GuruService>(
  (ref) => ref.read(kepalaSekolahSupabaseServiceProvider).guruService,
);

final jadwalServiceProvider = Provider<JadwalService>(
  (ref) => ref.read(kepalaSekolahSupabaseServiceProvider).jadwalService,
);

final jurnalServiceProvider = Provider<JurnalService>(
  (ref) => ref.read(kepalaSekolahSupabaseServiceProvider).jurnalService,
);

final absensiJurnalServiceProvider = Provider<AbsensiService>(
  (ref) => ref.read(kepalaSekolahSupabaseServiceProvider).absensiJurnalService,
);

final nilaiServiceProvider = Provider<NilaiUjianService>(
  (ref) => ref.read(kepalaSekolahSupabaseServiceProvider).nilaiService,
);

final nilaiTugasServiceProvider = Provider<NilaiTugasService>(
  (ref) => ref.read(kepalaSekolahSupabaseServiceProvider).nilaiTugasService,
);

final tugasServiceProvider = Provider<TugasService>(
  (ref) => ref.read(kepalaSekolahSupabaseServiceProvider).tugasService,
);

final kelasSiswaServiceProvider = Provider<KelasSiswaService>(
  (ref) => ref.read(kepalaSekolahSupabaseServiceProvider).kelasSiswaService,
);

final administrasiPembelajaranServiceProvider =
    Provider<AdministrasiPembelajaranService>(
      (ref) => ref
          .read(kepalaSekolahSupabaseServiceProvider)
          .administrasiPembelajaranService,
    );

final historiWaliKelasServiceProvider = Provider<HistoriWaliKelasService>(
  (ref) =>
      ref.read(kepalaSekolahSupabaseServiceProvider).historiWaliKelasService,
);

final userServiceProvider = Provider<UserService>((ref) => UserService());

final userRoleServiceProvider = Provider<UserRoleService>(
  (ref) => UserRoleService(),
);

final siswaServiceProvider = Provider<SiswaService>((ref) => SiswaService());

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(
    userService: ref.read(userServiceProvider),
    roleService: ref.read(userRoleServiceProvider),
    siswaService: ref.read(siswaServiceProvider),
    guruService: ref.read(guruServiceProvider),
  ),
);

class TahunAjaranGuruState {
  final List<TahunAjaranRecord> options;
  final String? selectedTahunAjaranId;
  final bool isLoading;
  final String? error;
  final bool lockSelection;

  const TahunAjaranGuruState({
    required this.options,
    required this.selectedTahunAjaranId,
    required this.isLoading,
    required this.error,
    required this.lockSelection,
  });

  factory TahunAjaranGuruState.initial() {
    return const TahunAjaranGuruState(
      options: <TahunAjaranRecord>[],
      selectedTahunAjaranId: null,
      isLoading: false,
      error: null,
      lockSelection: false,
    );
  }

  TahunAjaranRecord? get selectedOption {
    final selectedId = selectedTahunAjaranId;
    if (selectedId == null) {
      return options.isEmpty ? null : options.first;
    }

    for (final item in options) {
      if (item.id == selectedId) {
        return item;
      }
    }
    return options.isEmpty ? null : options.first;
  }

  TahunAjaranGuruState copyWith({
    List<TahunAjaranRecord>? options,
    Object? selectedTahunAjaranId = _tahunAjaranProviderSentinel,
    bool? isLoading,
    Object? error = _tahunAjaranProviderSentinel,
    bool? lockSelection,
  }) {
    return TahunAjaranGuruState(
      options: options ?? this.options,
      selectedTahunAjaranId:
          selectedTahunAjaranId == _tahunAjaranProviderSentinel
          ? this.selectedTahunAjaranId
          : selectedTahunAjaranId as String?,
      isLoading: isLoading ?? this.isLoading,
      error: error == _tahunAjaranProviderSentinel
          ? this.error
          : error as String?,
      lockSelection: lockSelection ?? this.lockSelection,
    );
  }
}

class TahunAjaranGuruNotifier extends StateNotifier<TahunAjaranGuruState> {
  TahunAjaranGuruNotifier(this._ref) : super(TahunAjaranGuruState.initial());

  final Ref _ref;
  Future<void>? _loadingFuture;

  Future<void> loadTahunAjaran({bool forceRefreshData = false}) async {
    if (!forceRefreshData && state.options.isNotEmpty && !state.isLoading) {
      return;
    }
    if (!forceRefreshData && _loadingFuture != null) {
      return _loadingFuture;
    }

    final future = _loadTahunAjaran(forceRefreshData: forceRefreshData);
    _loadingFuture = future;
    try {
      await future;
    } finally {
      if (identical(_loadingFuture, future)) {
        _loadingFuture = null;
      }
    }
  }

  Future<void> _loadTahunAjaran({required bool forceRefreshData}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final rows = await _ref
          .read(tahunAjaranServiceProvider)
          .getAllIncremental(forceFullFetch: forceRefreshData);
      final sorted = [...rows]
        ..sort((a, b) => a.nama.toLowerCase().compareTo(b.nama.toLowerCase()));
      TahunAjaranRecord? active;
      for (final item in sorted) {
        if (item.aktif) {
          active = item;
          break;
        }
      }

      final selectedId = _resolveSelectedId(
        options: sorted,
        previousSelectedId: state.selectedTahunAjaranId,
        fallbackSelectedId: active?.id,
      );

      state = state.copyWith(
        options: sorted,
        selectedTahunAjaranId: selectedId,
        isLoading: false,
        error: null,
        lockSelection: sorted.length <= 1,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: 'Gagal memuat tahun ajaran: $error',
      );
    }
  }

  void setSelectedTahunAjaran(String? id) {
    state = state.copyWith(selectedTahunAjaranId: id, error: null);
  }

  String? _resolveSelectedId({
    required List<TahunAjaranRecord> options,
    required String? previousSelectedId,
    required String? fallbackSelectedId,
  }) {
    if (previousSelectedId != null &&
        options.any((item) => item.id == previousSelectedId)) {
      return previousSelectedId;
    }
    if (fallbackSelectedId != null &&
        options.any((item) => item.id == fallbackSelectedId)) {
      return fallbackSelectedId;
    }
    return options.isEmpty ? null : options.first.id;
  }
}

final tahunAjaranProvider =
    StateNotifierProvider<TahunAjaranGuruNotifier, TahunAjaranGuruState>((ref) {
      final notifier = TahunAjaranGuruNotifier(ref);
      Future.microtask(notifier.loadTahunAjaran);
      return notifier;
    });

const Object _tahunAjaranProviderSentinel = Object();
