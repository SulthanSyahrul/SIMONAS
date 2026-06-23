import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../kepala_sekolah/widgets/app_alert.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/academic_year_provider.dart';
import '../../../../core/widgets/app_external_filter_bar.dart';
import '../../../../models/kelas_siswa_model.dart';
import '../../../../models/siswa_model.dart';
import '../../../../providers/supabase_providers.dart';
import '../../../shared/providers/shared_academic_context_provider.dart';
import '../../providers/jadwal_guru_supabase_provider.dart';
import '../../providers/tugas_guru_supabase_provider.dart';

class _DropdownOption {
  final String id;
  final String label;

  const _DropdownOption({required this.id, required this.label});
}

class _SiswaOption {
  final KelasSiswaRecord keanggotaan;
  final SiswaRecord siswa;

  const _SiswaOption({required this.keanggotaan, required this.siswa});
}

class _ScoreInputFormatter extends TextInputFormatter {
  const _ScoreInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) {
      return newValue;
    }

    final value = int.tryParse(text);
    if (value == null || value < 0 || value > 100) {
      return oldValue;
    }

    return newValue;
  }
}

class GuruTugasScreen extends ConsumerStatefulWidget {
  final AcademicYearProvider academicYearProvider;
  final String guruUid;

  const GuruTugasScreen({
    super.key,
    required this.academicYearProvider,
    required this.guruUid,
  });

  @override
  ConsumerState<GuruTugasScreen> createState() => _GuruTugasScreenState();
}

class _GuruTugasScreenState extends ConsumerState<GuruTugasScreen> {
  List<_DropdownOption> _kelasOptions = const [];
  List<_DropdownOption> _mapelOptions = const [];

  String _filterKelasId = 'all';
  String _filterMapelId = 'all';
  int _selectedSemester = 1;
  bool _isFilterVisible = true;
  bool _isContentLoading = false;

  String? get _selectedTahunAjaranId {
    return ref.read(tahunAjaranProvider).selectedTahunAjaranId;
  }

  @override
  void initState() {
    super.initState();
    widget.academicYearProvider.addListener(_handleAcademicYearChanged);
    Future.microtask(() async {
      await _loadReferenceData();
    });
  }

  @override
  void dispose() {
    widget.academicYearProvider.removeListener(_handleAcademicYearChanged);
    super.dispose();
  }

  void _handleAcademicYearChanged() {
    _loadReferenceData(forceRefreshData: true);
  }

  List<_DropdownOption> _buildMapelOptions(
    JadwalGuruFilterState jadwalState,
    JadwalGuruFilterNotifier notifier,
    String kelasFilter,
  ) {
    if (kelasFilter == 'all') {
      final map = <String, String>{};
      for (final row in jadwalState.data) {
        map[row.mapelId] = row.mapelNama;
      }

      final options =
          map.entries
              .map(
                (entry) => _DropdownOption(id: entry.key, label: entry.value),
              )
              .toList()
            ..sort((a, b) => a.label.compareTo(b.label));

      return options;
    }

    return notifier
        .getMapelByKelas(kelasFilter)
        .map((item) => _DropdownOption(id: item.id, label: item.label))
        .toList();
  }

