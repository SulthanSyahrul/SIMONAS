import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../kepala_sekolah/widgets/app_alert.dart';
import '../../../../core/providers/academic_year_provider.dart';
import '../../../../models/kelas_siswa_model.dart';
import '../../../../models/siswa_model.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_external_filter_bar.dart';
import '../../../../providers/supabase_providers.dart';
import '../../../../services/nilai_ujian_service.dart';
import '../../providers/nilai_guru_supabase_provider.dart';
import '../../providers/jadwal_guru_supabase_provider.dart';

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

/// Screen untuk input dan melihat nilai ujian siswa.
/// Guru hanya melihat nilai kelas dan mapel yang dipilih.
class GuruNilaiScreen extends ConsumerStatefulWidget {
  final AcademicYearProvider academicYearProvider;
  final String guruUid;

  const GuruNilaiScreen({
    super.key,
    required this.academicYearProvider,
    required this.guruUid,
  });

  @override
  ConsumerState<GuruNilaiScreen> createState() => _GuruNilaiScreenState();
}

class _GuruNilaiScreenState extends ConsumerState<GuruNilaiScreen> {
  List<_DropdownOption> _kelasOptions = const [];
  List<_DropdownOption> _mapelOptions = const [];
  List<_SiswaOption> _siswaOptions = const [];

  String? _selectedKelasId;
  String? _selectedMapelId;
  bool _isSaving = false;
  bool _isFilterVisible = true;
  bool _isContentLoading = false;

  final Map<String, TextEditingController> _utsControllers = {};
  final Map<String, TextEditingController> _uasControllers = {};

  String? get _selectedTahunAjaranId {
    return ref.read(tahunAjaranProvider).selectedTahunAjaranId;
  }

  String _displaySiswaName(SiswaRecord siswa) {
    final nama = siswa.nama?.trim();
    if (nama != null && nama.isNotEmpty) {
      return nama;
    }
    return siswa.uid;
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
    for (final controller in _utsControllers.values) {
      controller.dispose();
    }
    for (final controller in _uasControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _handleAcademicYearChanged() {
    _loadReferenceData(forceRefreshData: true);
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
        _selectedKelasId = null;
        _selectedMapelId = null;
        _siswaOptions = const <_SiswaOption>[];
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
    await _loadSelectedContent(forceRefreshData: forceRefreshData);
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
    await _syncDropdownFromJadwal(preserveSelection: false);
    await _loadSelectedContent();
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
    });

    await _loadSelectedContent();
  }

  Future<List<_SiswaOption>> _fetchSiswaOptionsByKelas() async {
    if (_selectedKelasId == null) {
      return const <_SiswaOption>[];
    }
    final tahunAjaranId = _selectedTahunAjaranId;
    if (tahunAjaranId == null) {
      return const <_SiswaOption>[];
    }

    final memberships = await ref
        .read(kelasSiswaServiceProvider)
        .getByKelasDanTahunAjaranIncremental(
          _selectedKelasId!,
          tahunAjaranId,
          includeDeleted: false,
        );

    final options = <_SiswaOption>[];
    for (final item in memberships) {
      options.add(
        _SiswaOption(
          keanggotaan: item,
          siswa: SiswaRecord(
            id: item.siswaRecordId ?? item.siswaId,
            uid: item.siswaId,
            nama: item.siswaNama,
            email: null,
            noHp: null,
            nis: item.siswaNis,
            gender: null,
            tempatLahir: null,
            tanggalLahir: null,
            alamat: null,
            isDeleted: false,
          ),
        ),
      );
    }

    options.sort(
      (a, b) {
        if (a.keanggotaan.statusAktif != b.keanggotaan.statusAktif) {
          return a.keanggotaan.statusAktif ? -1 : 1;
        }
        return _displaySiswaName(
          a.siswa,
        ).toLowerCase().compareTo(_displaySiswaName(b.siswa).toLowerCase());
      },
    );

    return options;
  }

