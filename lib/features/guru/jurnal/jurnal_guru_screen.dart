import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../kepala_sekolah/widgets/app_alert.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/academic_year_provider.dart';
import '../../../core/widgets/app_external_filter_bar.dart';
import '../../../models/absensi_jurnal_model.dart';
import '../../../models/model_utils.dart';
import '../providers/jadwal_guru_supabase_provider.dart';
import '../providers/jurnal_absensi_supabase_provider.dart';
import '../../shared/providers/shared_academic_context_provider.dart';

class _DropdownOption {
  final String id;
  final String label;

  const _DropdownOption({required this.id, required this.label});
}

class _JamRangeOption {
  final String id;
  final String kelasId;
  final String mapelId;
  final int jamMulai;
  final int jamSelesai;
  final String label;

  const _JamRangeOption({
    required this.id,
    required this.kelasId,
    required this.mapelId,
    required this.jamMulai,
    required this.jamSelesai,
    required this.label,
  });
}

/// Screen utama untuk Jurnal Pembelajaran Guru dengan TabBar
/// Tab 1: Input Jurnal (form input jurnal dan absensi)
/// Tab 2: History Jurnal (daftar jurnal yang pernah diinput)
class JurnalGuruScreen extends ConsumerStatefulWidget {
  final AcademicYearProvider academicYearProvider;
  final String guruUid;

  const JurnalGuruScreen({
    super.key,
    required this.academicYearProvider,
    required this.guruUid,
  });

  @override
  ConsumerState<JurnalGuruScreen> createState() => _JurnalGuruScreenState();
}

class _JurnalGuruScreenState extends ConsumerState<JurnalGuruScreen> {
  final _materiController = TextEditingController();
  final _catatanController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String? _selectedKelasId;
  String? _selectedMapelId;
  String? _selectedJamRangeId;
  int _selectedJamMulai = 1;
  int _selectedJamSelesai = 1;
  String _selectedStatusGuru = 'Masuk';
  bool _isSaving = false;

