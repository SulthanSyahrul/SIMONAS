import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/auth_session_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_external_filter_bar.dart';
import '../../../../models/absensi_jurnal_model.dart';
import '../../../../providers/supabase_providers.dart';
import '../../../shared/providers/shared_academic_context_provider.dart';
import '../../widgets/app_alert.dart';
import '../../providers/jurnal_monitoring_provider.dart';
import '../detail_jurnal_screen.dart';

/// Tab history jurnal dengan filter tanggal, guru, dan kelas.
class HistoryTab extends ConsumerStatefulWidget {
  const HistoryTab({super.key});

  @override
  ConsumerState<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends ConsumerState<HistoryTab> {
  bool _isFilterVisible = true;
  late String _selectedTahunAjaran;
  String _selectedSemester = 'Semua Semester';
  int? _selectedJamKe;
  bool _canManageJurnal = false;
  bool _isBootstrapped = false;

  @override
  void initState() {
    super.initState();
    // Initialize with first available tahun ajaran
    _selectedTahunAjaran = 'Semua Tahun Ajaran';
    Future.microtask(() async {
      await _resolveRolePermission();
      if (!mounted || _isBootstrapped) {
        return;
      }
      _isBootstrapped = true;
      await ref.read(historyJurnalMonitoringProvider.notifier).loadData();
    });
  }

  Future<void> _resolveRolePermission() async {
    final session = await AuthSessionService().getValidSession();
    final normalizedRole = (session?.role ?? '').trim().toLowerCase();
    final isKepsek =
        normalizedRole == 'kepala_sekolah' ||
        normalizedRole == 'kepala sekolah' ||
        normalizedRole == 'kepsek';

    if (!mounted) {
      return;
    }

    setState(() {
      _canManageJurnal = isKepsek;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Set active tahun ajaran as default when data loads
    final state = ref.read(historyJurnalMonitoringProvider);
    if (state.activeTahunAjaranName != null &&
        state.activeTahunAjaranName!.isNotEmpty &&
        _selectedTahunAjaran == 'Semua Tahun Ajaran') {
      setState(() {
        _selectedTahunAjaran = state.activeTahunAjaranName!;
      });
    }
  }

  Future<void> _pickDate(DateTime initialDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      await ref.read(historyJurnalMonitoringProvider.notifier).setDate(picked);
    }
  }

  void _viewDetail(JurnalMonitoringItem jurnal) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            DetailJurnalScreen(jurnalData: jurnal.toDisplayMap()),
      ),
    );
  }

  Future<void> _editJurnal(JurnalMonitoringItem jurnal) async {
    if (!_canManageJurnal) {
      await AppAlert.info(
        context,
        title: 'Akses Ditolak',
        message: 'Fitur ini hanya untuk Kepala Sekolah.',
      );
      return;
    }

    final state = ref.read(historyJurnalMonitoringProvider);
    if (state.kelasOptions.length <= 1 || state.mapelOptions.isEmpty) {
      await AppAlert.error(
        context,
        title: 'Gagal',
        message: 'Data kelas atau mata pelajaran belum tersedia.',
      );
      return;
    }

    final editableAbsensi = await _loadEditableAbsensiRows(jurnal);

    final payload = await _showEditJurnalDialog(jurnal, state, editableAbsensi);
    if (payload == null) {
      return;
    }

    try {
      await ref
          .read(historyJurnalMonitoringProvider.notifier)
          .updateJurnalDanAbsensiByKepsek(
            jurnalId: jurnal.id,
            kelasId: payload.kelasId,
            mataPelajaranId: payload.mapelId,
            tanggal: payload.tanggal,
            jamAwal: payload.jamAwal,
            jamAkhir: payload.jamAkhir,
            materi: payload.materi,
            catatan: payload.catatan,
            statusKehadiran: payload.statusKehadiran,
            absensi: payload.absensi
                .map(
                  (row) => KepsekAbsensiEditDraft(
                    siswaId: row.siswaId,
                    statusKehadiran: row.status,
                    catatan: row.catatan,
                  ),
                )
                .toList(growable: false),
          );

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

      await AppAlert.error(
        context,
        title: 'Gagal',
        message: 'Gagal memperbarui data jurnal.',
      );
    }
  }

  Future<void> _forceDeleteJurnal(JurnalMonitoringItem jurnal) async {
    if (!_canManageJurnal) {
      await AppAlert.info(
        context,
        title: 'Akses Ditolak',
        message: 'Fitur ini hanya untuk Kepala Sekolah.',
      );
      return;
    }

    final confirmed = await AppAlert.confirm(
      context,
      title: 'Peringatan',
      message:
          'Hapus permanen data jurnal ini?\nData tidak dapat dikembalikan.',
      okText: 'Ya, Hapus',
      cancelText: 'Batal',
    );

    if (!confirmed) {
      return;
    }

    try {
      await ref
          .read(historyJurnalMonitoringProvider.notifier)
          .forceDeleteJurnalByKepsek(jurnal.id);

      if (!mounted) {
        return;
      }

      await AppAlert.success(
        context,
        title: 'Berhasil',
        message: 'Data jurnal berhasil dihapus permanen.',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      await AppAlert.error(
        context,
        title: 'Gagal',
        message: 'Gagal menghapus data jurnal.',
      );
    }
  }

  Future<_EditJurnalPayload?> _showEditJurnalDialog(
    JurnalMonitoringItem jurnal,
    JurnalMonitoringState state,
    List<_EditAbsensiRow> absensiRows,
  ) async {
    final formKey = GlobalKey<FormState>();
    final materiController = TextEditingController(text: jurnal.materi);
    final catatanController = TextEditingController(text: jurnal.catatan ?? '');

    String selectedKelasId = jurnal.kelasId;
    String selectedMapelId = jurnal.mataPelajaranId;
    DateTime selectedTanggal = jurnal.tanggal ?? DateTime.now();
    int selectedJamAwal = jurnal.jamAwal;
    int selectedJamAkhir = jurnal.jamAkhir;
    String selectedStatus = _normalizeStatus(jurnal.statusKehadiran);

    final allKelas = state.kelasOptions
        .where((item) => item.id != 'all')
        .toList(growable: false);
    final allMapel = state.mapelOptions;

    final statusOptions = <String>{
      'Hadir',
      'Masuk',
      'Izin',
      'Sakit',
      'Alpa',
      selectedStatus,
    }.toList();

    final result = await showDialog<_EditJurnalPayload>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Jurnal'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue:
                            allKelas.any((x) => x.id == selectedKelasId)
                            ? selectedKelasId
                            : (allKelas.isNotEmpty ? allKelas.first.id : null),
                        decoration: const InputDecoration(labelText: 'Kelas'),
                        items: allKelas
                            .map(
                              (item) => DropdownMenuItem<String>(
                                value: item.id,
                                child: Text(item.label),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() {
                              selectedKelasId = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue:
                            allMapel.any((x) => x.id == selectedMapelId)
                            ? selectedMapelId
                            : (allMapel.isNotEmpty ? allMapel.first.id : null),
                        decoration: const InputDecoration(
                          labelText: 'Mata Pelajaran',
                        ),
                        items: allMapel
                            .map(
                              (item) => DropdownMenuItem<String>(
                                value: item.id,
                                child: Text(item.label),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() {
                              selectedMapelId = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: dialogContext,
                            initialDate: selectedTanggal,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              selectedTanggal = DateTime(
                                picked.year,
                                picked.month,
                                picked.day,
                              );
                            });
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Tanggal',
                            border: OutlineInputBorder(),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                '${selectedTanggal.day}/${selectedTanggal.month}/${selectedTanggal.year}',
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<int>(
                        initialValue: selectedJamAwal,
                        decoration: const InputDecoration(labelText: 'Jam Awal'),
                        items: List.generate(
                          8,
                          (index) => DropdownMenuItem<int>(
                            value: index + 1,
                            child: Text('Jam ${index + 1}'),
                          ),
                        ),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() {
                              selectedJamAwal = value;
                              if (selectedJamAkhir < selectedJamAwal) {
                                selectedJamAkhir = selectedJamAwal;
                              }
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<int>(
                        initialValue: selectedJamAkhir,
                        decoration: const InputDecoration(labelText: 'Jam Akhir'),
                        items: List.generate(
                          9 - selectedJamAwal,
                          (index) => DropdownMenuItem<int>(
                            value: selectedJamAwal + index,
                            child: Text('Jam ${selectedJamAwal + index}'),
                          ),
                        ),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() {
                              selectedJamAkhir = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: materiController,
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: 'Materi'),
                        validator: (value) {
                          if ((value ?? '').trim().isEmpty) {
                            return 'Materi wajib diisi';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: catatanController,
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: 'Catatan'),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: statusOptions.contains(selectedStatus)
                            ? selectedStatus
                            : statusOptions.first,
                        decoration: const InputDecoration(
                          labelText: 'Status Kehadiran',
                        ),
                        items: statusOptions
                            .map(
                              (status) => DropdownMenuItem<String>(
                                value: status,
                                child: Text(status),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() {
                              selectedStatus = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Presensi Siswa',
                          style: Theme.of(dialogContext).textTheme.titleSmall,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (absensiRows.isEmpty)
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Data presensi belum tersedia.'),
                        )
                      else
                        ...absensiRows.map((row) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(child: Text(row.siswaNama)),
                                const SizedBox(width: 8),
                                DropdownButton<String>(
                                  value: row.status,
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
                                  onChanged: (value) {
                                    if (value == null) {
                                      return;
                                    }
                                    setDialogState(() {
                                      row.status = value;
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
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (!(formKey.currentState?.validate() ?? false)) {
                      return;
                    }

                    Navigator.of(dialogContext).pop(
                      _EditJurnalPayload(
                        kelasId: selectedKelasId,
                        mapelId: selectedMapelId,
                        tanggal: selectedTanggal,
                        jamAwal: selectedJamAwal,
                        jamAkhir: selectedJamAkhir,
                        materi: materiController.text.trim(),
                        catatan: catatanController.text.trim(),
                        statusKehadiran: selectedStatus,
                        absensi: absensiRows,
                      ),
                    );
                  },
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );

    materiController.dispose();
    catatanController.dispose();
    return result;
  }

  Future<List<_EditAbsensiRow>> _loadEditableAbsensiRows(
    JurnalMonitoringItem jurnal,
  ) async {
    final absensiService = ref.read(absensiJurnalServiceProvider);
    final masterCache = ref.read(appMasterCacheProvider);

    final existingRows = await absensiService.getByJurnalId(jurnal.id);
    final existingBySiswaId = <String, AbsensiJurnalRecord>{
      for (final row in existingRows)
        if (row.siswaId.trim().isNotEmpty) row.siswaId: row,
    };

    final siswaUsers = await masterCache.getActiveKelasSiswaRoster(
      ref.read,
      jurnal.kelasId,
    );
    final activeMembers = masterCache.getCachedKelasMembership(jurnal.kelasId);
    final siswaByUid = {for (final user in siswaUsers) user.uid: user};

    final rows = <_EditAbsensiRow>[];
    for (final item in activeMembers) {
      final siswaId = item.siswaId;
      final user = siswaByUid[siswaId];
      final existing = existingBySiswaId[siswaId];
      rows.add(
        _EditAbsensiRow(
          siswaId: siswaId,
          siswaNama: user?.nama?.trim().isNotEmpty == true
              ? user!.nama!.trim()
              : siswaId,
          status: _normalizeSiswaStatus(existing?.statusKehadiran ?? 'hadir'),
          catatan: existing?.catatan,
        ),
      );
    }

    for (final existing in existingRows) {
      if (rows.any((row) => row.siswaId == existing.siswaId)) {
        continue;
      }
      rows.add(
        _EditAbsensiRow(
          siswaId: existing.siswaId,
          siswaNama:
              existing.siswaNama?.trim().isNotEmpty == true
              ? existing.siswaNama!.trim()
              : ((siswaByUid[existing.siswaId]?.nama?.trim().isNotEmpty ==
                          true)
                      ? siswaByUid[existing.siswaId]!.nama!.trim()
                      : existing.siswaId),
          status: _normalizeSiswaStatus(existing.statusKehadiran),
          catatan: existing.catatan,
        ),
      );
    }

    rows.sort(
      (a, b) => a.siswaNama.toLowerCase().compareTo(b.siswaNama.toLowerCase()),
    );
    return rows;
  }

  String _normalizeSiswaStatus(String raw) {
    switch (raw.trim().toLowerCase()) {
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

  String _normalizeStatus(String raw) {
    final value = raw.trim().toLowerCase();
    switch (value) {
      case 'hadir':
        return 'Hadir';
      case 'masuk':
        return 'Masuk';
      case 'izin':
        return 'Izin';
      case 'sakit':
        return 'Sakit';
      case 'alpa':
      case 'alpha':
        return 'Alpa';
      default:
        return raw.trim().isEmpty ? 'Hadir' : raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(historyJurnalMonitoringProvider);

    final tahunAjaranList = ['Semua Tahun Ajaran', ...state.tahunAjaranOptions];

    final semesterList = const ['Semua Semester', 'Semester 1', 'Semester 2'];

    final effectiveTahunAjaran = tahunAjaranList.contains(_selectedTahunAjaran)
        ? _selectedTahunAjaran
        : 'Semua Tahun Ajaran';
    final effectiveSemester = semesterList.contains(_selectedSemester)
        ? _selectedSemester
        : 'Semua Semester';

    final filteredList = state.data.where((jurnal) {
      if (effectiveTahunAjaran != 'Semua Tahun Ajaran' &&
          jurnal.tahunAjaranName != effectiveTahunAjaran) {
        return false;
      }
      if (effectiveSemester != 'Semua Semester' &&
          'Semester ${jurnal.semester}' != effectiveSemester) {
        return false;
      }
      if (_selectedJamKe != null &&
          !(_selectedJamKe! >= jurnal.jamAwal &&
              _selectedJamKe! <= jurnal.jamAkhir)) {
        return false;
      }
      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(historyJurnalMonitoringProvider.notifier).refresh();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          AppExternalFilterBar(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            isExpanded: _isFilterVisible,
            onToggle: () {
              setState(() {
                _isFilterVisible = !_isFilterVisible;
              });
            },
            onReset: () async {
              setState(() {
                _selectedTahunAjaran =
                    state.activeTahunAjaranName ?? 'Semua Tahun Ajaran';
                _selectedSemester = 'Semua Semester';
                _selectedJamKe = null;
              });
              await ref
                  .read(historyJurnalMonitoringProvider.notifier)
                  .setShowAllDates(true);
              await ref
                  .read(historyJurnalMonitoringProvider.notifier)
                  .setKelasId('all');
              await ref
                  .read(historyJurnalMonitoringProvider.notifier)
                  .setGuruId('all');
            },
            onApply: () => setState(() {}),
            isBusy: state.isLoading,
            children: [
              SizedBox(
                width: 240,
                child: _buildStringDropdown(
                  label: 'Tahun Ajaran',
                  value: effectiveTahunAjaran,
                  items: tahunAjaranList,
                  onChanged: (value) {
                    setState(() {
                      _selectedTahunAjaran = value ?? 'Semua Tahun Ajaran';
                    });
                  },
                ),
              ),
              SizedBox(
                width: 240,
                child: _buildStringDropdown(
                  label: 'Semester',
                  value: effectiveSemester,
                  items: semesterList,
                  onChanged: (value) {
                    setState(() {
                      _selectedSemester = value ?? 'Semua Semester';
                    });
                  },
                ),
              ),
              SizedBox(
                width: 240,
                child: SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text(
                    'Semua Tanggal',
                    style: TextStyle(fontSize: 13),
                  ),
                  value: state.showAllDates,
                  onChanged: (value) {
                    ref
                        .read(historyJurnalMonitoringProvider.notifier)
                        .setShowAllDates(value);
                  },
                ),
              ),
              SizedBox(
                width: 240,
                child: InkWell(
                  onTap: state.showAllDates
                      ? null
                      : () => _pickDate(state.selectedDate),
                  borderRadius: BorderRadius.circular(14),
                  child: InputDecorator(
                    decoration: appExternalFilterDecoration(
                      hintText: 'Pilih tanggal',
                      icon: Icons.calendar_today_rounded,
                    ),
                    child: Text(
                      state.showAllDates
                          ? 'Semua Tanggal'
                          : '${state.selectedDate.day}/${state.selectedDate.month}/${state.selectedDate.year}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 240,
                child: _buildOptionDropdown(
                  label: 'Kelas',
                  value: state.selectedKelasId,
                  items: state.kelasOptions,
                  onChanged: (value) {
                    if (value != null) {
                      ref
                          .read(historyJurnalMonitoringProvider.notifier)
                          .setKelasId(value);
                    }
                  },
                ),
              ),
              SizedBox(
                width: 240,
                child: _buildStringDropdown(
                  label: 'Jam Ke',
                  value: _selectedJamKe == null ? 'Semua Jam' : 'Jam $_selectedJamKe',
                  items: const [
                    'Semua Jam',
                    'Jam 1',
                    'Jam 2',
                    'Jam 3',
                    'Jam 4',
                    'Jam 5',
                    'Jam 6',
                    'Jam 7',
                    'Jam 8',
                  ],
                  onChanged: (value) {
                    setState(() {
                      if (value == null || value == 'Semua Jam') {
                        _selectedJamKe = null;
                      } else {
                        _selectedJamKe = int.tryParse(value.replaceAll('Jam ', ''));
                      }
                    });
                  },
                ),
              ),
              SizedBox(
                width: 240,
                child: _buildOptionDropdown(
                  label: 'Guru',
                  value: state.selectedGuruId,
                  items: state.guruOptions,
                  onChanged: (value) {
                    if (value != null) {
                      ref
                          .read(historyJurnalMonitoringProvider.notifier)
                          .setGuruId(value);
                    }
                  },
                ),
              ),
            ],
          ),
          const Divider(height: 1),
          if (state.error != null && state.error!.isNotEmpty)
            Container(
              width: double.infinity,
              color: AppColors.error.withAlpha(20),
              padding: const EdgeInsets.all(12),
              child: Text(
                state.error!,
                style: const TextStyle(color: AppColors.error, fontSize: 12),
              ),
            ),
          if (state.isLoading && filteredList.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 120),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (filteredList.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 120),
              child: Center(
                child: Text(
                  'Tidak ada jurnal pada filter ini',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            Column(
              children: [
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredList.length,
                  itemBuilder: (context, index) {
                    final jurnal = filteredList[index];
                    return _buildJurnalCard(jurnal);
                  },
                ),
                if (state.isLoadingMore)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 20),
                    child: CircularProgressIndicator(),
                  )
                else if (state.hasMoreData)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          ref
                              .read(historyJurnalMonitoringProvider.notifier)
                              .loadMore();
                        },
                        icon: const Icon(Icons.expand_more),
                        label: const Text('Muat Lebih Banyak'),
                      ),
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.only(bottom: 20),
                    child: Text(
                      'Semua data histori sudah dimuat',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildJurnalCard(JurnalMonitoringItem jurnal) {
    final statusLower = jurnal.statusKehadiran.toLowerCase();
    final statusColor = statusLower == 'masuk'
        ? AppColors.success
        : (statusLower == 'izin' ? AppColors.warning : AppColors.info);
    final tanggal = jurnal.tanggal ?? DateTime.now();

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statusColor, width: 2),
      ),
      child: InkWell(
        onTap: () => _viewDetail(jurnal),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          jurnal.mataPelajaran,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Kelas ${jurnal.kelasName}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(26),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      jurnal.statusKehadiran,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              _buildInfoRow(Icons.person, jurnal.guruName),
              const SizedBox(height: 6),
              _buildInfoRow(
                Icons.calendar_today,
                '${tanggal.day}/${tanggal.month}/${tanggal.year}',
              ),
              const SizedBox(height: 6),
              _buildInfoRow(Icons.access_time, jurnal.jamLabel),
              const SizedBox(height: 6),
              _buildInfoRow(Icons.school, jurnal.tahunAjaranName),
              const SizedBox(height: 6),
              _buildInfoRow(Icons.event_note, 'Semester ${jurnal.semester}'),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildActionButton(
                      icon: Icons.visibility,
                      label: 'Lihat Detail',
                      color: AppColors.primary,
                      onPressed: () => _viewDetail(jurnal),
                    ),
                    if (_canManageJurnal)
                      _buildActionButton(
                        icon: Icons.edit,
                        label: 'Edit',
                        color: AppColors.warning,
                        onPressed: () => _editJurnal(jurnal),
                        tooltip: 'Edit Jurnal',
                      ),
                    if (_canManageJurnal)
                      _buildActionButton(
                        icon: Icons.delete,
                        label: 'Hapus',
                        color: AppColors.error,
                        onPressed: () => _forceDeleteJurnal(jurnal),
                        tooltip: 'Hapus Permanen',
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
    String? tooltip,
  }) {
    final button = OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.all(color),
        side: WidgetStateProperty.all(BorderSide(color: color)),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        minimumSize: WidgetStateProperty.all(Size.zero),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: WidgetStateProperty.all(const StadiumBorder()),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) {
            return color.withAlpha(28);
          }
          if (states.contains(WidgetState.pressed)) {
            return color.withAlpha(46);
          }
          return color.withAlpha(18);
        }),
      ),
    );

    if (tooltip == null || tooltip.trim().isEmpty) {
      return button;
    }

    return Tooltip(message: tooltip, child: button);
  }

  Widget _buildStringDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              items: items
                  .map(
                    (item) => DropdownMenuItem<String>(
                      value: item,
                      child: Text(item),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOptionDropdown({
    required String label,
    required String value,
    required List<JurnalFilterOption> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              items: items
                  .map(
                    (item) => DropdownMenuItem<String>(
                      value: item.id,
                      child: Text(item.label),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

class _EditJurnalPayload {
  final String kelasId;
  final String mapelId;
  final DateTime tanggal;
  final int jamAwal;
  final int jamAkhir;
  final String materi;
  final String? catatan;
  final String statusKehadiran;
  final List<_EditAbsensiRow> absensi;

  const _EditJurnalPayload({
    required this.kelasId,
    required this.mapelId,
    required this.tanggal,
    required this.jamAwal,
    required this.jamAkhir,
    required this.materi,
    required this.catatan,
    required this.statusKehadiran,
    required this.absensi,
  });
}

class _EditAbsensiRow {
  final String siswaId;
  final String siswaNama;
  final String? catatan;
  String status;

  _EditAbsensiRow({
    required this.siswaId,
    required this.siswaNama,
    required this.status,
    required this.catatan,
  });
}
