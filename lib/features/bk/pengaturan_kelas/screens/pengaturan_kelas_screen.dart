import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../core/services/app_metrics.dart';
import '../../../../../core/widgets/app_external_filter_bar.dart';
import '../../../../../models/kelas_model.dart';
import '../../providers/pengaturan_kelas_bk_supabase_provider.dart';

part '../widgets/pengaturan_kelas_widgets.dart';

enum _StudentStatusTab { assigned, unassigned }

class PengaturanKelasScreen extends ConsumerStatefulWidget {
  const PengaturanKelasScreen({super.key});

  @override
  ConsumerState<PengaturanKelasScreen> createState() =>
      _PengaturanKelasScreenState();
}

class _PengaturanKelasScreenState extends ConsumerState<PengaturanKelasScreen> {
  final TextEditingController _searchController = TextEditingController();
  final PerfTimer _screenTimer = PerfTimer('pengaturan_kelas_screen');

  String? _selectedTahunAjaranId;
  String? _selectedKelasId;
  bool _isBootstrapping = true;
  bool _hasRecordedScreenLoad = false;
  _StudentStatusTab _selectedTab = _StudentStatusTab.assigned;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    Future.microtask(_bootstrap);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final notifier = ref.read(pengaturanKelasBkProvider.notifier);
    await notifier.loadMasterData();