  List<_DropdownOption> _kelasOptions = const [];
  List<_DropdownOption> _mapelOptions = const [];
  final Map<String, String> _absensiBySiswaId = {};
  List<_DropdownOption> _tahunAjaranOptions = const [];
  Map<String, int> _semesterAktifByTahunAjaranId = const <String, int>{};
  String? _selectedTahunAjaranId;
  String? _selectedSemesterId;
  int _selectedSemester = 1;
  bool _isReferenceLoading = false;
  String? _referenceError;
  static const List<String> _hariHistoryOptions = <String>[
    'Semua Hari',
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];
  String _selectedHistoryHari = 'Semua Hari';
  DateTime? _selectedHistoryDate;
  String? _selectedHistoryTahunAjaranId;
  int _selectedHistorySemester = 1;
  String? _selectedHistoryKelasId;
  String? _selectedHistoryMapelId;
  bool _isHistoryFilterVisible = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await _loadReferenceData();
    });
  }

  @override
  void dispose() {
    _materiController.dispose();
    _catatanController.dispose();
    super.dispose();
  }

  Future<void> _syncDropdownFromJadwal({bool preserveSelection = true}) async {
    final notifier = ref.read(jadwalGuruProvider(widget.guruUid).notifier);
    final kelasOptions = notifier
        .getAvailableKelas()
        .map((item) => _DropdownOption(id: item.id, label: item.label))
        .toList();

    String? selectedKelas = preserveSelection ? _selectedKelasId : null;
    if (selectedKelas == null ||
        !kelasOptions.any((item) => item.id == selectedKelas)) {
      selectedKelas = kelasOptions.isNotEmpty ? kelasOptions.first.id : null;
    }

    final mapelOptions = selectedKelas == null
        ? <_DropdownOption>[]
        : notifier
              .getMapelByKelas(selectedKelas)
              .map((item) => _DropdownOption(id: item.id, label: item.label))
              .toList();

    String? selectedMapel = preserveSelection ? _selectedMapelId : null;
    if (selectedMapel == null ||
        !mapelOptions.any((item) => item.id == selectedMapel)) {
      selectedMapel = mapelOptions.isNotEmpty ? mapelOptions.first.id : null;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _kelasOptions = kelasOptions;
      _selectedKelasId = selectedKelas;
      _mapelOptions = mapelOptions;
      _selectedMapelId = selectedMapel;
      _absensiBySiswaId.clear();
    });

    _syncJamRangeSelection(preserveSelection: preserveSelection);

    if (_selectedKelasId != null) {
      await _loadSiswaKelas(_selectedKelasId!);
    }
  }

  List<_JamRangeOption> _buildJamRangeOptions() {
    final hari = _formatHariIndonesia(_selectedDate);
    if (hari == '-') {
      return const <_JamRangeOption>[];
    }

    final jadwalState = ref.read(jadwalGuruProvider(widget.guruUid));
    final options = <_JamRangeOption>[];
    final seen = <String>{};

    for (final item in jadwalState.data) {
      if (item.hari != hari) {
        continue;
      }
      if (_selectedKelasId != null && item.kelasId != _selectedKelasId) {
        continue;
      }
      if (_selectedMapelId != null && item.mapelId != _selectedMapelId) {
        continue;
      }

      final id = '${item.kelasId}|${item.mapelId}|${item.jamAwal}|${item.jamAkhir}';
      if (!seen.add(id)) {
        continue;
      }
      options.add(
        _JamRangeOption(
          id: id,
          kelasId: item.kelasId,
          mapelId: item.mapelId,
          jamMulai: item.jamAwal,
          jamSelesai: item.jamAkhir,
          label: 'Jam ${item.jamAwal} - ${item.jamAkhir} (${item.waktuMulai ?? '--:--'} - ${item.waktuSelesai ?? '--:--'})',
        ),
      );
    }

    options.sort((a, b) => a.jamMulai.compareTo(b.jamMulai));
    return options;
  }

  void _syncJamRangeSelection({bool preserveSelection = true}) {
    final options = _buildJamRangeOptions();
    _JamRangeOption? selected;

    if (preserveSelection && _selectedJamRangeId != null) {
      for (final item in options) {
        if (item.id == _selectedJamRangeId) {
          selected = item;
          break;
        }
      }
    }
    selected ??= options.isEmpty ? null : options.first;

    setState(() {
      _selectedJamRangeId = selected?.id;
      _selectedJamMulai = selected?.jamMulai ?? 1;
      _selectedJamSelesai = selected?.jamSelesai ?? 1;
    });
  }

  Future<void> _loadReferenceData({bool forceRefreshData = false}) async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isReferenceLoading = true;
      _referenceError = null;
    });

    try {
      final cache = ref.read(appMasterCacheProvider);
      final tahunAjaran = await cache.getTahunAjaran(
        ref.read,
        forceRefresh: forceRefreshData,
      );

      String? activeYearId;
      for (final item in tahunAjaran) {
        if (item.aktif) {
          activeYearId = item.id;
          break;
        }
      }

      if (activeYearId == null && tahunAjaran.isNotEmpty) {
        activeYearId = tahunAjaran.first.id;
      }

      int activeSemester = 1;
      if (activeYearId != null) {
        for (final item in tahunAjaran) {
          if (item.id == activeYearId) {
            activeSemester = item.semesterAktif ?? 1;
            break;
          }
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _tahunAjaranOptions = tahunAjaran
            .map((item) => _DropdownOption(id: item.id, label: item.nama))
            .toList()
          ..sort((a, b) => b.label.compareTo(a.label));
        _semesterAktifByTahunAjaranId = <String, int>{
          for (final item in tahunAjaran) item.id: item.semesterAktif ?? 1,
        };
        _selectedTahunAjaranId = activeYearId;
        _selectedSemesterId = null;
        _selectedSemester = activeSemester;
        if (_selectedHistoryTahunAjaranId == null ||
            !_tahunAjaranOptions.any(
              (item) => item.id == _selectedHistoryTahunAjaranId,
            )) {
          _selectedHistoryTahunAjaranId = activeYearId;
          _selectedHistorySemester = activeSemester;
        }
        _isReferenceLoading = false;
      });

      if (_selectedTahunAjaranId == null) {
        setState(() {
          _kelasOptions = const <_DropdownOption>[];
          _mapelOptions = const <_DropdownOption>[];
          _selectedKelasId = null;
          _selectedMapelId = null;
        });
        return;
      }

      await ref
          .read(jadwalGuruProvider(widget.guruUid).notifier)
          .loadJadwalByTahunAjaran(
            _selectedTahunAjaranId!,
            semester: _selectedSemester,
            semesterId: _selectedSemesterId,
            forceRefreshData: forceRefreshData,
            forceRefreshCache: forceRefreshData,
          );

      await _syncDropdownFromJadwal();
      await _reloadHistoryJurnal(forceRefreshData: forceRefreshData);
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isReferenceLoading = false;
        _referenceError = 'Gagal memuat referensi jurnal: $e';
      });
    }
  }

  Future<void> _onTahunAjaranChanged(String? tahunAjaranId) async {
    if (tahunAjaranId == null) {
      return;
    }

    int selectedSemester = 1;
    final tahunAjaran = await ref.read(appMasterCacheProvider).getTahunAjaran(
      ref.read,
      forceRefresh: false,
    );
    for (final item in tahunAjaran) {
      if (item.id == tahunAjaranId) {
        selectedSemester = item.semesterAktif ?? 1;
        break;
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedTahunAjaranId = tahunAjaranId;
      _selectedSemesterId = null;
      _selectedSemester = selectedSemester;
    });

    await ref
        .read(jadwalGuruProvider(widget.guruUid).notifier)
        .loadJadwalByTahunAjaran(
          tahunAjaranId,
          semester: _selectedSemester,
          semesterId: _selectedSemesterId,
        );
    await _syncDropdownFromJadwal(preserveSelection: false);
    await _reloadJurnal();
  }

  Future<void> _handleKelasChanged(String? kelasId) async {
    final notifier = ref.read(jadwalGuruProvider(widget.guruUid).notifier);
    final mapelOptions = kelasId == null
        ? <_DropdownOption>[]
        : notifier
              .getMapelByKelas(kelasId)
              .map((item) => _DropdownOption(id: item.id, label: item.label))
              .toList();

    setState(() {
      _selectedKelasId = kelasId;
      _mapelOptions = mapelOptions;
      if (_selectedMapelId == null ||
          !mapelOptions.any((item) => item.id == _selectedMapelId)) {
        _selectedMapelId = mapelOptions.isNotEmpty
            ? mapelOptions.first.id
            : null;
      }
      _absensiBySiswaId.clear();
    });

    _syncJamRangeSelection(preserveSelection: false);

    if (kelasId != null) {
      await _loadSiswaKelas(kelasId);
    }
  }

  Future<void> _reloadJurnal({bool forceRefreshData = false}) async {
    try {
      final tahunAjaranId = _selectedTahunAjaranId;
      final semester = _selectedSemester;
      if (tahunAjaranId == null) {
        return;
      }

      await ref
          .read(jurnalAbsensiSupabaseProvider(widget.guruUid).notifier)
          .getJurnalByGuru(
            tahunAjaranId: tahunAjaranId,
            semester: semester,
            semesterId: _selectedSemesterId,
            includeAbsensi: true,
            forceRefreshData: forceRefreshData,
            forceRefreshCache: forceRefreshData,
          );
    } catch (e) {
      if (!mounted) {
        return;
      }
      await AppAlert.error(context, message: 'Gagal memuat jurnal: $e');
    }
  }

  Future<void> _reloadHistoryJurnal({bool forceRefreshData = false}) async {
    try {
      final tahunAjaranId =
          _selectedHistoryTahunAjaranId ?? _selectedTahunAjaranId;
      if (tahunAjaranId == null) {
        return;
      }

      await ref
          .read(jurnalAbsensiSupabaseProvider(widget.guruUid).notifier)
          .getJurnalByGuru(
            tahunAjaranId: tahunAjaranId,
            semester: _selectedHistorySemester,
            includeAbsensi: true,
            forceRefreshData: forceRefreshData,
            forceRefreshCache: forceRefreshData,
          );
    } catch (e) {
      if (!mounted) {
        return;
      }
      await AppAlert.error(
        context,
        message: 'Gagal memuat history jurnal: $e',
      );
    }
  }

  Future<void> _loadSiswaKelas(String kelasId) async {
    await ref
        .read(jurnalAbsensiSupabaseProvider(widget.guruUid).notifier)
        .getSiswaByKelas(kelasId);

    final state = ref.read(jurnalAbsensiSupabaseProvider(widget.guruUid));
    if (!mounted) {
      return;
    }

    setState(() {
      for (final siswa in state.siswaKelasAktif) {
        _absensiBySiswaId.putIfAbsent(siswa.siswaId, () => 'hadir');
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
      });
      _syncJamRangeSelection(preserveSelection: false);
    }
  }

  Future<void> _saveJurnal() async {
    if (_selectedKelasId == null || _selectedMapelId == null) {
      await AppAlert.error(
        context,
        message: 'Kelas dan mata pelajaran wajib dipilih.',
      );
      return;
    }
    if (_selectedJamRangeId == null) {
      await AppAlert.error(
        context,
        message: 'Pilih rentang jam sesuai jadwal mengajar yang tersedia.',
      );
      return;
    }

    final tahunAjaranId = _selectedTahunAjaranId;
    if (tahunAjaranId == null) {
      await AppAlert.error(context, message: 'Tahun ajaran belum tersedia.');
      return;
    }

    final pairValid = ref
        .read(jadwalGuruProvider(widget.guruUid).notifier)
        .isPairValid(kelasId: _selectedKelasId!, mapelId: _selectedMapelId!);
    if (!pairValid) {
      await AppAlert.error(
        context,
        message: 'Kelas dan mata pelajaran tidak sesuai jadwal mengajar guru.',
      );
      return;
    }

    if (_materiController.text.trim().isEmpty) {
      await AppAlert.error(
        context,
        message: 'Materi pembelajaran wajib diisi.',
      );
      return;
    }

    if (_selectedJamMulai < 1 ||
        _selectedJamSelesai > 8 ||
        _selectedJamSelesai < _selectedJamMulai) {
      await AppAlert.error(
        context,
        message: 'Rentang jam tidak valid.',
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final notifier = ref.read(
        jurnalAbsensiSupabaseProvider(widget.guruUid).notifier,
      );

      final normalizedDate = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      );

      final siswa = ref
          .read(jurnalAbsensiSupabaseProvider(widget.guruUid))
          .siswaKelasAktif;

      final drafts = siswa
          .map(
            (item) => AbsensiDraft(
              siswaId: item.siswaId,
              statusKehadiran:
                  _absensiBySiswaId[item.siswaId]?.toLowerCase() ?? 'hadir',
            ),
          )
          .toList();

      final result = await notifier.createJurnalMultiJam(
        kelasId: _selectedKelasId!,
        mapelId: _selectedMapelId!,
        tahunAjaranId: tahunAjaranId,
        semester: _selectedSemester,
        semesterId: _selectedSemesterId,
        tanggal: normalizedDate,
        jamMulai: _selectedJamMulai,
        jamSelesai: _selectedJamSelesai,
        materi: _materiController.text.trim(),
        statusKehadiran: _selectedStatusGuru,
        catatan: _catatanController.text.trim(),
        absensi: drafts,
      );

      if (!mounted) {
        return;
      }

      if (result.createdJams.isNotEmpty) {
        _materiController.clear();
        _catatanController.clear();
        await AppAlert.success(
          context,
          title: 'Berhasil',
          message: 'Jurnal berhasil disimpan.',
        );
        if (drafts.isNotEmpty) {
          if (!mounted) {
            return;
          }
          await AppAlert.success(
            context,
            title: 'Berhasil',
            message: 'Absensi berhasil disimpan.',
          );
        }
      }

      final messageParts = <String>[];
      if (result.skippedDuplicateJams.isNotEmpty) {
        messageParts.add(
          'Duplikat dilewati jam: ${result.skippedDuplicateJams.join(', ')}',
        );
      }
      if (result.failedJams.isNotEmpty) {
        messageParts.add('Gagal simpan jam: ${result.failedJams.join(', ')}');
      }

      final message = messageParts.isEmpty
          ? 'Tidak ada jurnal baru yang disimpan.'
          : messageParts.join(' | ');

      if (messageParts.isNotEmpty) {
        if (!mounted) {
          return;
        }
        await AppAlert.info(context, message: message);
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      await AppAlert.error(context, message: 'Gagal menyimpan jurnal: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _showEditJurnalDialog(JurnalAbsensiItem item) async {
    final notifier = ref.read(
      jurnalAbsensiSupabaseProvider(widget.guruUid).notifier,
    );
    await notifier.getSiswaByKelas(item.kelasId);
    if (!mounted) {
      return;
    }
    final afterSiswaState = ref.read(
      jurnalAbsensiSupabaseProvider(widget.guruUid),
    );
    final existingAbsensi =
        afterSiswaState.absensiByJurnalId[item.id] ??
        const <AbsensiJurnalRecord>[];

    final materiController = TextEditingController(text: item.materi);
    final catatanController = TextEditingController(text: item.catatan ?? '');
    String status = item.statusKehadiran;

    final existingBySiswaId = <String, AbsensiJurnalRecord>{
      for (final row in existingAbsensi)
        if (row.siswaId.trim().isNotEmpty) row.siswaId: row,
    };

    final attendanceRows = <_EditAbsensiRowState>[];
    for (final siswaKelas in afterSiswaState.siswaKelasAktif) {
      final siswaId = siswaKelas.siswaId;
      final siswaNama = afterSiswaState.siswaNamaById[siswaId];
      final existing = existingBySiswaId[siswaId];
      attendanceRows.add(
        _EditAbsensiRowState(
          siswaId: siswaId,
          siswaNama: siswaNama ?? siswaKelas.siswaNama ?? siswaId,
          status: _normalizeStudentStatus(existing?.statusKehadiran ?? 'hadir'),
          catatan: existing?.catatan,
        ),
      );
    }

    for (final existing in existingAbsensi) {
      if (attendanceRows.any((row) => row.siswaId == existing.siswaId)) {
        continue;
      }
      attendanceRows.add(
        _EditAbsensiRowState(
          siswaId: existing.siswaId,
          siswaNama: existing.siswaId,
          status: _normalizeStudentStatus(existing.statusKehadiran),
          catatan: existing.catatan,
        ),
      );
    }

    attendanceRows.sort(
      (a, b) => a.siswaNama.toLowerCase().compareTo(b.siswaNama.toLowerCase()),
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720, maxHeight: 760),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Edit Jurnal Guru',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${item.mapelNama} • ${item.kelasNama}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(dialogContext).pop(false),
                            icon: const Icon(Icons.close_rounded),
                            color: Colors.white,
                            tooltip: 'Tutup',
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withAlpha(18),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Wrap(
                                spacing: 12,
                                runSpacing: 8,
                                children: [
                                  _buildInfoPill(
                                    icon: Icons.event_rounded,
                                    label:
                                        '${item.tanggal?.day}/${item.tanggal?.month}/${item.tanggal?.year}',
                                  ),
                                  _buildInfoPill(
                                    icon: Icons.schedule_rounded,
                                    label: 'Jam ${item.jamAwal}-${item.jamAkhir} (${ModelUtils.getWaktuMulai(item.jamAwal) ?? '--:--'} - ${ModelUtils.getWaktuSelesai(item.jamAkhir) ?? '--:--'})',
                                  ),
                                  _buildInfoPill(
                                    icon: Icons.school_rounded,
                                    label: item.tahunAjaranNama,
                                  ),
                                  _buildInfoPill(
                                    icon: Icons.layers_rounded,
                                    label: 'Semester ${item.semester}',
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            DropdownButtonFormField<String>(
                              initialValue: status,
                              decoration: const InputDecoration(
                                labelText: 'Status Kehadiran Guru',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.person_rounded),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'Masuk',
                                  child: Text('Masuk'),
                                ),
                                DropdownMenuItem(value: 'Izin', child: Text('Izin')),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setDialogState(() {
                                    status = value;
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: materiController,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                labelText: 'Materi Pembelajaran',
                                border: OutlineInputBorder(),
                                alignLabelWithHint: true,
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: catatanController,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                labelText: 'Catatan',
                                border: OutlineInputBorder(),
                                alignLabelWithHint: true,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Text(
                                  'Presensi Siswa',
                                  style: Theme.of(dialogContext)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withAlpha(18),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '${attendanceRows.length} siswa',
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (attendanceRows.isEmpty)
                              const Text('Data presensi siswa belum tersedia.')
                            else
                              ...attendanceRows.map((row) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade200),
                                    borderRadius: BorderRadius.circular(16),
                                    color: Colors.white,
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor: AppColors.primary.withAlpha(18),
                                        child: Text(
                                          row.siswaNama.isEmpty
                                              ? '?'
                                              : row.siswaNama.substring(0, 1).toUpperCase(),
                                          style: const TextStyle(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          row.siswaNama,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      SizedBox(
                                        width: 120,
                                        child: DropdownButtonFormField<String>(
                                          initialValue: row.status,
                                          decoration: const InputDecoration(
                                            isDense: true,
                                            border: OutlineInputBorder(),
                                            contentPadding: EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 10,
                                            ),
                                          ),
                                          items: const [
                                            DropdownMenuItem(
                                              value: 'hadir',
                                              child: Text('Hadir'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'izin',
                                              child: Text('Izin'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'sakit',
                                              child: Text('Sakit'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'alpa',
                                              child: Text('Alpa'),
                                            ),
                                          ],
                                          onChanged: (newValue) {
                                            if (newValue == null) {
                                              return;
                                            }
                                            setDialogState(() {
                                              row.status = newValue;
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(dialogContext).pop(false),
                            child: const Text('Batal'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () => Navigator.of(dialogContext).pop(true),
                            icon: const Icon(Icons.save_outlined),
                            label: const Text('Simpan'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    final nextMateri = materiController.text.trim();
    final nextCatatan = catatanController.text.trim();
    materiController.dispose();
    catatanController.dispose();

    if (saved != true) {
      return;
    }

    try {
      final absensiDrafts = attendanceRows
          .map(
            (row) => AbsensiEditDraft(
              siswaId: row.siswaId,
              statusKehadiran: row.status,
              catatan: row.catatan,
            ),
          )
          .toList(growable: false);

      await ref
          .read(jurnalAbsensiSupabaseProvider(widget.guruUid).notifier)
          .updateJurnalWithAbsensi(
            jurnalId: item.id,
            kelasId: item.kelasId,
            mapelId: item.mapelId,
            tahunAjaranId: item.tahunAjaranId,
            semester: item.semester,
            semesterId: null,
            tanggal: item.tanggal ?? DateTime.now(),
            jamAwal: item.jamAwal,
            jamAkhir: item.jamAkhir,
            materi: nextMateri,
            statusKehadiran: status,
            catatan: nextCatatan,
            absensi: absensiDrafts,
          );

      await _reloadHistoryJurnal();

      if (!mounted) {
        return;
      }
      await AppAlert.success(
        context,
        title: 'Berhasil',
        message: 'Jurnal dan presensi berhasil diperbarui.',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      await AppAlert.error(context, message: 'Gagal memperbarui jurnal: $e');
    }
  }

  String _normalizeStudentStatus(String value) {
    switch (value.trim().toLowerCase()) {
      case 'izin':
        return 'izin';
      case 'sakit':
        return 'sakit';
      case 'alpa':
      case 'alpha':
        return 'alpa';
      default:
        return 'hadir';
    }
  }

  Future<void> _deleteJurnal(JurnalAbsensiItem item) async {
    final confirmed = await AppAlert.confirm(
      context,
      title: 'Hapus jurnal ini?',
      message: 'Data yang dihapus tidak dapat dikembalikan.',
      okText: 'Ya, hapus',
      cancelText: 'Batal',
    );
    if (!confirmed) {
      return;
    }

    try {
      await ref
          .read(jurnalAbsensiSupabaseProvider(widget.guruUid).notifier)
          .deleteJurnal(
            jurnalId: item.id,
            tahunAjaranId: item.tahunAjaranId,
            semester: item.semester,
            semesterId: null,
          );

      if (!mounted) {
        return;
      }
      await AppAlert.success(
        context,
        title: 'Berhasil',
        message: 'Jurnal berhasil dihapus.',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      await AppAlert.error(context, message: 'Gagal menghapus jurnal: $e');
    }
  }

  Future<void> _showDetailJurnal(
    JurnalAbsensiItem item,
    List<AbsensiJurnalRecord> absensi,
  ) async {
    await ref
        .read(jurnalAbsensiSupabaseProvider(widget.guruUid).notifier)
        .getSiswaByKelas(item.kelasId);
    if (!mounted) {
      return;
    }
    final afterSiswaState = ref.read(
      jurnalAbsensiSupabaseProvider(widget.guruUid),
    );
    final namaBySiswaId = <String, String>{
      ...afterSiswaState.siswaNamaById,
      for (final siswa in afterSiswaState.siswaKelasAktif)
        if (siswa.siswaNama != null && siswa.siswaNama!.trim().isNotEmpty)
          siswa.siswaId: siswa.siswaNama!.trim(),
    };

    final hadir = absensi
        .where((row) => row.statusKehadiran.toLowerCase() == 'hadir')
        .length;
    final izin = absensi
        .where((row) => row.statusKehadiran.toLowerCase() == 'izin')
        .length;
    final sakit = absensi
        .where((row) => row.statusKehadiran.toLowerCase() == 'sakit')
        .length;
    final alpa = absensi
        .where((row) => row.statusKehadiran.toLowerCase() == 'alpa')
        .length;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.mapelNama,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.kelasNama,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildStatusBadge(item.statusKehadiran),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildInfoPill(
                      icon: Icons.event_rounded,
                      label:
                          '${item.tanggal?.day}/${item.tanggal?.month}/${item.tanggal?.year}',
                    ),
                    _buildInfoPill(
                      icon: Icons.schedule_rounded,
                      label: 'Jam ${item.jamAwal}-${item.jamAkhir} (${ModelUtils.getWaktuMulai(item.jamAwal) ?? '--:--'} - ${ModelUtils.getWaktuSelesai(item.jamAkhir) ?? '--:--'})',
                    ),
                    _buildInfoPill(
                      icon: Icons.school_rounded,
                      label: item.tahunAjaranNama,
                    ),
                    _buildInfoPill(
                      icon: Icons.layers_rounded,
                      label: 'Semester ${item.semester}',
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _buildDetailSection(
                  context,
                  title: 'Materi Pembelajaran',
                  child: Text(item.materi),
                ),
                const SizedBox(height: 12),
                _buildDetailSection(
                  context,
                  title: 'Catatan',
                  child: Text(
                    (item.catatan ?? '').trim().isEmpty ? '-' : item.catatan!,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Ringkasan Presensi',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _buildAttendanceSummaryCard('Hadir', hadir)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildAttendanceSummaryCard('Izin', izin)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildAttendanceSummaryCard('Sakit', sakit)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildAttendanceSummaryCard('Alpa', alpa)),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Daftar Presensi Siswa',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: absensi.isEmpty
                      ? const Center(child: Text('Belum ada data presensi siswa.'))
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: absensi.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final row = absensi[index];
                            final siswaNama =
                                namaBySiswaId[row.siswaId] ?? row.siswaId;
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: AppColors.primary.withAlpha(18),
                                    child: Text(
                                      siswaNama.isEmpty
                                          ? '?'
                                          : siswaNama.substring(0, 1).toUpperCase(),
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      siswaNama,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  _buildStatusBadge(row.statusKehadiran),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatLastUpdated(DateTime? value) {
    if (value == null) {
      return '-';
    }
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    final day = value.day.toString().padLeft(2, '0');
    final month = months[value.month - 1];
    final year = value.year;
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day $month $year, $hour:$minute';
  }

  String _formatHariIndonesia(DateTime? value) {
    if (value == null) {
      return '-';
    }

    switch (value.weekday) {
      case DateTime.monday:
        return 'Senin';
      case DateTime.tuesday:
        return 'Selasa';
      case DateTime.wednesday:
        return 'Rabu';
      case DateTime.thursday:
        return 'Kamis';
      case DateTime.friday:
        return 'Jumat';
      case DateTime.saturday:
        return 'Sabtu';
      case DateTime.sunday:
        return 'Minggu';
      default:
        return '-';
    }
  }

  bool _isSameDate(DateTime? a, DateTime? b) {
    if (a == null || b == null) {
      return false;
    }
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _pickHistoryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedHistoryDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedHistoryDate = picked;
      });
    }
  }

  void _clearHistoryDate() {
    setState(() {
      _selectedHistoryDate = null;
    });
  }

  int _resolveDefaultSemesterForTahunAjaran(String tahunAjaranId) {
    return _semesterAktifByTahunAjaranId[tahunAjaranId] ?? 1;
  }

  Future<void> _onHistoryTahunAjaranChanged(String? tahunAjaranId) async {
    if (tahunAjaranId == null) {
      return;
    }

    setState(() {
      _selectedHistoryTahunAjaranId = tahunAjaranId;
      _selectedHistorySemester = _resolveDefaultSemesterForTahunAjaran(
        tahunAjaranId,
      );
      _selectedHistoryKelasId = null;
      _selectedHistoryMapelId = null;
      _selectedHistoryDate = null;
      _selectedHistoryHari = 'Semua Hari';
    });

    await _reloadHistoryJurnal();
  }

  Future<void> _onHistorySemesterChanged(int? semester) async {
    if (semester == null) {
      return;
    }

    setState(() {
      _selectedHistorySemester = semester;
      _selectedHistoryKelasId = null;
      _selectedHistoryMapelId = null;
      _selectedHistoryDate = null;
      _selectedHistoryHari = 'Semua Hari';
    });

    await _reloadHistoryJurnal();
  }

  void _resetHistoryFilters() {
    final fallbackTahunAjaranId =
        _selectedTahunAjaranId ??
        (_tahunAjaranOptions.isEmpty ? null : _tahunAjaranOptions.first.id);

    setState(() {
      _selectedHistoryTahunAjaranId = fallbackTahunAjaranId;
      _selectedHistorySemester = fallbackTahunAjaranId == null
          ? 1
          : _resolveDefaultSemesterForTahunAjaran(fallbackTahunAjaranId);
      _selectedHistoryKelasId = null;
      _selectedHistoryMapelId = null;
      _selectedHistoryHari = 'Semua Hari';
      _selectedHistoryDate = null;
    });

    _reloadHistoryJurnal();
  }

  List<_DropdownOption> _buildHistoryKelasOptions(JurnalAbsensiState state) {
    final seen = <String>{};
    final options = <_DropdownOption>[];
    for (final item in state.jurnal) {
      if (!seen.add(item.kelasId)) {
        continue;
      }
      options.add(_DropdownOption(id: item.kelasId, label: item.kelasNama));
    }
    options.sort((a, b) => a.label.compareTo(b.label));
    return options;
  }

  List<_DropdownOption> _buildHistoryMapelOptions(JurnalAbsensiState state) {
    final seen = <String>{};
    final options = <_DropdownOption>[];
    for (final item in state.jurnal) {
      if (_selectedHistoryKelasId != null && item.kelasId != _selectedHistoryKelasId) {
        continue;
      }
      if (!seen.add(item.mapelId)) {
        continue;
      }
      options.add(_DropdownOption(id: item.mapelId, label: item.mapelNama));
    }
    options.sort((a, b) => a.label.compareTo(b.label));
    return options;
  }

  Widget _buildInfoPill({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final normalized = status.trim().toLowerCase();
    Color color;
    String label;
    switch (normalized) {
      case 'izin':
        color = AppColors.warning;
        label = 'Izin';
        break;
      case 'sakit':
        color = AppColors.info;
        label = 'Sakit';
        break;
      case 'alpa':
      case 'alpha':
        color = AppColors.error;
        label = 'Alpa';
        break;
      default:
        color = AppColors.success;
        label = status.trim().isEmpty ? 'Hadir' : status;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildDetailSection(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _buildAttendanceSummaryCard(String label, int total) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Text(
            total.toString(),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(jurnalAbsensiSupabaseProvider(widget.guruUid));

    return ListenableBuilder(
      listenable: widget.academicYearProvider,
      builder: (context, child) {
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Jurnal & Absensi'),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              actions: [
                IconButton(
                  onPressed: () async {
                    await _loadReferenceData(forceRefreshData: true);
                  },
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Reload Data',
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(78),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Data terakhir diupdate: ${_formatLastUpdated(_selectedDate)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const TabBar(
                      indicatorColor: Colors.white,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white70,
                      tabs: [
                        Tab(icon: Icon(Icons.edit_note), text: 'Input Jurnal'),
                        Tab(icon: Icon(Icons.history), text: 'History Jurnal'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            body: Column(
              children: [
                if (state.isLoading) const LinearProgressIndicator(),
                Expanded(
                  child: TabBarView(
                    children: [_buildInputTab(state), _buildHistoryTab(state)],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInputTab(JurnalAbsensiState state) {
    final jadwalState = ref.watch(jadwalGuruProvider(widget.guruUid));
    final jamRangeOptions = _buildJamRangeOptions();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_isReferenceLoading)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        if (_referenceError != null && _referenceError!.isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.error.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.error.withAlpha(70)),
            ),
            child: Text(
              _referenceError!,
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        if (jadwalState.isLoading)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        if (!jadwalState.isLoading && jadwalState.data.isEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.error.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.error.withAlpha(70)),
            ),
            child: const Text(
              'Tidak ada jadwal mengajar pada tahun ajaran ini',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Input Jurnal Mengajar',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (_tahunAjaranOptions.length <= 1)
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Tahun Ajaran',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.school),
                    ),
                    child: Text(
                      _tahunAjaranOptions.isEmpty
                          ? '-'
                          : _tahunAjaranOptions
                              .firstWhere(
                                (item) => item.id == _selectedTahunAjaranId,
                                orElse: () => _tahunAjaranOptions.first,
                              )
                              .label,
                    ),
                  )
                else
                  DropdownButtonFormField<String>(
                    initialValue: _selectedTahunAjaranId,
                    decoration: const InputDecoration(
                      labelText: 'Tahun Ajaran',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.school),
                    ),
                    items: _tahunAjaranOptions
                        .map(
                          (item) => DropdownMenuItem<String>(
                            value: item.id,
                            child: Text(item.label),
                          ),
                        )
                        .toList(),
                    onChanged: _onTahunAjaranChanged,
                  ),
                const SizedBox(height: 12),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Semester Aktif',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.event_note),
                  ),
                  child: Text('Semester $_selectedSemester'),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Tanggal',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedKelasId,
                  decoration: const InputDecoration(
                    labelText: 'Kelas',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.class_),
                  ),
                  items: _kelasOptions
                      .map(
                        (item) => DropdownMenuItem(
                          value: item.id,
                          child: Text(item.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) async {
                    await _handleKelasChanged(value);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedMapelId,
                  decoration: const InputDecoration(
                    labelText: 'Mata Pelajaran',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.book),
                  ),
                  items: _mapelOptions
                      .map(
                        (item) => DropdownMenuItem(
                          value: item.id,
                          child: Text(item.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedMapelId = value;
                    });
                    _syncJamRangeSelection(preserveSelection: false);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedJamRangeId,
                  decoration: const InputDecoration(
                    labelText: 'Jam Mengajar',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.schedule),
                  ),
                  items: jamRangeOptions
                      .map(
                        (item) => DropdownMenuItem(
                          value: item.id,
                          child: Text(item.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    _JamRangeOption? selected;
                    for (final item in jamRangeOptions) {
                      if (item.id == value) {
                        selected = item;
                        break;
                      }
                    }
                    if (selected == null) {
                      return;
                    }
                    setState(() {
                      _selectedJamRangeId = selected!.id;
                      _selectedJamMulai = selected.jamMulai;
                      _selectedJamSelesai = selected.jamSelesai;
                      _selectedKelasId = selected.kelasId;
                      _selectedMapelId = selected.mapelId;
                    });
                  },
                ),
                if (jamRangeOptions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Tidak ada rentang jam sesuai jadwal pada hari yang dipilih.',
                      style: TextStyle(color: AppColors.error),
                    ),
                  ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedStatusGuru,
                  decoration: const InputDecoration(
                    labelText: 'Status Kehadiran Guru',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Masuk', child: Text('Masuk')),
                    DropdownMenuItem(value: 'Izin', child: Text('Izin')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedStatusGuru = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _materiController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Materi Pembelajaran',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _catatanController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Catatan',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (state.siswaKelasAktif.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Absensi Siswa (${state.siswaKelasAktif.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...state.siswaKelasAktif.map((item) {
                    final name =
                        state.siswaNamaById[item.siswaId] ??
                        item.siswaNama ??
                        item.siswaId;
                    final value = _absensiBySiswaId[item.siswaId] ?? 'hadir';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(child: Text(name)),
                          const SizedBox(width: 8),
                          DropdownButton<String>(
                            value: value,
                            items: const [
                              DropdownMenuItem(
                                value: 'hadir',
                                child: Text('Hadir'),
                              ),
                              DropdownMenuItem(
                                value: 'izin',
                                child: Text('Izin'),
                              ),
                              DropdownMenuItem(
                                value: 'sakit',
                                child: Text('Sakit'),
                              ),
                              DropdownMenuItem(
                                value: 'alpa',
                                child: Text('Alpa'),
                              ),
                            ],
                            onChanged: (newValue) {
                              if (newValue == null) {
                                return;
                              }
                              setState(() {
                                _absensiBySiswaId[item.siswaId] = newValue;
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed:
              _isSaving ||
                  jadwalState.data.isEmpty ||
                  _selectedTahunAjaranId == null
              ? null
              : _saveJurnal,
          icon: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save),
          label: Text(_isSaving ? 'Menyimpan...' : 'Simpan Jurnal & Absensi'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryTab(JurnalAbsensiState state) {
    final kelasOptions = _buildHistoryKelasOptions(state);
    final mapelOptions = _buildHistoryMapelOptions(state);
    final filtered = state.jurnal.where((item) {
      if (_selectedHistoryKelasId != null &&
          item.kelasId != _selectedHistoryKelasId) {
        return false;
      }
      if (_selectedHistoryMapelId != null &&
          item.mapelId != _selectedHistoryMapelId) {
        return false;
      }
      if (_selectedHistoryHari == 'Semua Hari') {
        return _selectedHistoryDate == null ||
            _isSameDate(item.tanggal, _selectedHistoryDate);
      }
      final matchesHari =
          _formatHariIndonesia(item.tanggal) == _selectedHistoryHari;
      final matchesDate =
          _selectedHistoryDate == null ||
          _isSameDate(item.tanggal, _selectedHistoryDate);
      return matchesHari && matchesDate;
    }).toList();

    return RefreshIndicator(
      onRefresh: () => _reloadHistoryJurnal(forceRefreshData: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          AppExternalFilterBar(
            isExpanded: _isHistoryFilterVisible,
            onToggle: () {
              setState(() {
                _isHistoryFilterVisible = !_isHistoryFilterVisible;
              });
            },
            onReset: _resetHistoryFilters,
            onApply: () => setState(() {}),
            children: [
              AppExternalFilterField(
                label: 'Tahun Ajaran',
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedHistoryTahunAjaranId,
                  decoration: appExternalFilterDecoration(
                    hintText: 'Pilih tahun ajaran',
                    icon: Icons.school_rounded,
                  ),
                  items: _tahunAjaranOptions
                      .map(
                        (item) => DropdownMenuItem<String>(
                          value: item.id,
                          child: Text(item.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) async {
                    await _onHistoryTahunAjaranChanged(value);
                  },
                ),
              ),
              AppExternalFilterField(
                label: 'Semester',
                child: DropdownButtonFormField<int>(
                  initialValue: _selectedHistorySemester,
                  decoration: appExternalFilterDecoration(
                    hintText: 'Pilih semester',
                    icon: Icons.event_note_rounded,
                  ),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('Semester 1')),
                    DropdownMenuItem(value: 2, child: Text('Semester 2')),
                  ],
                  onChanged: (value) async {
                    await _onHistorySemesterChanged(value);
                  },
                ),
              ),
              AppExternalFilterField(
                label: 'Kelas',
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedHistoryKelasId,
                  decoration: appExternalFilterDecoration(
                    hintText: 'Semua kelas',
                    icon: Icons.class_rounded,
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('Semua Kelas'),
                    ),
                    ...kelasOptions.map(
                      (item) => DropdownMenuItem<String>(
                        value: item.id,
                        child: Text(item.label),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedHistoryKelasId = value;
                      _selectedHistoryMapelId = null;
                    });
                  },
                ),
              ),
              AppExternalFilterField(
                label: 'Mata Pelajaran',
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedHistoryMapelId,
                  decoration: appExternalFilterDecoration(
                    hintText: 'Semua mapel',
                    icon: Icons.menu_book_rounded,
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('Semua Mapel'),
                    ),
                    ...mapelOptions.map(
                      (item) => DropdownMenuItem<String>(
                        value: item.id,
                        child: Text(item.label),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedHistoryMapelId = value;
                    });
                  },
                ),
              ),
              AppExternalFilterField(
                label: 'Hari',
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedHistoryHari,
                  decoration: appExternalFilterDecoration(
                    hintText: 'Pilih hari',
                    icon: Icons.calendar_view_week_rounded,
                  ),
                  items: _hariHistoryOptions
                      .map(
                        (day) => DropdownMenuItem<String>(
                          value: day,
                          child: Text(day),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _selectedHistoryHari = value;
                    });
                  },
                ),
              ),
              AppExternalFilterField(
                label: 'Tanggal',
                child: InkWell(
                  onTap: _pickHistoryDate,
                  borderRadius: BorderRadius.circular(14),
                  child: InputDecorator(
                    decoration: appExternalFilterDecoration(
                      hintText: 'Semua tanggal',
                      icon: Icons.calendar_today_rounded,
                    ).copyWith(
                      suffixIcon: _selectedHistoryDate == null
                          ? null
                          : IconButton(
                              tooltip: 'Hapus tanggal',
                              onPressed: _clearHistoryDate,
                              icon: const Icon(Icons.close_rounded, size: 18),
                            ),
                    ),
                    child: Text(
                      _selectedHistoryDate == null
                          ? 'Semua Tanggal'
                          : '${_selectedHistoryDate!.day}/${_selectedHistoryDate!.month}/${_selectedHistoryDate!.year}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 120),
              child: Center(
                child: Text('Belum ada jurnal untuk filter yang dipilih.'),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final item = filtered[index];
                final absensi = state.absensiByJurnalId[item.id] ?? const [];

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text('${item.mapelNama} - ${item.kelasNama}'),
                    subtitle: Text(
                      '${item.tanggal?.day}/${item.tanggal?.month}/${item.tanggal?.year} | ${_formatHariIndonesia(item.tanggal)} | Jam ke ${item.jamAwal} - ${item.jamAkhir} (${ModelUtils.getWaktuMulai(item.jamAwal) ?? '--:--'} - ${ModelUtils.getWaktuSelesai(item.jamAkhir) ?? '--:--'})\n${item.materi}',
                    ),
                    isThreeLine: true,
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'detail') {
                          _showDetailJurnal(item, absensi);
                        }
                        if (value == 'edit') {
                          await _showEditJurnalDialog(item);
                        }
                        if (value == 'delete') {
                          await _deleteJurnal(item);
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'detail', child: Text('Detail')),
                        PopupMenuItem(
                          value: 'edit',
                          child: Text('Edit Jurnal'),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Hapus Jurnal'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _EditAbsensiRowState {
  final String siswaId;
  final String siswaNama;
  final String? catatan;
  String status;

  _EditAbsensiRowState({
    required this.siswaId,
    required this.siswaNama,
    required this.status,
    required this.catatan,
  });
}