  Future<void> _syncDropdownFromJadwal() async {
    final notifier = ref.read(jadwalGuruProvider(widget.guruUid).notifier);
    final kelasOptions = notifier
        .getAvailableKelas()
        .map((item) => _DropdownOption(id: item.id, label: item.label))
        .toList();

    var filterKelasId = _filterKelasId;
    if (filterKelasId != 'all' &&
        !kelasOptions.any((item) => item.id == filterKelasId)) {
      filterKelasId = 'all';
    }

    final jadwalState = ref.read(jadwalGuruProvider(widget.guruUid));
    final mapelOptions = _buildMapelOptions(
      jadwalState,
      notifier,
      filterKelasId,
    );

    var filterMapelId = _filterMapelId;
    if (filterMapelId != 'all' &&
        !mapelOptions.any((item) => item.id == filterMapelId)) {
      filterMapelId = 'all';
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _kelasOptions = kelasOptions;
      _mapelOptions = mapelOptions;
      _filterKelasId = filterKelasId;
      _filterMapelId = filterMapelId;
    });
  }

  Future<void> _loadReferenceData({bool forceRefreshData = false}) async {
    await ref
        .read(tahunAjaranProvider.notifier)
        .loadTahunAjaran(forceRefreshData: forceRefreshData);

    final selectedTahunAjaranId = _selectedTahunAjaranId;
    if (selectedTahunAjaranId == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _kelasOptions = const <_DropdownOption>[];
        _mapelOptions = const <_DropdownOption>[];
        _filterKelasId = 'all';
        _filterMapelId = 'all';
      });
      return;
    }

    await ref
        .read(jadwalGuruProvider(widget.guruUid).notifier)
        .loadJadwalGuruByTahunAjaran(
          selectedTahunAjaranId,
          forceRefreshData: forceRefreshData,
          forceRefreshCache: forceRefreshData,
        );

    await _syncDropdownFromJadwal();
    await _reloadTugas(forceRefreshData: forceRefreshData);
  }

  Future<void> _onTahunAjaranChanged(String? tahunAjaranId) async {
    if (tahunAjaranId == null) {
      return;
    }

    ref
        .read(tahunAjaranProvider.notifier)
        .setSelectedTahunAjaran(tahunAjaranId);

    await ref
        .read(jadwalGuruProvider(widget.guruUid).notifier)
        .loadJadwalGuruByTahunAjaran(tahunAjaranId);

    if (!mounted) {
      return;
    }

    setState(() {
      _filterKelasId = 'all';
      _filterMapelId = 'all';
      _mapelOptions = _buildMapelOptions(
        ref.read(jadwalGuruProvider(widget.guruUid)),
        ref.read(jadwalGuruProvider(widget.guruUid).notifier),
        'all',
      );
    });

    await _syncDropdownFromJadwal();
    await _reloadTugas();
  }

  void _onFilterKelasChanged(String? kelasId) {
    final value = kelasId ?? 'all';
    final notifier = ref.read(jadwalGuruProvider(widget.guruUid).notifier);
    final mapelOptions = _buildMapelOptions(
      ref.read(jadwalGuruProvider(widget.guruUid)),
      notifier,
      value,
    );

    setState(() {
      _filterKelasId = value;
      _mapelOptions = mapelOptions;
      if (_filterMapelId != 'all' &&
          !mapelOptions.any((item) => item.id == _filterMapelId)) {
        _filterMapelId = 'all';
      }
    });
  }

  Future<void> _reloadTugas({bool forceRefreshData = false}) async {
    final tahunAjaranId = _selectedTahunAjaranId;
    if (tahunAjaranId == null) {
      return;
    }

    if (mounted) {
      setState(() {
        _isContentLoading = true;
      });
    }

    try {
      await ref
          .read(tugasGuruSupabaseProvider(widget.guruUid).notifier)
          .getTugasByGuru(
            tahunAjaranId: tahunAjaranId,
            semester: _selectedSemester,
            forceRefreshData: forceRefreshData,
            forceRefreshCache: forceRefreshData,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _isContentLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isContentLoading = false;
      });
      await AppAlert.error(context, message: 'Gagal memuat tugas: $e');
    }
  }

  String _formatDate(DateTime? value) {
    if (value == null) {
      return '-';
    }
    return '${value.day}/${value.month}/${value.year}';
  }

  List<TugasGuruItem> _filteredData(List<TugasGuruItem> input) {
    return input.where((item) {
      final byKelas = _filterKelasId == 'all' || item.kelasId == _filterKelasId;
      final byMapel = _filterMapelId == 'all' || item.mapelId == _filterMapelId;
      return byKelas && byMapel;
    }).toList();
  }

  double? _parseNilaiInput(String raw, String siswaNama) {
    final text = raw.trim();
    if (text.isEmpty) {
      return null;
    }
    final value = double.tryParse(text.replaceAll(',', '.'));
    if (value == null || value < 0 || value > 100) {
      throw Exception('Nilai $siswaNama harus berupa angka 0 sampai 100.');
    }
    return value;
  }

  String _displaySiswaName(SiswaRecord siswa) {
    final nama = siswa.nama?.trim();
    if (nama != null && nama.isNotEmpty) {
      return nama;
    }
    return siswa.uid;
  }

  Future<List<_SiswaOption>> _loadSiswaOptionsByKelas(String kelasId) async {
    final masterCache = ref.read(appMasterCacheProvider);
    final siswaRecords = await masterCache.getActiveKelasSiswaRoster(
      ref.read,
      kelasId,
    );
    final activeMemberships = masterCache.getCachedKelasMembership(kelasId);
    final byUid = {for (final siswa in siswaRecords) siswa.uid: siswa};

    final options = <_SiswaOption>[];
    for (final item in activeMemberships) {
      final siswa = byUid[item.siswaId];
      if (siswa != null) {
        options.add(_SiswaOption(keanggotaan: item, siswa: siswa));
      }
    }

    options.sort(
      (a, b) => _displaySiswaName(
        a.siswa,
      ).toLowerCase().compareTo(_displaySiswaName(b.siswa).toLowerCase()),
    );
    return options;
  }

  Future<void> _showNilaiTugasDialog(TugasGuruItem item) async {
    final siswaOptions = await _loadSiswaOptionsByKelas(item.kelasId);
    if (!mounted) {
      return;
    }
    if (siswaOptions.isEmpty) {
      await AppAlert.info(
        context,
        message: 'Tidak ada siswa aktif pada kelas ${item.kelasNama}.',
      );
      return;
    }

    final notifier = ref.read(
      tugasGuruSupabaseProvider(widget.guruUid).notifier,
    );
    final existingRows = await notifier.getNilaiTugasByTugas(item.id);
    if (!mounted) {
      return;
    }
    final existingBySiswa = {for (final row in existingRows) row.siswaUid: row};
    final controllers = <String, TextEditingController>{};
    for (final siswa in siswaOptions) {
      controllers[siswa.siswa.uid] = TextEditingController(
        text: existingBySiswa[siswa.siswa.uid]?.nilai?.toString() ?? '',
      );
    }

    try {
      final shouldSave = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Nilai ${item.judulTugas}'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${item.mapelNama} - ${item.kelasNama}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...siswaOptions.map(
                      (siswa) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _displaySiswaName(siswa.siswa),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 96,
                              child: TextField(
                                controller: controllers[siswa.siswa.uid],
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(3),
                                  const _ScoreInputFormatter(),
                                ],
                                decoration: const InputDecoration(
                                  labelText: 'Nilai',
                                  hintText: '0-100',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Batal'),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(true),
                icon: const Icon(Icons.save),
                label: const Text('Simpan'),
              ),
            ],
          );
        },
      );

      if (shouldSave != true) {
        return;
      }

      final batchItems = <({String siswaId, double? nilai})>[];
      for (final siswa in siswaOptions) {
        final controller = controllers[siswa.siswa.uid];
        final existing = existingBySiswa[siswa.siswa.uid];
        final nilai = _parseNilaiInput(
          controller?.text ?? '',
          _displaySiswaName(siswa.siswa),
        );
        if (nilai == null && existing == null) {
          continue;
        }

        batchItems.add(
          (
            siswaId: siswa.siswa.uid,
            nilai: nilai,
          ),
        );
      }

      if (batchItems.isNotEmpty) {
        await notifier.upsertNilaiTugasBatch(
          tugasId: item.id,
          items: batchItems,
        );
      }

      if (!mounted) {
        return;
      }
      await _reloadTugas(forceRefreshData: true);
      if (!mounted) {
        return;
      }
      await AppAlert.success(
        context,
        title: 'Berhasil',
        message: batchItems.isEmpty
            ? 'Tidak ada nilai tugas yang diubah.'
            : 'Nilai tugas berhasil disimpan.',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      await AppAlert.error(context, message: 'Gagal menyimpan nilai tugas: $e');
    } finally {
      for (final controller in controllers.values) {
        controller.dispose();
      }
    }
  }

  Future<void> _showCreateDialog() async {
    if (_kelasOptions.isEmpty) {
      await AppAlert.error(
        context,
        message: 'Tidak ada jadwal mengajar pada tahun ajaran ini.',
      );
      return;
    }

    final tahunAjaranLabel =
        ref.read(tahunAjaranProvider).selectedOption?.nama ?? '-';

    final jadwalNotifier = ref.read(
      jadwalGuruProvider(widget.guruUid).notifier,
    );
    String? kelasId = _kelasOptions.isNotEmpty ? _kelasOptions.first.id : null;
    List<_DropdownOption> mapelByKelas = kelasId == null
        ? <_DropdownOption>[]
        : jadwalNotifier
              .getMapelByKelas(kelasId)
              .map((item) => _DropdownOption(id: item.id, label: item.label))
              .toList();
    String? mapelId = mapelByKelas.isNotEmpty ? mapelByKelas.first.id : null;
    int dialogSemester = _selectedSemester;
    final judulController = TextEditingController();
    final deskripsiController = TextEditingController();
    DateTime? deadline;

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Tambah Tugas'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Tahun Ajaran',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.school),
                      ),
                      child: Text(tahunAjaranLabel),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: dialogSemester,
                      decoration: const InputDecoration(
                        labelText: 'Semester',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_month),
                      ),
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('Semester 1')),
                        DropdownMenuItem(value: 2, child: Text('Semester 2')),
                      ],
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setStateDialog(() {
                          dialogSemester = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: kelasId,
                      decoration: const InputDecoration(labelText: 'Kelas'),
                      items: _kelasOptions
                          .map(
                            (item) => DropdownMenuItem(
                              value: item.id,
                              child: Text(item.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setStateDialog(() {
                          kelasId = value;
                          mapelByKelas = value == null
                              ? <_DropdownOption>[]
                              : jadwalNotifier
                                    .getMapelByKelas(value)
                                    .map(
                                      (item) => _DropdownOption(
                                        id: item.id,
                                        label: item.label,
                                      ),
                                    )
                                    .toList();
                          if (mapelId == null ||
                              !mapelByKelas.any((item) => item.id == mapelId)) {
                            mapelId = mapelByKelas.isNotEmpty
                                ? mapelByKelas.first.id
                                : null;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: mapelId,
                      decoration: const InputDecoration(
                        labelText: 'Mata Pelajaran',
                      ),
                      items: mapelByKelas
                          .map(
                            (item) => DropdownMenuItem(
                              value: item.id,
                              child: Text(item.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setStateDialog(() {
                          mapelId = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: judulController,
                      decoration: const InputDecoration(
                        labelText: 'Judul Tugas',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: deskripsiController,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Deskripsi'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now().add(
                            const Duration(days: 7),
                          ),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setStateDialog(() {
                            deadline = picked;
                          });
                        }
                      },
                      icon: const Icon(Icons.event),
                      label: Text(
                        deadline == null
                            ? 'Pilih Deadline'
                            : 'Deadline: ${_formatDate(deadline)}',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );

    final judul = judulController.text.trim();
    final deskripsi = deskripsiController.text.trim();
    judulController.dispose();
    deskripsiController.dispose();

    if (shouldSave != true) {
      return;
    }
    if (!mounted) {
      return;
    }

    final selectedKelasId = kelasId;
    final selectedMapelId = mapelId;

    if (selectedKelasId == null ||
        selectedMapelId == null ||
        judul.isEmpty ||
        deskripsi.isEmpty) {
      await AppAlert.error(
        context,
        message: 'Lengkapi kelas, mapel, judul, dan deskripsi.',
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
        .isPairValid(kelasId: selectedKelasId, mapelId: selectedMapelId);
    if (!pairValid) {
      await AppAlert.error(
        context,
        message: 'Kelas dan mata pelajaran tidak sesuai jadwal mengajar guru.',
      );
      return;
    }

    try {
      await ref
          .read(tugasGuruSupabaseProvider(widget.guruUid).notifier)
          .createTugas(
            kelasId: selectedKelasId,
            mapelId: selectedMapelId,
            tahunAjaranId: tahunAjaranId,
            semester: dialogSemester,
            judul: judul,
            deskripsi: deskripsi,
            deadline: deadline,
          );
      await _reloadTugas(forceRefreshData: true);

      if (!mounted) {
        return;
      }
      await AppAlert.success(
        context,
        title: 'Berhasil',
        message: 'Tugas berhasil dibuat.',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      await AppAlert.error(context, message: 'Gagal membuat tugas: $e');
    }
  }

  Future<void> _showEditDialog(TugasGuruItem item) async {
    final judulController = TextEditingController(text: item.judulTugas);
    final deskripsiController = TextEditingController(text: item.deskripsi);
    DateTime? deadline = item.deadline;

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Edit Tugas'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: judulController,
                      decoration: const InputDecoration(
                        labelText: 'Judul Tugas',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: deskripsiController,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Deskripsi'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: deadline ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setStateDialog(() {
                            deadline = picked;
                          });
                        }
                      },
                      icon: const Icon(Icons.event),
                      label: Text('Deadline: ${_formatDate(deadline)}'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );

    final judul = judulController.text.trim();
    final deskripsi = deskripsiController.text.trim();
    judulController.dispose();
    deskripsiController.dispose();

    if (shouldSave != true) {
      return;
    }
    if (!mounted) {
      return;
    }

    if (judul.isEmpty || deskripsi.isEmpty) {
      await AppAlert.error(
        context,
        message: 'Judul dan deskripsi wajib diisi.',
      );
      return;
    }

    try {
      await ref
          .read(tugasGuruSupabaseProvider(widget.guruUid).notifier)
          .updateTugas(
            tugasId: item.id,
            tahunAjaranId: item.tahunAjaranId,
            semester: item.semester,
            judul: judul,
            deskripsi: deskripsi,
            deadline: deadline,
          );
      await _reloadTugas(forceRefreshData: true);

      if (!mounted) {
        return;
      }
      await AppAlert.success(
        context,
        title: 'Berhasil',
        message: 'Tugas berhasil diperbarui.',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      await AppAlert.error(context, message: 'Gagal memperbarui tugas: $e');
    }
  }

  Future<void> _deleteTugas(TugasGuruItem item) async {
    final shouldDelete = await AppAlert.confirm(
      context,
      title: 'Hapus tugas ini?',
      message: 'Data yang dihapus tidak dapat dikembalikan.',
      okText: 'Ya, hapus',
      cancelText: 'Batal',
    );

    if (!shouldDelete) {
      return;
    }

    try {
      await ref
          .read(tugasGuruSupabaseProvider(widget.guruUid).notifier)
          .softDeleteTugas(
            tugasId: item.id,
            tahunAjaranId: item.tahunAjaranId,
            semester: item.semester,
          );

      if (!mounted) {
        return;
      }
      await AppAlert.success(
        context,
        title: 'Berhasil',
        message: 'Tugas berhasil dihapus.',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      await AppAlert.error(context, message: 'Gagal menghapus tugas: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tugasGuruSupabaseProvider(widget.guruUid));
    final jadwalState = ref.watch(jadwalGuruProvider(widget.guruUid));
    final tahunAjaranState = ref.watch(tahunAjaranProvider);
    final visibleData = _filteredData(state.data);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tugas'),
        actions: [
          IconButton(
            onPressed: () => _loadReferenceData(forceRefreshData: true),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _reloadTugas(forceRefreshData: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (state.isLoading) const LinearProgressIndicator(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      if (tahunAjaranState.isLoading)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: LinearProgressIndicator(minHeight: 2),
                        ),
                      if (tahunAjaranState.error != null &&
                          tahunAjaranState.error!.isNotEmpty)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.error.withAlpha(20),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.error.withAlpha(70),
                            ),
                          ),
                          child: Text(
                            tahunAjaranState.error!,
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
                            border: Border.all(
                              color: AppColors.error.withAlpha(70),
                            ),
                          ),
                          child: const Text(
                            'Tidak ada jadwal mengajar pada tahun ajaran ini',
                            style: TextStyle(color: AppColors.error),
                          ),
                        ),
                      AppExternalFilterBar(
                        margin: EdgeInsets.zero,
                        isExpanded: _isFilterVisible,
                        onToggle: () {
                          setState(() {
                            _isFilterVisible = !_isFilterVisible;
                          });
                        },
                        onReset: () async {
                          setState(() {
                            _filterKelasId = 'all';
                            _filterMapelId = 'all';
                            _selectedSemester = 1;
                          });
                          await _reloadTugas();
                        },
                        onApply: _reloadTugas,
                        isBusy: state.isLoading,
                        children: [
                          AppExternalFilterField(
                            label: 'Tahun Ajaran',
                            minWidth: 250,
                            child: DropdownButtonFormField<String>(
                              initialValue:
                                  tahunAjaranState.selectedTahunAjaranId,
                              decoration: appExternalFilterDecoration(
                                hintText: 'Pilih tahun ajaran',
                                icon: Icons.school_rounded,
                              ),
                              items: tahunAjaranState.options
                                  .map(
                                    (item) => DropdownMenuItem<String>(
                                      value: item.id,
                                      child: Text(item.nama),
                                    ),
                                  )
                                  .toList(),
                              onChanged: _onTahunAjaranChanged,
                            ),
                          ),
                          AppExternalFilterField(
                            label: 'Kelas',
                            minWidth: 250,
                            child: DropdownButtonFormField<String>(
                              initialValue: _filterKelasId,
                              decoration: appExternalFilterDecoration(
                                hintText: 'Semua kelas',
                                icon: Icons.class_rounded,
                              ),
                              items: [
                                const DropdownMenuItem(
                                  value: 'all',
                                  child: Text('Semua Kelas'),
                                ),
                                ..._kelasOptions.map(
                                  (item) => DropdownMenuItem(
                                    value: item.id,
                                    child: Text(item.label),
                                  ),
                                ),
                              ],
                              onChanged: _onFilterKelasChanged,
                            ),
                          ),
                          AppExternalFilterField(
                            label: 'Mata Pelajaran',
                            minWidth: 250,
                            child: DropdownButtonFormField<String>(
                              initialValue: _filterMapelId,
                              decoration: appExternalFilterDecoration(
                                hintText: 'Semua mata pelajaran',
                                icon: Icons.menu_book_rounded,
                              ),
                              items: [
                                const DropdownMenuItem(
                                  value: 'all',
                                  child: Text('Semua Mata Pelajaran'),
                                ),
                                ..._mapelOptions.map(
                                  (item) => DropdownMenuItem(
                                    value: item.id,
                                    child: Text(item.label),
                                  ),
                                ),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _filterMapelId = value ?? 'all';
                                });
                              },
                            ),
                          ),
                          AppExternalFilterField(
                            label: 'Semester',
                            minWidth: 250,
                            child: DropdownButtonFormField<int>(
                              initialValue: _selectedSemester,
                              decoration: appExternalFilterDecoration(
                                hintText: 'Pilih semester',
                                icon: Icons.calendar_month_rounded,
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 1,
                                  child: Text('Semester 1'),
                                ),
                                DropdownMenuItem(
                                  value: 2,
                                  child: Text('Semester 2'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value == null) {
                                  return;
                                }
                                setState(() {
                                  _selectedSemester = value;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_isContentLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (visibleData.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 72),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.assignment_outlined,
                        size: 80,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Belum ada tugas',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: visibleData.length,
                itemBuilder: (context, index) {
                  final item = visibleData[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Text(item.judulTugas),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item.mapelNama} - ${item.kelasNama}\n'
                            'Deskripsi: ${item.deskripsi}\n'
                            'Deadline: ${_formatDate(item.deadline)}',
                          ),
                          const SizedBox(height: 8),
                          _buildPenilaianStatus(item),
                        ],
                      ),
                      isThreeLine: true,
                      trailing: SizedBox(
                        width: 144,
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.fact_check_outlined),
                                onPressed: () => _showNilaiTugasDialog(item),
                                tooltip: 'Nilai Tugas',
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => _showEditDialog(item),
                                tooltip: 'Edit',
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: AppColors.error,
                                ),
                                onPressed: () => _deleteTugas(item),
                                tooltip: 'Hapus',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  state.error!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
        tooltip: 'Tambah Tugas',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildPenilaianStatus(TugasGuruItem item) {
    final hasUngraded = item.belumDinilaiCount > 0;
    final color = hasUngraded ? AppColors.warning : AppColors.success;
    final label = item.totalSiswa == 0
        ? 'Belum ada siswa aktif'
        : hasUngraded
        ? '${item.belumDinilaiCount} siswa belum dinilai'
        : 'Semua siswa sudah dinilai';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(90)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasUngraded ? Icons.warning_amber_rounded : Icons.check_circle,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '$label (${item.totalDinilai}/${item.totalSiswa})',
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