    final state = ref.read(pengaturanKelasBkProvider);
    final tahunAktif = state.tahunAjaranOptions.where((row) => row.aktif);
    final defaultTahunId = tahunAktif.isNotEmpty
        ? tahunAktif.first.id
        : (state.tahunAjaranOptions.isNotEmpty
              ? state.tahunAjaranOptions.first.id
              : null);

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedTahunAjaranId = defaultTahunId;
      _selectedKelasId = null;
      _isBootstrapping = false;
    });

    await _loadData();
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    final tahunAjaranId = _selectedTahunAjaranId;
    if (tahunAjaranId == null) {
      return;
    }

    await ref
        .read(pengaturanKelasBkProvider.notifier)
        .getKelasSiswa(
          tahunAjaranId: tahunAjaranId,
          kelasId: _selectedKelasId,
          forceRefresh: forceRefresh,
        );

    if (!_hasRecordedScreenLoad && mounted) {
      _hasRecordedScreenLoad = true;
      AppMetrics().recordScreenLoad(
        'pengaturan_kelas',
        _screenTimer.elapsed,
      );
    }
  }

  Future<void> _applyFilter() async {
    final tahunAjaranId = _selectedTahunAjaranId;
    if (tahunAjaranId == null) {
      return;
    }

    await ref
        .read(pengaturanKelasBkProvider.notifier)
        .applyFilter(tahunAjaranId: tahunAjaranId, kelasId: _selectedKelasId);
  }

  String? _selectedTahunAjaranName(PengaturanKelasBkState state) {
    final selectedId = _selectedTahunAjaranId;
    if (selectedId == null) {
      return null;
    }
    for (final row in state.tahunAjaranOptions) {
      if (row.id == selectedId) {
        return row.nama;
      }
    }
    return null;
  }

  KelasRecord? _selectedKelas(PengaturanKelasBkState state) {
    final selectedId = _selectedKelasId;
    if (selectedId == null) {
      return null;
    }
    for (final row in state.kelasOptions) {
      if (row.id == selectedId) {
        return row;
      }
    }
    return null;
  }

  Future<void> _showAssignSheet({String? initialSiswaId}) async {
    final tahunAjaranId = _selectedTahunAjaranId;
    if (tahunAjaranId == null) {
      return;
    }

    final state = ref.read(pengaturanKelasBkProvider);
    final tahunNama = _selectedTahunAjaranName(state) ?? '-';
    String? kelasId =
        _selectedKelasId ??
        (state.kelasOptions.isNotEmpty ? state.kelasOptions.first.id : null);
    final selectedSiswaIds = <String>{
      if (initialSiswaId != null) initialSiswaId,
    };
    final sheetSearchController = TextEditingController();

    late final _AssignSheetResult? result;
    try {
      result = await showModalBottomSheet<_AssignSheetResult>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setSheetState) {
              final searchQuery = sheetSearchController.text;
              final candidates = state.unassignedData
                  .where((row) => row.matchesSearch(searchQuery))
                  .toList(growable: false);
              final selectedKelasNama = state.kelasOptions
                  .where((row) => row.id == kelasId)
                  .map((row) => row.namaKelas)
                  .cast<String?>()
                  .firstWhere((_) => true, orElse: () => null);

              return Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                  top: 12,
                ),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.86,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Tambah Siswa ke Kelas',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _ReadOnlyInfoRow(
                        icon: Icons.calendar_month_rounded,
                        label: 'Tahun Ajaran',
                        value: tahunNama,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: kelasId,
                        decoration: appExternalFilterDecoration(
                          hintText: 'Pilih kelas tujuan',
                          icon: Icons.class_rounded,
                        ).copyWith(labelText: 'Kelas Tujuan'),
                        items: state.kelasOptions
                            .map(
                              (row) => DropdownMenuItem(
                                value: row.id,
                                child: Text(row.namaKelas),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setSheetState(() {
                            kelasId = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: sheetSearchController,
                        decoration: appExternalFilterDecoration(
                          hintText: 'Cari nama atau NIS siswa...',
                          icon: Icons.search_rounded,
                        ),
                        onChanged: (_) => setSheetState(() {}),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: candidates.isEmpty
                            ? _InlineEmptyState(
                                icon: Icons.verified_user_outlined,
                                title: searchQuery.trim().isEmpty
                                    ? 'Semua siswa sudah memiliki kelas.'
                                    : 'Tidak ada siswa yang cocok dengan pencarian.',
                                subtitle: searchQuery.trim().isEmpty
                                    ? 'Tidak ada kandidat yang bisa ditambahkan pada tahun ajaran ini.'
                                    : 'Coba gunakan nama atau NIS lain.',
                              )
                            : ListView.separated(
                                itemCount: candidates.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final item = candidates[index];
                                  final selected = selectedSiswaIds.contains(
                                    item.siswaId,
                                  );
                                  return CheckboxListTile(
                                    value: selected,
                                    contentPadding: EdgeInsets.zero,
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    title: Text(
                                      item.siswaNama,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    subtitle: Text(
                                      item.siswaNis?.trim().isNotEmpty == true
                                          ? 'NIS: ${item.siswaNis}'
                                          : 'NIS belum tersedia',
                                    ),
                                    onChanged: (value) {
                                      setSheetState(() {
                                        if (value == true) {
                                          selectedSiswaIds.add(item.siswaId);
                                        } else {
                                          selectedSiswaIds.remove(item.siswaId);
                                        }
                                      });
                                    },
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: kelasId == null || selectedSiswaIds.isEmpty
                              ? null
                              : () {
                                  Navigator.of(context).pop(
                                    _AssignSheetResult(
                                      kelasId: kelasId!,
                                      kelasNama: selectedKelasNama ?? '-',
                                      siswaIds: selectedSiswaIds.toList(),
                                    ),
                                  );
                                },
                          icon: const Icon(Icons.person_add_alt_1_rounded),
                          label: Text(
                            selectedSiswaIds.isEmpty
                                ? 'Tambah ke Kelas'
                                : 'Tambah ${selectedSiswaIds.length} Siswa ke ${selectedKelasNama ?? 'Kelas'}',
                          ),
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
    } finally {
      sheetSearchController.dispose();
    }

    if (result == null) {
      return;
    }

    try {
      await ref
          .read(pengaturanKelasBkProvider.notifier)
          .assignSiswaListToKelas(
            siswaIds: result.siswaIds,
            kelasId: result.kelasId,
            tahunAjaranId: tahunAjaranId,
            refreshKelasId: _selectedKelasId,
          );

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Berhasil menambahkan ${result.siswaIds.length} siswa ke kelas ${result.kelasNama}.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan perubahan: ${_formatError(e)}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _showMoveSheet(BkKelasSiswaItem item) async {
    final state = ref.read(pengaturanKelasBkProvider);
    String? kelasBaruId = item.kelasId;

    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final kelasBaruNama = state.kelasOptions
                .where((row) => row.id == kelasBaruId)
                .map((row) => row.namaKelas)
                .cast<String?>()
                .firstWhere((_) => true, orElse: () => null);
            final isSameClass = kelasBaruId == item.kelasId;

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pindah Kelas',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _StudentIdentityHeader(
                    name: item.siswaNama,
                    nis: item.siswaNis,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: kelasBaruId,
                    decoration: appExternalFilterDecoration(
                      hintText: 'Pilih kelas baru',
                      icon: Icons.class_rounded,
                    ).copyWith(labelText: 'Kelas Baru'),
                    items: state.kelasOptions
                        .map(
                          (row) => DropdownMenuItem(
                            value: row.id,
                            child: Text(row.namaKelas),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setSheetState(() {
                        kelasBaruId = value;
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.info.withAlpha(20),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.info.withAlpha(45)),
                    ),
                    child: Text(
                      isSameClass
                          ? '${item.siswaNama} masih berada di kelas ${item.kelasNama}.'
                          : '${item.siswaNama} akan dipindahkan dari kelas ${item.kelasNama} ke kelas ${kelasBaruNama ?? '-'} pada tahun ajaran ${item.tahunAjaranNama}.',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Batalkan'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: kelasBaruId == null || isSameClass
                              ? null
                              : () => Navigator.of(context).pop(kelasBaruId),
                          child: const Text('Pindahkan'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (selected == null) {
      return;
    }

    try {
      await ref
          .read(pengaturanKelasBkProvider.notifier)
          .moveSiswaToKelas(
            kelasSiswaId: item.id,
            siswaId: item.siswaId,
            tahunAjaranId: item.tahunAjaranId,
            kelasId: selected,
            refreshKelasId: _selectedKelasId,
          );

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Berhasil memindahkan kelas siswa.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memindahkan kelas siswa: ${_formatError(e)}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _confirmDeactivate(BkKelasSiswaItem item) async {
    final shouldDeactivate = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nonaktifkan Assignment'),
          content: Text(
            'Nonaktifkan assignment ${item.siswaNama} dari kelas ${item.kelasNama}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Nonaktifkan'),
            ),
          ],
        );
      },
    );

    if (shouldDeactivate != true) {
      return;
    }

    try {
      await ref
          .read(pengaturanKelasBkProvider.notifier)
          .updateKelasSiswa(
            kelasSiswaId: item.id,
            tahunAjaranId: item.tahunAjaranId,
            kelasId: item.kelasId,
            status: 'nonaktif',
            refreshKelasId: _selectedKelasId,
          );

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Assignment siswa berhasil dinonaktifkan.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menonaktifkan assignment: ${_formatError(e)}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _confirmDelete(BkKelasSiswaItem item) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Hapus Assignment'),
          content: Text(
            'Hapus assignment ${item.siswaNama} dari kelas ${item.kelasNama}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      await ref
          .read(pengaturanKelasBkProvider.notifier)
          .softDeleteKelasSiswa(
            kelasSiswaId: item.id,
            tahunAjaranId: item.tahunAjaranId,
            refreshKelasId: _selectedKelasId,
          );

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Assignment berhasil dihapus.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menghapus assignment: ${_formatError(e)}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pengaturanKelasBkProvider);
    final selectedKelas = _selectedKelas(state);
    final fabLabel = selectedKelas == null
        ? 'Atur Kelas Siswa'
        : 'Tambah ke ${selectedKelas.namaKelas}';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pengaturan Kelas Siswa'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: state.isLoading
                ? null
                : () => _loadData(forceRefresh: true),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isBootstrapping
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadData(forceRefresh: true),
              child: _buildContent(state),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: state.isLoading ? null : _showAssignSheet,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: Text(fabLabel),
      ),
    );
  }

  Widget _buildContent(PengaturanKelasBkState state) {
    final query = _searchController.text;
    final assigned = state.assignedData
        .where((row) => row.matchesSearch(query))
        .toList(growable: false);
    final unassigned = state.unassignedData
        .where((row) => row.matchesSearch(query))
        .toList(growable: false);

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _buildYearFilter(state)),
        SliverToBoxAdapter(child: _buildSummaryCard(state)),
        SliverToBoxAdapter(child: _buildKelasChips(state)),
        SliverToBoxAdapter(child: _buildSearchBar()),
        SliverToBoxAdapter(child: _buildStatusTabs(state)),
        if (state.error != null && state.error!.isNotEmpty)
          SliverToBoxAdapter(child: _buildErrorState(state.error!))
        else if (state.isLoading)
          SliverToBoxAdapter(child: _buildLoadingState())
        else if (_selectedTab == _StudentStatusTab.assigned)
          _buildAssignedList(state, assigned)
        else
          _buildUnassignedList(state, unassigned),
        const SliverToBoxAdapter(child: SizedBox(height: 96)),
      ],
    );
  }

  Widget _buildYearFilter(PengaturanKelasBkState state) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      padding: const EdgeInsets.all(16),
      decoration: _surfaceDecoration(),
      child: DropdownButtonFormField<String>(
        key: ValueKey(_selectedTahunAjaranId),
        initialValue: _selectedTahunAjaranId,
        decoration: appExternalFilterDecoration(
          hintText: 'Pilih tahun ajaran',
          icon: Icons.school_rounded,
        ).copyWith(labelText: 'Tahun Ajaran'),
        items: state.tahunAjaranOptions
            .map(
              (row) => DropdownMenuItem(
                value: row.id,
                child: Text(row.aktif ? '${row.nama} (Aktif)' : row.nama),
              ),
            )
            .toList(),
        onChanged: state.isLoading
            ? null
            : (value) async {
                if (value == null) {
                  return;
                }
                setState(() {
                  _selectedTahunAjaranId = value;
                  _selectedKelasId = null;
                  _selectedTab = _StudentStatusTab.assigned;
                  _searchController.clear();
                });
                await _loadData();
              },
      ),
    );
  }

  Widget _buildSummaryCard(PengaturanKelasBkState state) {
    final items = [
      _SummaryItem(
        icon: Icons.groups_rounded,
        label: 'Total Siswa',
        value: state.totalSiswa.toString(),
        color: AppColors.primary,
      ),
      _SummaryItem(
        icon: Icons.check_circle_rounded,
        label: 'Sudah Diatur',
        value: state.assignedCount.toString(),
        color: AppColors.success,
      ),
      _SummaryItem(
        icon: Icons.person_search_rounded,
        label: 'Belum Punya Kelas',
        value: state.unassignedCount.toString(),
        color: AppColors.warning,
      ),
      _SummaryItem(
        icon: Icons.meeting_room_rounded,
        label: 'Kelas',
        value: state.kelasCount.toString(),
        color: AppColors.info,
      ),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(14),
      decoration: _surfaceDecoration(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = (constraints.maxWidth - 10) / 2;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: items
                .map((item) => SizedBox(width: itemWidth, child: item))
                .toList(),
          );
        },
      ),
    );
  }

  Widget _buildKelasChips(PengaturanKelasBkState state) {
    final grouped = <int, List<KelasRecord>>{};
    for (final kelas in state.kelasOptions) {
      grouped.putIfAbsent(kelas.tingkat, () => <KelasRecord>[]).add(kelas);
    }
    final levels = grouped.keys.toList()..sort();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: _surfaceDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.class_rounded, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Pilihan Kelas Cepat',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _ClassChip(
                  label: 'Semua',
                  count: state.assignedCount,
                  selected: _selectedKelasId == null,
                  onSelected: () async {
                    setState(() {
                      _selectedKelasId = null;
                    });
                    await _applyFilter();
                  },
                ),
              ],
            ),
          ),
          for (final level in levels) ...[
            const SizedBox(height: 12),
            Text(
              level > 0 ? 'Tingkat $level' : 'Kelas Lainnya',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: grouped[level]!
                    .map(
                      (kelas) => _ClassChip(
                        label: kelas.namaKelas,
                        count: state.kelasStudentCounts[kelas.id] ?? 0,
                        selected: _selectedKelasId == kelas.id,
                        onSelected: () async {
                          setState(() {
                            _selectedKelasId = _selectedKelasId == kelas.id
                                ? null
                                : kelas.id;
                          });
                          await _applyFilter();
                        },
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: TextField(
        controller: _searchController,
        decoration:
            appExternalFilterDecoration(
              hintText: 'Cari nama atau NIS siswa...',
              icon: Icons.search_rounded,
            ).copyWith(
              suffixIcon: _searchController.text.trim().isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Bersihkan pencarian',
                      onPressed: _searchController.clear,
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
      ),
    );
  }

  Widget _buildStatusTabs(PengaturanKelasBkState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<_StudentStatusTab>(
          segments: [
            ButtonSegment(
              value: _StudentStatusTab.assigned,
              icon: const Icon(Icons.check_circle_outline_rounded),
              label: Text('Sudah Diatur (${state.assignedData.length})'),
            ),
            ButtonSegment(
              value: _StudentStatusTab.unassigned,
              icon: const Icon(Icons.person_search_rounded),
              label: Text('Belum Punya Kelas (${state.unassignedData.length})'),
            ),
          ],
          selected: {_selectedTab},
          onSelectionChanged: (selection) {
            setState(() {
              _selectedTab = selection.first;
            });
          },
        ),
      ),
    );
  }

  Widget _buildAssignedList(
    PengaturanKelasBkState state,
    List<BkKelasSiswaItem> items,
  ) {
    if (items.isEmpty) {
      final query = _searchController.text.trim();
      final selectedKelas = _selectedKelas(state);
      return SliverToBoxAdapter(
        child: _PageEmptyState(
          icon: query.isEmpty ? Icons.class_outlined : Icons.search_off_rounded,
          title: query.isEmpty
              ? selectedKelas == null
                    ? 'Belum ada siswa yang sudah diatur.'
                    : 'Tetap belum ada siswa di kelas ini.'
              : 'Tidak ada siswa yang cocok dengan pencarian.',
          subtitle: query.isEmpty
              ? 'Tombol Tambah ke Kelas dapat digunakan untuk memasukkan siswa.'
              : 'Coba gunakan nama atau NIS lain.',
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) => _AssignedStudentCard(
          item: items[index],
          onMove: () => _showMoveSheet(items[index]),
          onDeactivate: () => _confirmDeactivate(items[index]),
          onDelete: () => _confirmDelete(items[index]),
        ),
      ),
    );
  }

  Widget _buildUnassignedList(
    PengaturanKelasBkState state,
    List<BkSiswaBelumKelasItem> items,
  ) {
    if (items.isEmpty) {
      final query = _searchController.text.trim();
      return SliverToBoxAdapter(
        child: _PageEmptyState(
          icon: query.isEmpty
              ? Icons.verified_user_outlined
              : Icons.search_off_rounded,
          title: query.isEmpty
              ? 'Semua siswa sudah memiliki kelas pada tahun ajaran ini.'
              : 'Tidak ada siswa yang cocok dengan pencarian.',
          subtitle: query.isEmpty
              ? 'Tidak ada siswa tersisa untuk dimasukkan ke kelas.'
              : 'Coba gunakan nama atau NIS lain.',
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) => _UnassignedStudentCard(
          item: items[index],
          onAssign: () =>
              _showAssignSheet(initialSiswaId: items[index].siswaId),
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: _surfaceDecoration(
          borderColor: AppColors.error.withAlpha(80),
        ),
        child: Column(
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.error),
            const SizedBox(height: 8),
            Text(
              'Gagal memuat data',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              _formatError(error),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _loadData(forceRefresh: true),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          const LinearProgressIndicator(minHeight: 2),
          const SizedBox(height: 16),
          for (var i = 0; i < 3; i++) ...[
            Container(
              height: 112,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.grey.shade200),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  BoxDecoration _surfaceDecoration({Color? borderColor}) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: borderColor ?? Colors.grey.shade200),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withAlpha(10),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  String _formatError(Object error) {
    final raw = error.toString().trim();
    if (raw.startsWith('Exception: ')) {
      return raw.substring('Exception: '.length).trim();
    }
    return raw;
  }
}
