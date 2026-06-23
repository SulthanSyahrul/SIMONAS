import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/semester_model.dart';
import '../../../models/tahun_ajaran_model.dart';
import '../../../providers/supabase_providers.dart';
import '../../../services/semester_service.dart';
import '../../../services/tahun_ajaran_service.dart';

class TahunAjaranManagementState {
  final List<TahunAjaranRecord> items;
  final bool isLoading;
  final String? error;

  const TahunAjaranManagementState({
    required this.items,
    required this.isLoading,
    this.error,
  });

  factory TahunAjaranManagementState.initial() {
    return const TahunAjaranManagementState(
      items: <TahunAjaranRecord>[],
      isLoading: false,
    );
  }

  List<TahunAjaranRecord> get history {
    return items.where((item) => !item.aktif).toList(growable: false);
  }

  TahunAjaranManagementState copyWith({
    List<TahunAjaranRecord>? items,
    bool? isLoading,
    String? error,
  }) {
    return TahunAjaranManagementState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class TahunAjaranManagementNotifier
    extends StateNotifier<TahunAjaranManagementState> {
  final TahunAjaranService _service;

  TahunAjaranManagementNotifier(this._service)
    : super(TahunAjaranManagementState.initial());

  Future<void> loadTahunAjaran() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final rows = await _service.getAllIncremental(forceFullFetch: true);
      rows.sort((a, b) => _sortByNamaTahunAsc(a, b));
      state = state.copyWith(items: rows, isLoading: false, error: null);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Gagal memuat tahun ajaran: $e',
      );
    }
  }

  Future<void> addTahunAjaran({
    required String nama,
    required int semesterAktif,
    required bool aktif,
  }) async {
    _validateInput(nama: nama, semesterAktif: semesterAktif);
    state = state.copyWith(isLoading: true, error: null);

    try {
      final currentRows = await _service.getAllIncremental(
        forceFullFetch: true,
      );
      final normalizedNama = nama.trim();
      final hasDuplicate = currentRows.any(
        (item) => item.nama.toLowerCase() == normalizedNama.toLowerCase(),
      );
      if (hasDuplicate) {
        throw Exception('Nama tahun ajaran sudah digunakan.');
      }

      final mustBeActive =
          aktif ||
          currentRows.isEmpty ||
          !currentRows.any((item) => item.aktif);

      await _service.create(<String, dynamic>{
        'nama': normalizedNama,
        'aktif': mustBeActive,
      });

      final created = (await _service.getAllIncremental(forceFullFetch: true))
          .where((item) => item.nama.toLowerCase() == normalizedNama.toLowerCase())
          .toList(growable: false);
      if (created.isEmpty) {
        throw Exception('Data tahun ajaran baru tidak ditemukan setelah disimpan.');
      }

      await _createDefaultSemesters(
        tahunAjaranId: created.first.id,
        semesterAktif: semesterAktif,
      );

      await _syncSemesterAktifState(
        activeTahunAjaranId: mustBeActive ? created.first.id : null,
        activeSemesterKe: mustBeActive ? semesterAktif : null,
        allTahunAjaranIds: [
          ...currentRows.map((item) => item.id),
          created.first.id,
        ],
      );

      if (mustBeActive) {
        await _setOnlyOneActive(created.first.id);
      }

      await _reloadState();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Gagal menambah tahun ajaran: $e',
      );
      rethrow;
    }
  }

  Future<void> updateTahunAjaran({
    required String id,
    required String nama,
    required int semesterAktif,
    required bool aktif,
  }) async {
    _validateInput(nama: nama, semesterAktif: semesterAktif);
    state = state.copyWith(isLoading: true, error: null);

    try {
      final currentRows = await _service.getAllIncremental(
        forceFullFetch: true,
      );
      final target = currentRows.where((item) => item.id == id).toList();
      if (target.isEmpty) {
        throw Exception('Data tahun ajaran tidak ditemukan.');
      }

      final normalizedNama = nama.trim();
      final hasDuplicate = currentRows.any(
        (item) =>
            item.id != id &&
            item.nama.toLowerCase() == normalizedNama.toLowerCase(),
      );
      if (hasDuplicate) {
        throw Exception('Nama tahun ajaran sudah digunakan.');
      }

      final activeCount = currentRows.where((item) => item.aktif).length;
      final previous = target.first;
      if (!aktif && previous.aktif && activeCount <= 1) {
        throw Exception('Harus ada tepat satu tahun ajaran aktif.');
      }

      await _service.update(id, <String, dynamic>{
        'nama': normalizedNama,
        'aktif': aktif,
      });

      await _syncSemesterAktifState(
        activeTahunAjaranId: aktif ? id : null,
        activeSemesterKe: aktif ? semesterAktif : null,
        allTahunAjaranIds: [
          ...currentRows.map((item) => item.id),
          id,
        ],
      );

      if (aktif) {
        await _setOnlyOneActive(id);
      } else {
        await _repairActiveInvariant();
      }

      await _reloadState();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Gagal mengubah tahun ajaran: $e',
      );
      rethrow;
    }
  }

  Future<void> deleteTahunAjaran(String id) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final currentRows = await _service.getAllIncremental(
        forceFullFetch: true,
      );
      final target = currentRows.where((item) => item.id == id).toList();
      if (target.isEmpty) {
        throw Exception('Data tahun ajaran tidak ditemukan.');
      }

      if (currentRows.length <= 1) {
        throw Exception('Minimal harus ada satu data tahun ajaran.');
      }

      final deleted = target.first;
      await _service.delete(id);

      final remaining = currentRows.where((item) => item.id != id).toList();
      if (deleted.aktif && remaining.isNotEmpty) {
        final replacement = _pickMostRecent(remaining);
        await _setOnlyOneActive(replacement.id);
      } else {
        await _repairActiveInvariant();
      }

      await _reloadState();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Gagal menghapus tahun ajaran: $e',
      );
      rethrow;
    }
  }

  Future<void> setActiveTahunAjaran(String id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _setOnlyOneActive(id);
      await _reloadState();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Gagal mengaktifkan tahun ajaran: $e',
      );
      rethrow;
    }
  }

  Future<void> _reloadState() async {
    final rows = await _service.getAllIncremental(forceFullFetch: true);
    rows.sort((a, b) => _sortByNamaTahunAsc(a, b));
    state = state.copyWith(items: rows, isLoading: false, error: null);
  }

  Future<void> _setOnlyOneActive(String activeId) async {
    final rows = await _service.getAllIncremental(forceFullFetch: true);
    for (final row in rows) {
      final shouldBeActive = row.id == activeId;
      if (row.aktif != shouldBeActive) {
        await _service.update(row.id, {'aktif': shouldBeActive});
      }
    }

    final activeRow = rows.where((item) => item.id == activeId).toList();
    if (activeRow.isNotEmpty) {
      await _syncSemesterAktifState(
        activeTahunAjaranId: activeId,
        activeSemesterKe: activeRow.first.semesterAktif ?? 1,
        allTahunAjaranIds: rows.map((item) => item.id).toList(),
      );
    }
  }

  Future<void> _repairActiveInvariant() async {
    final rows = await _service.getAllIncremental(forceFullFetch: true);
    if (rows.isEmpty) {
      return;
    }

    final activeRows = rows.where((item) => item.aktif).toList();
    if (activeRows.length == 1) {
      return;
    }

    final preferred = activeRows.isEmpty
        ? _pickMostRecent(rows)
        : _pickMostRecent(activeRows);
    await _setOnlyOneActive(preferred.id);
  }

  TahunAjaranRecord _pickMostRecent(List<TahunAjaranRecord> rows) {
    final sorted = <TahunAjaranRecord>[...rows]
      ..sort((a, b) => _sortByNamaTahunAsc(a, b));
    return sorted.first;
  }

  int _sortByNamaTahunAsc(TahunAjaranRecord a, TahunAjaranRecord b) {
    final left = a.nama.toLowerCase();
    final right = b.nama.toLowerCase();
    return left.compareTo(right);
  }

  void _validateInput({required String nama, required int semesterAktif}) {
    final normalizedNama = nama.trim();
    if (normalizedNama.isEmpty) {
      throw Exception('Nama tahun ajaran tidak boleh kosong.');
    }

    final pattern = RegExp(r'^\d{4}/\d{4}$');
    if (!pattern.hasMatch(normalizedNama)) {
      throw Exception('Format nama harus YYYY/YYYY, contoh 2025/2026.');
    }

    final parts = normalizedNama.split('/');
    final firstYear = int.tryParse(parts[0]);
    final secondYear = int.tryParse(parts[1]);
    if (firstYear == null ||
        secondYear == null ||
        secondYear != firstYear + 1) {
      throw Exception('Tahun kedua harus satu tingkat di atas tahun pertama.');
    }

    if (semesterAktif != 1 && semesterAktif != 2) {
      throw Exception('Semester aktif harus 1 atau 2.');
    }
  }

  Future<void> _createDefaultSemesters({
    required String tahunAjaranId,
    required int semesterAktif,
  }) async {
    final semesterService = SemesterService();
    await _ensureSemester(
      semesterService: semesterService,
      tahunAjaranId: tahunAjaranId,
      semesterKe: 1,
      aktif: semesterAktif == 1,
    );
    await _ensureSemester(
      semesterService: semesterService,
      tahunAjaranId: tahunAjaranId,
      semesterKe: 2,
      aktif: semesterAktif == 2,
    );
  }

  Future<void> _syncSemesterAktifState({
    required String? activeTahunAjaranId,
    required int? activeSemesterKe,
    required List<String> allTahunAjaranIds,
  }) async {
    final semesterService = SemesterService();

    for (final tahunAjaranId in allTahunAjaranIds) {
      final rows = <SemesterRecord?>[
        await semesterService.getByTahunAjaranDanSemester(
          tahunAjaranId: tahunAjaranId,
          semesterKe: 1,
        ),
        await semesterService.getByTahunAjaranDanSemester(
          tahunAjaranId: tahunAjaranId,
          semesterKe: 2,
        ),
      ];

      for (final semester in rows.whereType<SemesterRecord>()) {
        final shouldBeActive =
            activeTahunAjaranId == tahunAjaranId &&
            activeSemesterKe == semester.semesterKe;

        if (semester.aktif != shouldBeActive || semester.isDeleted) {
          await semesterService.update(semester.id, <String, dynamic>{
            'is_aktif': shouldBeActive,
            'is_deleted': false,
          });
        }
      }
    }
  }

  Future<void> _ensureSemester({
    required SemesterService semesterService,
    required String tahunAjaranId,
    required int semesterKe,
    required bool aktif,
  }) async {
    final existing = await semesterService.getByTahunAjaranDanSemester(
      tahunAjaranId: tahunAjaranId,
      semesterKe: semesterKe,
    );

    if (existing == null) {
      await semesterService.create(<String, dynamic>{
        'tahun_ajaran_id': tahunAjaranId,
        'semester_ke': semesterKe,
        'is_aktif': aktif,
        'is_deleted': false,
      });
      return;
    }

    if (existing.aktif != aktif || existing.isDeleted) {
      await semesterService.update(existing.id, <String, dynamic>{
        'is_aktif': aktif,
        'is_deleted': false,
      });
    }
  }
}