  Future<void> _loadSelectedContent({bool forceRefreshData = false}) async {
    if (_selectedKelasId == null || _selectedMapelId == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _siswaOptions = const <_SiswaOption>[];
        _isContentLoading = false;
      });
      return;
    }

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
      final siswaFuture = _fetchSiswaOptionsByKelas();
      final nilaiFuture = ref
          .read(nilaiGuruSupabaseProvider(widget.guruUid).notifier)
          .getNilaiByKelasMapel(
            kelasId: _selectedKelasId!,
            mapelId: _selectedMapelId!,
            tahunAjaranId: tahunAjaranId,
            forceRefreshData: forceRefreshData,
            forceRefreshCache: forceRefreshData,
          );
      final siswaOptions = await siswaFuture;
      await nilaiFuture;

      if (!mounted) {
        return;
      }

      setState(() {
        _siswaOptions = siswaOptions;
        _isContentLoading = false;
      });
      _hydrateControllers(ref.read(nilaiGuruSupabaseProvider(widget.guruUid)));
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isContentLoading = false;
      });
      await AppAlert.error(context, message: 'Gagal memuat nilai: $e');
    }
  }

  Future<void> _reloadNilai({bool forceRefreshData = false}) async {
    await _loadSelectedContent(forceRefreshData: forceRefreshData);
  }

  void _hydrateControllers(NilaiGuruState state) {
    final activeSiswaIds = _siswaOptions
        .map((item) => item.siswa.uid)
        .toSet();

    _disposeMissingControllers(_utsControllers, activeSiswaIds);
    _disposeMissingControllers(_uasControllers, activeSiswaIds);

    for (final siswa in _siswaOptions) {
      NilaiGuruItem? existing;
      for (final row in state.data) {
        if (row.siswaId == siswa.siswa.uid) {
          existing = row;
          break;
        }
      }

      final utsValue = existing?.nilaiUts?.toString() ?? '';
      final uasValue = existing?.nilaiUas?.toString() ?? '';

      final utsController = _utsControllers.putIfAbsent(
        siswa.siswa.uid,
        () => TextEditingController(),
      );
      if (utsController.text != utsValue) {
        utsController.text = utsValue;
      }

      final uasController = _uasControllers.putIfAbsent(
        siswa.siswa.uid,
        () => TextEditingController(),
      );
      if (uasController.text != uasValue) {
        uasController.text = uasValue;
      }
    }
  }

  void _disposeMissingControllers(
    Map<String, TextEditingController> controllers,
    Set<String> activeSiswaIds,
  ) {
    final removedIds = controllers.keys
        .where((id) => !activeSiswaIds.contains(id))
        .toList(growable: false);
    for (final id in removedIds) {
      controllers.remove(id)?.dispose();
    }
  }

  Future<void> _saveNilai() async {
    if (_selectedKelasId == null || _selectedMapelId == null) {
      await AppAlert.error(
        context,
        message: 'Pilih kelas dan mata pelajaran terlebih dahulu.',
      );
      return;
    }

    if (_siswaOptions.isEmpty) {
      await AppAlert.error(
        context,
        message: 'Tidak ada siswa aktif pada kelas ini.',
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final tahunAjaranId = _selectedTahunAjaranId;
      if (tahunAjaranId == null) {
        throw Exception('Tahun ajaran belum tersedia.');
      }

      final notifier = ref.read(
        nilaiGuruSupabaseProvider(widget.guruUid).notifier,
      );
      final existingSiswaIds = ref
          .read(nilaiGuruSupabaseProvider(widget.guruUid))
          .data
          .map((item) => item.siswaId)
          .toSet();

      var totalSaved = 0;
      var hasCreated = false;
      var hasUpdated = false;
      final batchItems = <NilaiUjianBatchInput>[];
      for (final siswa in _siswaOptions) {
        if (!siswa.keanggotaan.statusAktif) {
          continue;
        }
        final uts = double.tryParse(
          _utsControllers[siswa.siswa.uid]?.text.trim() ?? '',
        );
        final uas = double.tryParse(
          _uasControllers[siswa.siswa.uid]?.text.trim() ?? '',
        );

        if (uts == null && uas == null) {
          continue;
        }

        if (existingSiswaIds.contains(siswa.siswa.uid)) {
          hasUpdated = true;
        } else {
          hasCreated = true;
        }

        batchItems.add(
          NilaiUjianBatchInput(
            siswaUid: siswa.siswa.uid,
            nilaiUts: uts,
            nilaiUas: uas,
          ),
        );
        totalSaved++;
      }

      if (batchItems.isNotEmpty) {
        await notifier.upsertNilaiMany(
          kelasId: _selectedKelasId!,
          mapelId: _selectedMapelId!,
          tahunAjaranId: tahunAjaranId,
          items: batchItems,
        );
      }

      await _reloadNilai();

      if (!mounted) {
        return;
      }

      if (totalSaved == 0) {
        await AppAlert.info(
          context,
          message: 'Tidak ada data nilai yang diubah.',
        );
      } else if (hasUpdated && !hasCreated) {
        await AppAlert.success(
          context,
          title: 'Berhasil',
          message: 'Nilai berhasil diperbarui.',
        );
      } else {
        await AppAlert.success(
          context,
          title: 'Berhasil',
          message: 'Nilai berhasil disimpan.',
        );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      await AppAlert.error(context, message: 'Gagal menyimpan nilai: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _confirmResetNilai() async {
    final kelasId = _selectedKelasId;
    final mapelId = _selectedMapelId;
    final tahunAjaranId = _selectedTahunAjaranId;

    if (kelasId == null || mapelId == null || tahunAjaranId == null) {
      await AppAlert.error(
        context,
        message:
            'Pilih tahun ajaran, kelas, dan mata pelajaran terlebih dahulu.',
      );
      return;
    }

    final currentState = ref.read(nilaiGuruSupabaseProvider(widget.guruUid));
    if (currentState.data.isEmpty) {
      await AppAlert.info(
        context,
        message: 'Tidak ada data nilai untuk dihapus.',
      );
      return;
    }

    final confirmed = await AppAlert.confirm(
      context,
      title: 'Yakin menghapus data nilai?',
      message: 'Data nilai pada filter saat ini akan dihapus.',
      okText: 'Ya, hapus',
      cancelText: 'Batal',
    );
    if (!confirmed) {
      return;
    }

    try {
      await ref
          .read(nilaiGuruSupabaseProvider(widget.guruUid).notifier)
          .clearNilaiByKelasMapel(
            kelasId: kelasId,
            mapelId: mapelId,
            tahunAjaranId: tahunAjaranId,
          );

      if (!mounted) {
        return;
      }
      await AppAlert.success(
        context,
        title: 'Berhasil',
        message: 'Nilai berhasil diperbarui.',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      await AppAlert.error(context, message: 'Gagal menghapus data nilai: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final nilaiState = ref.watch(nilaiGuruSupabaseProvider(widget.guruUid));
    final tahunAjaranState = ref.watch(tahunAjaranProvider);
    final jadwalState = ref.watch(jadwalGuruProvider(widget.guruUid));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nilai Ujian Siswa'),
        actions: [
          IconButton(
            onPressed: _isSaving ? null : _confirmResetNilai,
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Reset Nilai',
          ),
          IconButton(
            onPressed: () => _loadReferenceData(forceRefreshData: true),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _reloadNilai(forceRefreshData: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (nilaiState.isLoading) const LinearProgressIndicator(),
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
                          await _syncDropdownFromJadwal(
                            preserveSelection: false,
                          );
                          await _loadSelectedContent();
                        },
                        onApply: _reloadNilai,
                        isBusy: nilaiState.isLoading,
                        children: [
                          AppExternalFilterField(
                            label: 'Tahun Ajaran',
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
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedKelasId,
                              decoration: appExternalFilterDecoration(
                                hintText: 'Pilih kelas',
                                icon: Icons.class_rounded,
                              ),
                              items: _kelasOptions
                                  .map(
                                    (item) => DropdownMenuItem(
                                      value: item.id,
                                      child: Text(item.label),
                                    ),
                                  )
                                  .toList(),
                              onChanged: _handleKelasChanged,
                            ),
                          ),
                          AppExternalFilterField(
                            label: 'Mata Pelajaran',
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedMapelId,
                              decoration: appExternalFilterDecoration(
                                hintText: 'Pilih mata pelajaran',
                                icon: Icons.menu_book_rounded,
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
            _buildBody(nilaiState),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(NilaiGuruState nilaiState) {
    if (_selectedKelasId == null || _selectedMapelId == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('Pilih kelas dan mata pelajaran.')),
      );
    }

    if (_isContentLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_siswaOptions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text('Tidak ada siswa aktif pada kelas terpilih.'),
        ),
      );
    }

    return Column(
      children: [
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _siswaOptions.length,
          separatorBuilder: (context, index) => const Divider(),
          itemBuilder: (context, index) {
            final siswa = _siswaOptions[index];
            final isAktif = siswa.keanggotaan.statusAktif;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_displaySiswaName(siswa.siswa)),
              subtitle: Text(
                'NIS: ${siswa.siswa.nis ?? '-'}${isAktif ? '' : '\nStatus: Tidak aktif'}',
              ),
              isThreeLine: !isAktif,
              trailing: SizedBox(
                width: 220,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _utsControllers[siswa.siswa.uid],
                        enabled: isAktif && !_isSaving,
                        readOnly: !isAktif,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(3),
                          const _ScoreInputFormatter(),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'UTS',
                          hintText: '0-100',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _uasControllers[siswa.siswa.uid],
                        enabled: isAktif && !_isSaving,
                        readOnly: !isAktif,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(3),
                          const _ScoreInputFormatter(),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'UAS',
                          hintText: '0-100',
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        if (nilaiState.error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              nilaiState.error!,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveNilai,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(_isSaving ? 'Menyimpan...' : 'Simpan Nilai'),
            ),
          ),
        ),
      ],
    );
  }
}
