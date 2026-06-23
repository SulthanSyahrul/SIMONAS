import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/widgets/app_external_filter_bar.dart';
import '../../../../models/kelas_model.dart';
import '../../providers/kenaikan_kelas_bk_supabase_provider.dart';

class KenaikanKelasScreen extends ConsumerStatefulWidget {
  const KenaikanKelasScreen({super.key});

  @override
  ConsumerState<KenaikanKelasScreen> createState() =>
      _KenaikanKelasScreenState();
}

class _KenaikanKelasScreenState extends ConsumerState<KenaikanKelasScreen> {
  static const String _lulusOptionValue = '__lulus__';

  String? _sourceTahunAjaranId;
  String? _targetTahunAjaranId;
  String? _sourceKelasId;
  String? _targetKelasId;

  final Map<String, bool> _keputusanNaik = {};
  bool _isBootstrapping = true;
  bool _isFilterVisible = true;

  String _formatErrorMessage(Object error) {
    final raw = error.toString().trim();
    if (raw.startsWith('Exception: ')) {
      return raw.substring('Exception: '.length).trim();
    }
    return raw;
  }

  bool get _isLulusSelected => _targetKelasId == _lulusOptionValue;

  int? _extractKelasTingkat(String kelasName) {
    final match = RegExp(r'(\d+)').firstMatch(kelasName);
    if (match == null) {
      return null;
    }
    return int.tryParse(match.group(1) ?? '');
  }

  int? _selectedSourceTingkat(KenaikanKelasBkState state) {
    final sourceId = _sourceKelasId;
    if (sourceId == null) {
      return null;
    }

    for (final row in state.kelasOptions) {
      if (row.id == sourceId) {
        return _extractKelasTingkat(row.namaKelas);
      }
    }
    return null;
  }

  String? _extractKelasSuffix(String kelasName) {
    final match = RegExp(r'\d+\s*([A-Za-z0-9]+)$').firstMatch(kelasName.trim());
    final suffix = (match?.group(1) ?? '').trim().toUpperCase();
    if (suffix.isEmpty) {
      return null;
    }
    return suffix;
  }

  List<KelasRecord> _resolveTargetKelasOptions(
    KenaikanKelasBkState state,
  ) {
    final sourceId = _sourceKelasId;
    if (sourceId == null) {
      return [];
    }

    KelasRecord? sourceClass;
    for (final row in state.kelasOptions) {
      if (row.id == sourceId) {
        sourceClass = row;
        break;
      }
    }
    if (sourceClass == null) {
      return [];
    }

    final sourceTingkat = _extractKelasTingkat(sourceClass.namaKelas);
    if (sourceTingkat == null || sourceTingkat < 7 || sourceTingkat > 9) {
      return [];
    }
    if (sourceTingkat == 9) {
      return [];
    }

    final targetTingkat = sourceTingkat + 1;
    final targetOptions =
        state.kelasOptions
            .where(
              (row) => _extractKelasTingkat(row.namaKelas) == targetTingkat,
            )
            .toList()
          ..sort(
            (a, b) =>
                a.namaKelas.toLowerCase().compareTo(b.namaKelas.toLowerCase()),
          );
    return targetOptions;
  }

  String? _resolveAutoDefaultTargetClassId(
    KenaikanKelasBkState state,
    List<KelasRecord> targetOptions,
  ) {
    final sourceId = _sourceKelasId;
    if (sourceId == null) {
      return null;
    }

    KelasRecord? sourceClass;
    for (final row in state.kelasOptions) {
      if (row.id == sourceId) {
        sourceClass = row;
        break;
      }
    }
    if (sourceClass == null) {
      return null;
    }

    final sourceTingkat = _extractKelasTingkat(sourceClass.namaKelas);
    if (sourceTingkat == 9) {
      return _lulusOptionValue;
    }
    if (targetOptions.isEmpty) {
      return null;
    }

    final sourceSuffix = _extractKelasSuffix(sourceClass.namaKelas);
    if (sourceSuffix != null) {
      for (final row in targetOptions) {
        if (_extractKelasSuffix(row.namaKelas) == sourceSuffix) {
          return row.id;
        }
      }
    }

    return targetOptions.first.id;
  }

