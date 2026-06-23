import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_external_filter_bar.dart';
import '../../../models/tahun_ajaran_model.dart';
import '../../../models/model_utils.dart';
import '../widgets/app_alert.dart';
import '../providers/manajemen_akademik_provider.dart';

class JadwalGuruTab extends ConsumerStatefulWidget {
  final String selectedTahunAjaran;
  final String tahunAjaranId;
  final List<TahunAjaranRecord> tahunAjaranOptions;
  final ValueChanged<String> onTahunAjaranChanged;

  const JadwalGuruTab({
    super.key,
    required this.selectedTahunAjaran,
    required this.tahunAjaranId,
    required this.tahunAjaranOptions,
    required this.onTahunAjaranChanged,
  });

  @override
  ConsumerState<JadwalGuruTab> createState() => _JadwalGuruTabState();
}

class _JadwalGuruTabState extends ConsumerState<JadwalGuruTab> {
  static const List<String> _hariList = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
  ];
  static const String _semuaHari = 'Semua Hari';

  bool _isSavingAction = false;
  bool _isFilterVisible = true;
  int? _filterSemester;
  String _filterHari = _semuaHari;
  String? _filterKelasId;
  String? _filterGuruUid;

  @override
  void didUpdateWidget(covariant JadwalGuruTab oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.tahunAjaranId != widget.tahunAjaranId) {
      _filterSemester = null;
      _filterHari = _semuaHari;
      _filterKelasId = null;
      _filterGuruUid = null;
    }
  }

  Future<void> _refresh() async {
    await ref
        .read(jadwalGuruManagementProvider(widget.tahunAjaranId).notifier)
        .loadData(forceRefreshData: true);
  }

  Future<void> _onTambahJadwal() async {
    final payload = await _showJadwalFormDialog();
    if (payload == null) {
      return;
    }

    try {
      setState(() {
        _isSavingAction = true;
      });

      final result = await ref
          .read(jadwalGuruManagementProvider(widget.tahunAjaranId).notifier)
          .createJadwalRange(
            guruUid: payload['guru_uid'] as String,
            kelasId: payload['kelas_id'] as String,
            mapelId: payload['mapel_id'] as String,
            hari: payload['hari'] as String,
            jamMulai: payload['jam_mulai'] as int,
            jamSelesai: payload['jam_selesai'] as int,
            semester: payload['semester'] as int,
          );

      if (!mounted) {
        return;
      }

      final parts = <String>[];
      if (result.createdJams.isNotEmpty) {
        parts.add('Berhasil: ${result.createdJams.join(', ')}');
      }
      if (result.skippedJams.isNotEmpty) {
        parts.add('Duplikat dilewati: ${result.skippedJams.join(', ')}');
      }

      _showSuccess(
        parts.isEmpty
            ? 'Tidak ada jadwal baru yang ditambahkan.'
            : parts.join(' | '),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isSavingAction = false;
        });
      }
    }
  }

  Future<void> _onEditJadwal(JadwalManajemenItem item) async {
    final oldRange = (mulai: item.jamAwal, selesai: item.jamAkhir);

    final payload = await _showJadwalFormDialog(
      initial: item,
      initialJamMulai: oldRange.mulai,
      initialJamSelesai: oldRange.selesai,
    );
    if (payload == null) {
      return;
    }

    try {
      setState(() {
        _isSavingAction = true;
      });

      final result = await ref
          .read(jadwalGuruManagementProvider(widget.tahunAjaranId).notifier)
          .updateJadwalRange(
            jadwalId: item.id,
            oldGuruUid: item.guruUid,
            oldKelasId: item.kelasId,
            oldMapelId: item.mapelId,
            oldHari: item.hari,
            oldSemester: item.semester,
            oldJamMulai: oldRange.mulai,
            oldJamSelesai: oldRange.selesai,
            guruUid: payload['guru_uid'] as String,
            kelasId: payload['kelas_id'] as String,
            mapelId: payload['mapel_id'] as String,
            hari: payload['hari'] as String,
            jamMulai: payload['jam_mulai'] as int,
            jamSelesai: payload['jam_selesai'] as int,
            semester: payload['semester'] as int,
          );

      if (!mounted) {
        return;
      }

      final parts = <String>[];
      if (result.updatedJams.isNotEmpty) {
        parts.add('Diupdate: ${result.updatedJams.join(', ')}');
      }
      if (result.createdJams.isNotEmpty) {
        parts.add('Ditambah: ${result.createdJams.join(', ')}');
      }
      if (result.deletedJams.isNotEmpty) {
        parts.add('Dihapus: ${result.deletedJams.join(', ')}');
      }
      if (result.skippedJams.isNotEmpty) {
        parts.add('Duplikat dilewati: ${result.skippedJams.join(', ')}');
      }

      _showSuccess(
        parts.isEmpty ? 'Tidak ada perubahan jadwal.' : parts.join(' | '),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isSavingAction = false;
        });
      }
    }
  }

  Future<void> _onDeleteJadwal(JadwalManajemenItem item) async {
    final confirmed = await AppAlert.confirm(
      context,
      title: 'Hapus Jadwal',
      message:
          'Hapus jadwal ${item.guruName} pada ${item.hari} jam ke-${item.jamAwal} s.d. ke-${item.jamAkhir} (${ModelUtils.getWaktuMulai(item.jamAwal) ?? '--:--'} - ${ModelUtils.getWaktuSelesai(item.jamAkhir) ?? '--:--'})?',
    );

    if (!confirmed) {
      return;
    }

    try {
      await ref
          .read(jadwalGuruManagementProvider(widget.tahunAjaranId).notifier)
          .deleteJadwal(item.id);

      if (!mounted) {
        return;
      }
      _showSuccess('Jadwal berhasil dihapus.');
    } catch (e) {
      if (!mounted) {
        return;
      }
      _showError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<Map<String, dynamic>?> _showJadwalFormDialog({
    JadwalManajemenItem? initial,
    int? initialJamMulai,
    int? initialJamSelesai,
  }) async {
    final state = ref.read(jadwalGuruManagementProvider(widget.tahunAjaranId));

    if (state.guruOptions.isEmpty ||
        state.kelasOptions.isEmpty ||
        state.mapelOptions.isEmpty) {
      _showError(
        'Data guru, kelas, atau mapel belum tersedia. Pastikan master data sudah diisi.',
      );
      return null;
    }

    String? selectedGuruUid = initial?.guruUid ?? state.guruOptions.first.uid;
    String? selectedKelasId = initial?.kelasId ?? state.kelasOptions.first.id;
    String? selectedMapelId = initial?.mapelId ?? state.mapelOptions.first.id;
    String selectedHari = initial?.hari ?? _hariList.first;
    int selectedJamMulai = initialJamMulai ?? initial?.jamAwal ?? 1;
    int selectedJamSelesai = initialJamSelesai ?? initial?.jamAkhir ?? 1;
    int selectedSemester = initial?.semester ?? 1;
    String? localError;

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(initial == null ? 'Tambah Jadwal' : 'Edit Jadwal'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDropdownField<String>(
                    label: 'Guru',
                    value: selectedGuruUid,
                    items: state.guruOptions
                        .map(
                          (guru) => DropdownMenuItem<String>(
                            value: guru.uid,
                            child: Text(guru.nama),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedGuruUid = value;
                        localError = null;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildDropdownField<String>(
                    label: 'Kelas',
                    value: selectedKelasId,
                    items: state.kelasOptions
                        .map(
                          (kelas) => DropdownMenuItem<String>(
                            value: kelas.id,
                            child: Text(kelas.namaKelas),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedKelasId = value;
                        localError = null;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildDropdownField<String>(
                    label: 'Mata Pelajaran',
                    value: selectedMapelId,
                    items: state.mapelOptions
                        .map(
                          (mapel) => DropdownMenuItem<String>(
                            value: mapel.id,
                            child: Text(mapel.namaMapel),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedMapelId = value;
                        localError = null;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildDropdownField<String>(
                    label: 'Hari',
                    value: selectedHari,
                    items: _hariList
                        .map(
                          (hari) => DropdownMenuItem<String>(
                            value: hari,
                            child: Text(hari),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedHari = value ?? _hariList.first;
                        localError = null;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildDropdownField<int>(
                    label: 'Jam Mulai',
                    value: selectedJamMulai,
                    items: List.generate(
                      8,
                      (index) => DropdownMenuItem<int>(
                        value: index + 1,
                        child: Text(
                          'Jam ${index + 1} (${ModelUtils.getWaktuMulai(index + 1)} - ${ModelUtils.getWaktuSelesai(index + 1)})',
                        ),
                      ),
                    ),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedJamMulai = value ?? 1;
                        if (selectedJamSelesai < selectedJamMulai) {
                          selectedJamSelesai = selectedJamMulai;
                        }
                        localError = null;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildDropdownField<int>(
                    label: 'Jam Selesai',
                    value: selectedJamSelesai,
                    items: List.generate(8, (index) => index + 1)
                        .where((jam) => jam >= selectedJamMulai)
                        .map((jam) {
                          return DropdownMenuItem<int>(
                            value: jam,
                            child: Text(
                              'Jam $jam (${ModelUtils.getWaktuMulai(jam)} - ${ModelUtils.getWaktuSelesai(jam)})',
                            ),
                          );
                        })
                        .toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedJamSelesai = value ?? selectedJamMulai;
                        localError = null;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildDropdownField<int>(
                    label: 'Semester',
                    value: selectedSemester,
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('Semester 1')),
                      DropdownMenuItem(value: 2, child: Text('Semester 2')),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        selectedSemester = value ?? 1;
                        localError = null;
                      });
                    },
                  ),
                  if (localError != null && localError!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      localError!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (selectedGuruUid == null ||
                      selectedKelasId == null ||
                      selectedMapelId == null) {
                    setDialogState(() {
                      localError = 'Semua field wajib dipilih.';
                    });
                    return;
                  }

                  final rangeError = ref
                      .read(
                        jadwalGuruManagementProvider(
                          widget.tahunAjaranId,
                        ).notifier,
                      )
                      .validateJamRange(
                        jamMulai: selectedJamMulai,
                        jamSelesai: selectedJamSelesai,
                      );
                  if (rangeError != null) {
                    setDialogState(() {
                      localError = rangeError;
                    });
                    return;
                  }

                  Navigator.of(context).pop({
                    'guru_uid': selectedGuruUid!,
                    'kelas_id': selectedKelasId!,
                    'mapel_id': selectedMapelId!,
                    'hari': selectedHari,
                    'jam_mulai': selectedJamMulai,
                    'jam_selesai': selectedJamSelesai,
                    'semester': selectedSemester,
                  });
                },
                child: Text(initial == null ? 'Simpan' : 'Update'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<T>(
          initialValue: value,
          items: items,
          onChanged: onChanged,
          isExpanded: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
        ),
      ],
    );
  }

  void _showSuccess(String message) {
    AppAlert.success(
      context,
      title: 'Berhasil',
      message: message,
      autoClose: true,
    );
  }

  void _showError(String message) {
    AppAlert.error(context, message: message);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(jadwalGuruManagementProvider(widget.tahunAjaranId));

    if (_filterKelasId != null &&
        !state.kelasOptions.any((item) => item.id == _filterKelasId)) {
      _filterKelasId = null;
    }
    if (_filterGuruUid != null &&
        !state.guruOptions.any((item) => item.uid == _filterGuruUid)) {
      _filterGuruUid = null;
    }

    final filteredData = state.data.where((item) {
      if (_filterSemester != null && item.semester != _filterSemester) {
        return false;
      }
      if (_filterHari != _semuaHari && item.hari != _filterHari) {
        return false;
      }
      if (_filterKelasId != null && item.kelasId != _filterKelasId) {
        return false;
      }
      if (_filterGuruUid != null && item.guruUid != _filterGuruUid) {
        return false;
      }
      return true;
    }).toList();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (_isSavingAction) const LinearProgressIndicator(minHeight: 2),
            _buildFilterCard(state),
            if (state.error != null && state.error!.isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.error.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  state.error!,
                  style: const TextStyle(fontSize: 12, color: AppColors.error),
                ),
              ),
            if (state.isLoading && state.data.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 120),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (filteredData.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 120),
                child: Center(
                  child: Text(
                    'Belum ada jadwal guru sesuai filter.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: filteredData.length,
                itemBuilder: (context, index) {
                  final item = filteredData[index];
                  return _buildJadwalCard(item);
                },
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isSavingAction ? null : _onTambahJadwal,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildFilterCard(JadwalManajemenState state) {
    return AppExternalFilterBar(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      isExpanded: _isFilterVisible,
      onToggle: () {
        setState(() {
          _isFilterVisible = !_isFilterVisible;
        });
      },
      onReset: () {
        setState(() {
          _filterSemester = null;
          _filterHari = _semuaHari;
          _filterKelasId = null;
          _filterGuruUid = null;
        });
      },
      onApply: _refresh,
      isBusy: state.isLoading || _isSavingAction,
      children: [
        AppExternalFilterField(
          label: 'Tahun Ajaran',
          child: DropdownButtonFormField<String>(
            initialValue: widget.tahunAjaranId,
            decoration: appExternalFilterDecoration(
              hintText: 'Pilih tahun ajaran',
              icon: Icons.school_rounded,
            ),
            items: widget.tahunAjaranOptions
                .map(
                  (year) => DropdownMenuItem<String>(
                    value: year.id,
                    child: Text(
                      year.aktif ? '${year.nama} (Aktif)' : year.nama,
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) {
                return;
              }
              widget.onTahunAjaranChanged(value);
            },
          ),
        ),
        AppExternalFilterField(
          label: 'Semester',
          child: DropdownButtonFormField<int?>(
            initialValue: _filterSemester,
            decoration: appExternalFilterDecoration(
              hintText: 'Semua semester',
              icon: Icons.calendar_month_rounded,
            ),
            items: const [
              DropdownMenuItem<int?>(
                value: null,
                child: Text('Semua Semester'),
              ),
              DropdownMenuItem<int?>(value: 1, child: Text('Semester 1')),
              DropdownMenuItem<int?>(value: 2, child: Text('Semester 2')),
            ],
            onChanged: (value) {
              setState(() {
                _filterSemester = value;
              });
            },
          ),
        ),
        AppExternalFilterField(
          label: 'Hari',
          child: DropdownButtonFormField<String>(
            initialValue: _filterHari,
            decoration: appExternalFilterDecoration(
              hintText: 'Pilih hari',
              icon: Icons.view_week_rounded,
            ),
            items: [
              const DropdownMenuItem<String>(
                value: _semuaHari,
                child: Text(_semuaHari),
              ),
              ..._hariList.map(
                (hari) =>
                    DropdownMenuItem<String>(value: hari, child: Text(hari)),
              ),
            ],
            onChanged: (value) {
              setState(() {
                _filterHari = value ?? _semuaHari;
              });
            },
          ),
        ),
        AppExternalFilterField(
          label: 'Kelas',
          child: DropdownButtonFormField<String?>(
            initialValue: _filterKelasId,
            decoration: appExternalFilterDecoration(
              hintText: 'Semua kelas',
              icon: Icons.class_rounded,
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Semua Kelas'),
              ),
              ...state.kelasOptions.map(
                (kelas) => DropdownMenuItem<String?>(
                  value: kelas.id,
                  child: Text(kelas.namaKelas),
                ),
              ),
            ],
            onChanged: (value) {
              setState(() {
                _filterKelasId = value;
              });
            },
          ),
        ),
        AppExternalFilterField(
          label: 'Guru',
          child: DropdownButtonFormField<String?>(
            initialValue: _filterGuruUid,
            decoration: appExternalFilterDecoration(
              hintText: 'Semua guru',
              icon: Icons.person_rounded,
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Semua Guru'),
              ),
              ...state.guruOptions.map(
                (guru) => DropdownMenuItem<String?>(
                  value: guru.uid,
                  child: Text(guru.nama),
                ),
              ),
            ],
            onChanged: (value) {
              setState(() {
                _filterGuruUid = value;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildJadwalCard(JadwalManajemenItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.guruName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Semester ${item.semester}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('${item.mapelName} • Kelas ${item.kelasName}'),
            const SizedBox(height: 4),
            Text(
              '${item.hari}, Jam ke-${item.jamAwal} s.d. ke-${item.jamAkhir} '
              '(${ModelUtils.getWaktuMulai(item.jamAwal) ?? '--:--'} - '
              '${ModelUtils.getWaktuSelesai(item.jamAkhir) ?? '--:--'})',
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: () => _onEditJadwal(item),
                  icon: const Icon(Icons.edit),
                  tooltip: 'Edit',
                ),
                IconButton(
                  onPressed: () => _onDeleteJadwal(item),
                  icon: const Icon(Icons.delete),
                  tooltip: 'Hapus',
                  color: AppColors.error,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