final tahunAjaranManagementProvider =
    StateNotifierProvider<
      TahunAjaranManagementNotifier,
      TahunAjaranManagementState
    >((ref) {
      final service = ref.read(tahunAjaranServiceProvider);
      return TahunAjaranManagementNotifier(service);
    });

class TahunAjaranFormState {
  final bool isLoading;
  final String? error;
  final bool isSuccess;

  const TahunAjaranFormState({
    required this.isLoading,
    this.error,
    required this.isSuccess,
  });

  factory TahunAjaranFormState.initial() {
    return const TahunAjaranFormState(isLoading: false, isSuccess: false);
  }

  TahunAjaranFormState copyWith({
    bool? isLoading,
    String? error,
    bool? isSuccess,
  }) {
    return TahunAjaranFormState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

class TahunAjaranFormNotifier extends StateNotifier<TahunAjaranFormState> {
  final Ref _ref;

  TahunAjaranFormNotifier(this._ref) : super(TahunAjaranFormState.initial());

  Future<void> saveTahunAjaran({
    required String nama,
    required bool aktif,
    required int semesterAktif,
  }) async {
    state = state.copyWith(isLoading: true, error: null, isSuccess: false);

    try {
      await _ref
          .read(tahunAjaranManagementProvider.notifier)
          .addTahunAjaran(
            nama: nama,
            aktif: aktif,
            semesterAktif: semesterAktif,
          );

      state = state.copyWith(isLoading: false, isSuccess: true);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isSuccess: false,
        error: 'Gagal menyimpan tahun ajaran: $e',
      );
    }
  }

  void clearStatus() {
    state = state.copyWith(isSuccess: false, error: null);
  }
}

final tahunAjaranFormProvider =
    StateNotifierProvider.autoDispose<
      TahunAjaranFormNotifier,
      TahunAjaranFormState
    >((ref) {
      return TahunAjaranFormNotifier(ref);
    });