  void _syncTargetClassBySource(
    KenaikanKelasBkState state, {
    bool forceAutoDefault = false,
  }) {
    final sourceTingkat = _selectedSourceTingkat(state);
    final targetOptions = _resolveTargetKelasOptions(state);
    final validTargetIds = targetOptions.map((row) => row.id).toSet();

    if (sourceTingkat == 9) {
      setState(() {
        _targetKelasId = _lulusOptionValue;
      });
      return;
    }

    final shouldAutoDefault =
        forceAutoDefault ||
        _targetKelasId == null ||
        !validTargetIds.contains(_targetKelasId);

    if (!shouldAutoDefault) {
      return;
    }

    final autoTargetId = _resolveAutoDefaultTargetClassId(state, targetOptions);
    setState(() {
      _targetKelasId = autoTargetId;
    });
  }

  Future<bool> _confirmLulusFromNonFinalClass() async {
    final shouldContinue = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Konfirmasi Kelulusan'),
          content: const Text(
            'Yakin menandai siswa lulus dari kelas non-akhir?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
                foregroundColor: Colors.white,
              ),
              child: const Text('Lanjutkan'),
            ),
          ],
        );
      },
    );

    return shouldContinue == true;
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(_bootstrap);
  }

  Future<void> _bootstrap() async {
    final notifier = ref.read(kenaikanKelasBkProvider.notifier);
    await notifier.loadMasterData();

    final state = ref.read(kenaikanKelasBkProvider);
    final tahun = state.tahunAjaranOptions;
    final kelas = state.kelasOptions;

    String? targetYear;
    if (tahun.isNotEmpty) {
      final active = tahun.where((row) => row.aktif).toList();
      targetYear = active.isNotEmpty ? active.first.id : tahun.first.id;
    }

    final sourceYear = tahun
        .where((row) => row.id != targetYear)
        .map((row) => row.id)
        .cast<String?>()
        .firstWhere((_) => true, orElse: () => targetYear);

    if (!mounted) {
      return;
    }

    setState(() {
      _targetTahunAjaranId = targetYear;
      _sourceTahunAjaranId = sourceYear;
      _sourceKelasId = kelas.isNotEmpty ? kelas.first.id : null;
      _targetKelasId = null;
      _isBootstrapping = false;
    });

    _syncTargetClassBySource(state, forceAutoDefault: true);

    await _loadCandidates();
  }

  Future<void> _loadCandidates({bool forceRefresh = false}) async {
    final sourceKelasId = _sourceKelasId;
    final sourceTahunId = _sourceTahunAjaranId;

    if (sourceKelasId == null || sourceTahunId == null) {
      return;
    }

    await ref
        .read(kenaikanKelasBkProvider.notifier)
        .loadCandidates(
          kelasAsalId: sourceKelasId,
          tahunAjaranAsalId: sourceTahunId,
          forceRefresh: forceRefresh,
        );

    final state = ref.read(kenaikanKelasBkProvider);
    if (!mounted) {
      return;
    }

    setState(() {
      for (final row in state.candidates) {
        _keputusanNaik.putIfAbsent(row.siswaId, () => true);
      }
    });
  }

  Future<void> _prosesKenaikan() async {
    final currentState = ref.read(kenaikanKelasBkProvider);
    final sourceTahunId = _sourceTahunAjaranId;
    final targetTahunId = _targetTahunAjaranId;
    final sourceKelasId = _sourceKelasId;
    final targetKelasId = _targetKelasId;

    if (sourceTahunId == null ||
        targetTahunId == null ||
        sourceKelasId == null ||
        targetKelasId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lengkapi tahun ajaran dan kelas terlebih dahulu.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (_isLulusSelected) {
      final tingkat = _selectedSourceTingkat(currentState);
      final isFinalGrade = tingkat == 9;
      if (!isFinalGrade) {
        final allowed = await _confirmLulusFromNonFinalClass();
        if (!allowed) {
          return;
        }
        if (!mounted) {
          return;
        }
      }
    }

    final shouldProcess = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Konfirmasi Proses Kenaikan'),
          content: const Text(
            'Proses ini akan memperbarui assignment siswa pada tabel kelas_siswa. Lanjutkan?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
              ),
              child: const Text('Proses'),
            ),
          ],
        );
      },
    );

    if (shouldProcess != true) {
      return;
    }

    try {
      final result = await ref
          .read(kenaikanKelasBkProvider.notifier)
          .prosesKenaikan(
            kelasAsalId: sourceKelasId,
            kelasTujuanId: _isLulusSelected ? null : targetKelasId,
            tahunAjaranAsalId: sourceTahunId,
            tahunAjaranTujuanId: targetTahunId,
            keputusanNaikBySiswaId: _keputusanNaik,
          );

      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (context) {
          if (_isLulusSelected) {
            return AlertDialog(
              title: const Text('Berhasil'),
              content: const Text('Siswa berhasil dinyatakan lulus'),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            );
          }

          return AlertDialog(
            title: const Text('Kenaikan Kelas Berhasil'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total siswa diproses: ${result.total}'),
                Text('Naik kelas: ${result.naik}'),
                Text('Tinggal kelas: ${result.tinggal}'),
                if (result.lulus > 0) Text('Lulus: ${result.lulus}'),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );

      await _loadCandidates(forceRefresh: true);
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal memproses kenaikan kelas: ${_formatErrorMessage(e)}',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(kenaikanKelasBkProvider);
    final sourceTingkat = _selectedSourceTingkat(state);
    final targetClassOptions = _resolveTargetKelasOptions(state);
    final isFinalGrade = sourceTingkat == 9;
    final isTargetSelectionValid = isFinalGrade
        ? _targetKelasId == _lulusOptionValue
        : targetClassOptions.any((row) => row.id == _targetKelasId);
    final targetDropdownValue = isTargetSelectionValid ? _targetKelasId : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kenaikan Kelas'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: state.isLoading
                ? null
                : () => _loadCandidates(forceRefresh: true),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isBootstrapping
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadCandidates(forceRefresh: true),
              child: ListView(
                children: [
                  AppExternalFilterBar(
                    isExpanded: _isFilterVisible,
                    onToggle: () {
                      setState(() {
                        _isFilterVisible = !_isFilterVisible;
                      });
                    },
                    onReset: _bootstrap,
                    onApply: () {},
                    isBusy: state.isLoading,
                    children: [
                      AppExternalFilterField(
                        label: 'Tahun Ajaran',
                        child: DropdownButtonFormField<String>(
                           initialValue: _sourceTahunAjaranId,
                          decoration: appExternalFilterDecoration(
                            hintText: 'Tahun ajaran sumber',
                            icon: Icons.school_rounded,
                          ),
                          items: state.tahunAjaranOptions
                              .map(
                                (row) => DropdownMenuItem(
                                  value: row.id,
                                  child: Text(row.nama),
                                ),
                              )
                              .toList(),
                          onChanged: (value) async {
                            if (value == null) {
                              return;
                            }
                            setState(() {
                              _sourceTahunAjaranId = value;
                            });
                            await _loadCandidates();
                          },
                        ),
                      ),
                      AppExternalFilterField(
                        label: 'Tahun Ajaran Tujuan',
                        child: DropdownButtonFormField<String>(
                          initialValue: _targetTahunAjaranId,
                          decoration: appExternalFilterDecoration(
                            hintText: 'Tahun ajaran tujuan',
                            icon: Icons.flag_rounded,
                          ),
                          items: state.tahunAjaranOptions
                              .map(
                                (row) => DropdownMenuItem(
                                  value: row.id,
                                  child: Text(row.nama),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _targetTahunAjaranId = value;
                            });
                          },
                        ),
                      ),
                      Builder(
                        builder: (context) {
                          final isMobile =
                              MediaQuery.sizeOf(context).width < 760;
                          if (isMobile) {
                            return const SizedBox.shrink();
                          }
                          return const SizedBox(width: 240);
                        },
                      ),
                      AppExternalFilterField(
                        label: 'Kelas Asal',
                        child: DropdownButtonFormField<String>(
                          initialValue: _sourceKelasId,
                          decoration: appExternalFilterDecoration(
                            hintText: 'Pilih kelas asal',
                            icon: Icons.class_rounded,
                          ),
                          items: state.kelasOptions
                              .map(
                                (row) => DropdownMenuItem(
                                  value: row.id,
                                  child: Text(row.namaKelas),
                                ),
                              )
                              .toList(),
                          onChanged: (value) async {
                            if (value == null) {
                              return;
                            }
                            setState(() {
                              _sourceKelasId = value;
                            });
                            _syncTargetClassBySource(
                              ref.read(kenaikanKelasBkProvider),
                              forceAutoDefault: true,
                            );
                            await _loadCandidates();
                          },
                        ),
                      ),
                      AppExternalFilterField(
                        label: 'Kelas Tujuan',
                        child: DropdownButtonFormField<String>(
                          initialValue: targetDropdownValue,
                          decoration:
                              appExternalFilterDecoration(
                                hintText: 'Pilih kelas tujuan',
                                icon: Icons.outbound_rounded,
                              ).copyWith(
                                helperText:
                                    'Kelas tujuan disesuaikan otomatis berdasarkan tingkat kelas.',
                              ),
                          items: [
                            ...targetClassOptions.map(
                              (row) => DropdownMenuItem(
                                value: row.id,
                                child: Text(row.namaKelas),
                              ),
                            ),
                            if (isFinalGrade)
                              const DropdownMenuItem(
                                value: _lulusOptionValue,
                                child: Text('Lulus'),
                              ),
                          ],
                          onChanged: isFinalGrade
                              ? null
                              : (value) {
                                  setState(() {
                                    _targetKelasId = value;
                                  });
                                },
                        ),
                      ),
                    ],
                  ),
                  if (!isFinalGrade && targetClassOptions.isEmpty)
                    Container(
                      width: double.infinity,
                      color: AppColors.warning.withAlpha(20),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: const Text(
                        'Tidak ditemukan kelas tujuan yang valid untuk tingkat berikutnya.',
                        style: TextStyle(
                          color: AppColors.warning,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  Container(
                    width: double.infinity,
                    color: AppColors.info.withAlpha(26),
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      _isLulusSelected
                          ? 'Tentukan per siswa: lulus (ON) atau tidak lulus (OFF)'
                          : 'Tentukan per siswa: naik kelas (ON) atau tinggal kelas (OFF).',
                      style: const TextStyle(
                        color: AppColors.info,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  if (state.error != null && state.error!.isNotEmpty)
                    Container(
                      width: double.infinity,
                      color: AppColors.error.withAlpha(20),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Text(
                        state.error!,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  if (state.isLoading)
                    const LinearProgressIndicator(minHeight: 2),
                  if (state.candidates.isEmpty) ...[
                    const SizedBox(height: 96),
                    const Icon(
                      Icons.upgrade_outlined,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 12),
                    const Center(
                      child: Text(
                        'Tidak ada kandidat kenaikan',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ] else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: state.candidates.length,
                      itemBuilder: (context, index) {
                        final row = state.candidates[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: SwitchListTile(
                            value: _keputusanNaik[row.siswaId] ?? true,
                            title: Text(
                              row.siswaNama,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              'Kelas asal: ${row.kelasAsalNama}\n'
                              '${_isLulusSelected ? ((_keputusanNaik[row.siswaId] ?? true) ? 'Lulus' : 'Tidak Lulus') : ((_keputusanNaik[row.siswaId] ?? true) ? 'Naik kelas' : 'Tinggal kelas')}',
                            ),
                            onChanged: (value) {
                              setState(() {
                                    _keputusanNaik[row.siswaId] = value;
                              });
                            },
                          ),
                        );
                      },
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: state.isLoading || state.candidates.isEmpty
                            ? null
                            : _prosesKenaikan,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Proses Kenaikan Kelas'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
