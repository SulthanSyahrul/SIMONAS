import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/academic_year_provider.dart';
import '../../../../providers/supabase_providers.dart';
import '../../../../core/widgets/app_external_filter_bar.dart';
import '../../../shared/providers/shared_academic_context_provider.dart';
import '../../providers/raport_guru_supabase_provider.dart';

class _DropdownOption {
  final String id;
  final String label;

  const _DropdownOption({required this.id, required this.label});
}

/// Screen untuk raport siswa (khusus wali kelas)
/// Menampilkan ringkasan nilai siswa per kelas.
class RaportScreen extends ConsumerStatefulWidget {
  final AcademicYearProvider academicYearProvider;
  final String guruUid;

  const RaportScreen({
    super.key,
    required this.academicYearProvider,
    required this.guruUid,
  });

  @override
  ConsumerState<RaportScreen> createState() => _RaportScreenState();
}

class _RaportScreenState extends ConsumerState<RaportScreen> {
  static const String _allFilterValue = 'all';

  final TextEditingController _searchController = TextEditingController();
  bool _isFilterVisible = true;

  List<_DropdownOption> _tahunAjaranOptions = const [];
  List<_DropdownOption> _kelasOptions = const [];
  List<_DropdownOption> _mapelOptions = const [];
  Map<String, List<_DropdownOption>> _kelasOptionsByTahun =
      const <String, List<_DropdownOption>>{};

  String _selectedTahunAjaranId = _allFilterValue;
  String _selectedKelasId = _allFilterValue;
  String _selectedMapelId = _allFilterValue;
  String _searchQuery = '';
  _RaportSortOption _sortOption = _RaportSortOption.rankingTertinggi;
  bool _hasRaportAccess = true;

  @override
  void initState() {
    super.initState();
    widget.academicYearProvider.addListener(_handleAcademicYearChanged);
    Future.microtask(() async {
      await _loadFilterOptions();
      if (_hasRaportAccess) {
        await _reloadRaport();
      }
    });
  }

  @override
  void dispose() {
    widget.academicYearProvider.removeListener(_handleAcademicYearChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _handleAcademicYearChanged() {
    if (!_hasRaportAccess) {
      return;
    }
    _reloadRaport();
  }

  Future<void> _loadFilterOptions() async {
    final cache = ref.read(appMasterCacheProvider);
    final historiWaliKelas = await ref
        .read(historiWaliKelasServiceProvider)
        .getScopeByGuru(widget.guruUid, onlyAktif: true);
    final tahunAjaranWaliSet = historiWaliKelas
        .where((item) => !item.isDeleted && item.isAktif)
        .map((item) => item.tahunAjaranId)
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet();

    final tahunAjaranAll = await cache.getTahunAjaran(ref.read);
    final tahunAjaran = tahunAjaranAll
        .where((item) => tahunAjaranWaliSet.contains(item.id))
        .toList(growable: false);
    final kelas = await cache.getKelas(ref.read);
    final mapel = await cache.getMapel(ref.read);

    final kelasNamaById = {for (final item in kelas) item.id: item.namaKelas};
    final kelasIdByTahun = <String, Set<String>>{};
    for (final item in historiWaliKelas) {
      if (item.isDeleted || !item.isAktif) {
        continue;
      }
      final tahunId = item.tahunAjaranId.trim();
      final kelasId = item.kelasId.trim();
      if (tahunId.isEmpty || kelasId.isEmpty) {
        continue;
      }
      kelasIdByTahun.putIfAbsent(tahunId, () => <String>{}).add(kelasId);
    }

    final kelasOptionsByTahun = <String, List<_DropdownOption>>{};
    for (final entry in kelasIdByTahun.entries) {
      final kelasOptions =
          entry.value
              .where(kelasNamaById.containsKey)
              .map(
                (kelasId) => _DropdownOption(
                  id: kelasId,
                  label: kelasNamaById[kelasId]!,
                ),
              )
              .toList(growable: false)
            ..sort((a, b) => a.label.compareTo(b.label));
      kelasOptionsByTahun[entry.key] = [
        const _DropdownOption(id: _allFilterValue, label: 'Semua Kelas'),
        ...kelasOptions,
      ];
    }

    String? activeTahunAjaranId;
    for (final item in tahunAjaran) {
      if (item.aktif) {
        activeTahunAjaranId = item.id;
        break;
      }
    }

    if (!mounted) {
      return;
    }

    final hasAccess = tahunAjaran.isNotEmpty;
    final sortedTahunAjaran = tahunAjaran
      ..sort((a, b) => b.nama.compareTo(a.nama));
    final defaultYearId = hasAccess
        ? (activeTahunAjaranId ?? sortedTahunAjaran.first.id)
        : null;

    setState(() {
      _hasRaportAccess = hasAccess;

      _tahunAjaranOptions = tahunAjaran
          .map((item) => _DropdownOption(id: item.id, label: item.nama))
          .toList(growable: false);

      _kelasOptionsByTahun = kelasOptionsByTahun;

      _mapelOptions = [
        const _DropdownOption(id: _allFilterValue, label: 'Semua Mapel'),
        ...mapel
            .map((item) => _DropdownOption(id: item.id, label: item.namaMapel))
            .toList()
          ..sort((a, b) => a.label.compareTo(b.label)),
      ];

      if (!hasAccess) {
        _selectedTahunAjaranId = _allFilterValue;
      } else if (!tahunAjaran.any(
        (item) => item.id == _selectedTahunAjaranId,
      )) {
        _selectedTahunAjaranId = defaultYearId!;
      }

      _kelasOptions = _resolveKelasOptionsForTahun(_selectedTahunAjaranId);
      if (!_kelasOptions.any((item) => item.id == _selectedKelasId)) {
        _selectedKelasId = _allFilterValue;
      }
    });
  }

  List<_DropdownOption> _resolveKelasOptionsForTahun(String tahunAjaranId) {
    if (tahunAjaranId == _allFilterValue) {
      final merged = <String, _DropdownOption>{};
      for (final options in _kelasOptionsByTahun.values) {
        for (final option in options) {
          if (option.id == _allFilterValue) {
            continue;
          }
          merged[option.id] = option;
        }
      }
      final sorted = merged.values.toList(growable: false)
        ..sort((a, b) => a.label.compareTo(b.label));
      return [
        const _DropdownOption(id: _allFilterValue, label: 'Semua Kelas'),
        ...sorted,
      ];
    }

    return _kelasOptionsByTahun[tahunAjaranId] ??
        const <_DropdownOption>[
          _DropdownOption(id: _allFilterValue, label: 'Semua Kelas'),
        ];
  }

  Future<void> _reloadRaport({bool forceRefreshData = false}) async {
    try {
      await ref
          .read(raportGuruSupabaseProvider(widget.guruUid).notifier)
          .getRaport(
            kelasId: _selectedKelasId == _allFilterValue
                ? null
                : _selectedKelasId,
            tahunAjaranId: _selectedTahunAjaranId == _allFilterValue
                ? null
                : _selectedTahunAjaranId,
            mataPelajaranId: _selectedMapelId == _allFilterValue
                ? null
                : _selectedMapelId,
            forceRefreshData: forceRefreshData,
          );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal memuat raport: $e')));
    }
  }

  String _displayScore(double? value) {
    if (value == null) {
      return '-';
    }
    return value.toStringAsFixed(1);
  }

  _GradeMeta _gradeFromScore(double? nilaiAkhir) {
    if (nilaiAkhir == null) {
      return const _GradeMeta(label: '-', color: Color(0xFF9E9E9E));
    }

    if (nilaiAkhir >= 90) {
      return const _GradeMeta(label: 'A', color: Color(0xFF2E7D32));
    }
    if (nilaiAkhir >= 80) {
      return const _GradeMeta(label: 'B', color: Color(0xFF1565C0));
    }
    if (nilaiAkhir >= 70) {
      return const _GradeMeta(label: 'C', color: Color(0xFFEF6C00));
    }
    return const _GradeMeta(label: 'D', color: Color(0xFFC62828));
  }

  List<_StudentRaportView> _buildViewItems(List<RaportSiswaRingkasan> input) {
    final all = input
        .map((siswa) {
          final utsScores = siswa.nilai
              .map((row) => row.nilaiUts)
              .whereType<double>()
              .toList();
          final uasScores = siswa.nilai
              .map((row) => row.nilaiUas)
              .whereType<double>()
              .toList();
          final tugasScores = siswa.nilai
              .map((row) => row.nilaiTugas)
              .whereType<double>()
              .toList();
          final akhirScores = siswa.nilai
              .map((row) => row.nilaiAkhir)
              .whereType<double>()
              .toList();

          double? avg(List<double> values) {
            if (values.isEmpty) {
              return null;
            }
            return values.reduce((a, b) => a + b) / values.length;
          }

          return _StudentRaportView(
            siswa: siswa,
            nilaiTugas: avg(tugasScores),
            nilaiUts: avg(utsScores),
            nilaiUas: avg(uasScores),
            nilaiAkhir: avg(akhirScores),
          );
        })
        .where((item) {
          if (_searchQuery.trim().isEmpty) {
            return true;
          }
          final query = _searchQuery.trim().toLowerCase();
          return item.siswa.siswaNama.toLowerCase().contains(query);
        })
        .toList();

    switch (_sortOption) {
      case _RaportSortOption.rankingTertinggi:
        all.sort((a, b) => (b.nilaiAkhir ?? -1).compareTo(a.nilaiAkhir ?? -1));
        break;
      case _RaportSortOption.rankingTerendah:
        all.sort(
          (a, b) => (a.nilaiAkhir ?? 999).compareTo(b.nilaiAkhir ?? 999),
        );
        break;
      case _RaportSortOption.namaAZ:
        all.sort(
          (a, b) => a.siswa.siswaNama.toLowerCase().compareTo(
            b.siswa.siswaNama.toLowerCase(),
          ),
        );
        break;
      case _RaportSortOption.namaZA:
        all.sort(
          (a, b) => b.siswa.siswaNama.toLowerCase().compareTo(
            a.siswa.siswaNama.toLowerCase(),
          ),
        );
        break;
    }

    return all;
  }

  String _avatarInitial(String siswaNama) {
    final trimmed = siswaNama.trim();
    if (trimmed.isEmpty) {
      return '?';
    }
    return trimmed.substring(0, 1).toUpperCase();
  }

  void _showDetailRaport(_StudentRaportView view, int ranking, int totalSiswa) {
    final mapelById = {for (final item in _mapelOptions) item.id: item.label};
    final grade = _gradeFromScore(view.nilaiAkhir);
    final catatan = view.siswa.nilai
        .map((row) => row.catatan?.trim())
        .whereType<String>()
        .where((row) => row.isNotEmpty)
        .toSet()
        .toList();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.82,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    view.siswa.siswaNama,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        avatar: const Icon(Icons.leaderboard, size: 18),
                        label: Text('Ranking Kelas #$ranking dari $totalSiswa'),
                      ),
                      Chip(
                        label: Text('Grade ${grade.label}'),
                        backgroundColor: grade.color.withAlpha(30),
                        side: BorderSide(color: grade.color.withAlpha(70)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildDetailStat(
                        'Rata-rata',
                        _displayScore(view.nilaiAkhir),
                      ),
                      _buildDetailStat(
                        'Nilai UTS',
                        _displayScore(view.nilaiUts),
                      ),
                      _buildDetailStat(
                        'Nilai Tugas',
                        _displayScore(view.nilaiTugas),
                      ),
                      _buildDetailStat(
                        'Nilai UAS',
                        _displayScore(view.nilaiUas),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Seluruh Komponen Nilai',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      itemCount: view.siswa.nilai.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final row = view.siswa.nilai[index];
                        final mapelName =
                            mapelById[row.mataPelajaranId] ??
                            row.mataPelajaranId;
                        final rowGrade = _gradeFromScore(row.nilaiAkhir);
                        return Card(
                          elevation: 0,
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: ListTile(
                            title: Text(mapelName),
                            subtitle: Text(
                              'UTS: ${_displayScore(row.nilaiUts)} - '
                              'Tugas: ${_displayScore(row.nilaiTugas)} - '
                              'UAS: ${_displayScore(row.nilaiUas)} - '
                              'Akhir: ${_displayScore(row.nilaiAkhir)}',
                            ),
                            trailing: CircleAvatar(
                              radius: 14,
                              backgroundColor: rowGrade.color.withAlpha(30),
                              child: Text(
                                rowGrade.label,
                                style: TextStyle(
                                  color: rowGrade.color,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (catatan.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Catatan Guru',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      catatan.join('\n- '),
                      style: const TextStyle(height: 1.4),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Fitur print/export akan segera hadir',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.print_outlined),
                      label: const Text('Print / Export'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(raportGuruSupabaseProvider(widget.guruUid));
    final siswaView = _buildViewItems(state.siswa);

    return ListenableBuilder(
      listenable: widget.academicYearProvider,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: const Color(0xFFF4F7FB),
          appBar: AppBar(
            title: const Text('Raport Akademik'),
            actions: [
              IconButton(
                onPressed: () => _reloadRaport(forceRefreshData: true),
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
              ),
            ],
          ),
          body: _buildRaportContent(state, siswaView),
        );
      },
    );
  }

  Widget _buildRaportContent(
    RaportGuruState state,
    List<_StudentRaportView> siswaView,
  ) {
    if (!_hasRaportAccess) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Text(
              'Halaman raport hanya tersedia untuk guru yang pernah menjadi wali kelas.',
            ),
          ),
        ],
      );
    }

    if (state.isLoading && state.siswa.isEmpty) {
      return _buildLoadingState();
    }

    return RefreshIndicator(
      onRefresh: () => _reloadRaport(forceRefreshData: true),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _buildFilterSection(),
          const SizedBox(height: 12),
          if (state.error != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFCDD2)),
              ),
              child: Text(
                state.error!,
                style: const TextStyle(color: Color(0xFFB71C1C)),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Daftar Raport Siswa',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (state.isLoading)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: LinearProgressIndicator(minHeight: 3),
            ),
          _buildSiswaList(siswaView),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return AppExternalFilterBar(
      title: 'Filter Data',
      isExpanded: _isFilterVisible,
      onToggle: () {
        setState(() {
          _isFilterVisible = !_isFilterVisible;
        });
      },
      onReset: () {
        _searchController.clear();
        setState(() {
          if (_tahunAjaranOptions.isNotEmpty) {
            _selectedTahunAjaranId = _tahunAjaranOptions.first.id;
          }
          _selectedKelasId = _allFilterValue;
          _selectedMapelId = _allFilterValue;
          _searchQuery = '';
          _sortOption = _RaportSortOption.rankingTertinggi;
        });
        _reloadRaport();
      },
      onApply: _reloadRaport,
      children: [
        _buildFilterDropdown(
          width: 240,
          label: 'Tahun Ajaran',
          value: _selectedTahunAjaranId,
          options: _tahunAjaranOptions,
          onChanged: (value) async {
            setState(() {
              _selectedTahunAjaranId = value;
              _kelasOptions = _resolveKelasOptionsForTahun(value);
              if (!_kelasOptions.any((item) => item.id == _selectedKelasId)) {
                _selectedKelasId = _allFilterValue;
              }
            });
          },
          icon: Icons.calendar_today_rounded,
        ),
        _buildFilterDropdown(
          width: 240,
          label: 'Kelas',
          value: _selectedKelasId,
          options: _kelasOptions,
          onChanged: (value) async {
            setState(() {
              _selectedKelasId = value;
            });
          },
          icon: Icons.class_rounded,
        ),
        _buildFilterDropdown(
          width: 240,
          label: 'Mata Pelajaran',
          value: _selectedMapelId,
          options: _mapelOptions,
          onChanged: (value) async {
            setState(() {
              _selectedMapelId = value;
            });
          },
          icon: Icons.menu_book_rounded,
        ),
        SizedBox(
          width: 240,
          child: AppExternalFilterField(
            label: 'Search Nama',
            child: TextField(
              controller: _searchController,
              decoration:
                  appExternalFilterDecoration(
                    hintText: 'Cari nama siswa',
                    icon: Icons.search_rounded,
                  ).copyWith(
                    suffixIcon: _searchQuery.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                            icon: const Icon(Icons.close),
                          ),
                  ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
        ),
        _buildSortDropdown(240),
      ],
    );
  }

  Widget _buildSortDropdown(double width) {
    return SizedBox(
      width: width,
      child: AppExternalFilterField(
        label: 'Ranking',
        child: DropdownButtonFormField<_RaportSortOption>(
          initialValue: _sortOption,
          decoration: appExternalFilterDecoration(
            hintText: 'Pilih urutan',
            icon: Icons.sort_rounded,
          ),
          items: _RaportSortOption.values
              .map(
                (item) =>
                    DropdownMenuItem(value: item, child: Text(item.label)),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) {
              return;
            }
            setState(() {
              _sortOption = value;
            });
          },
        ),
      ),
    );
  }

  Widget _buildFilterDropdown({
    required double width,
    required String label,
    required String value,
    required List<_DropdownOption> options,
    required Future<void> Function(String value) onChanged,
    required IconData icon,
  }) {
    final safeValue = options.any((item) => item.id == value) ? value : null;

    return SizedBox(
      width: width,
      child: AppExternalFilterField(
        label: label,
        child: DropdownButtonFormField<String>(
          initialValue: safeValue,
          decoration: appExternalFilterDecoration(
            hintText: 'Pilih $label',
            icon: icon,
          ),
          items: options
              .map(
                (item) =>
                    DropdownMenuItem(value: item.id, child: Text(item.label)),
              )
              .toList(),
          onChanged: (newValue) async {
            if (newValue == null) {
              return;
            }
            await onChanged(newValue);
          },
        ),
      ),
    );
  }

  Widget _buildSiswaList(List<_StudentRaportView> siswaView) {
    if (siswaView.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(
              Icons.fact_check_outlined,
              size: 58,
              color: AppColors.textSecondary.withAlpha(150),
            ),
            const SizedBox(height: 14),
            const Text(
              'Belum ada data raport',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (int index = 0; index < siswaView.length; index++) ...[
          _buildStudentCard(
            siswaView[index],
            ranking: index + 1,
            total: siswaView.length,
          ),
          if (index != siswaView.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildStudentCard(
    _StudentRaportView view, {
    required int ranking,
    required int total,
  }) {
    final grade = _gradeFromScore(view.nilaiAkhir);
    final rankColor = ranking <= 3
        ? const [Color(0xFFFFD54F), Color(0xFFFFB300)]
        : const [Color(0xFFE0E0E0), Color(0xFFBDBDBD)];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _showDetailRaport(view, ranking, total),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(12),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: rankColor),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '#$ranking',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFFE3F2FD),
                      child: Text(
                        _avatarInitial(view.siswa.siswaNama),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1565C0),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              view.siswa.siswaNama,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: grade.color.withAlpha(28),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: grade.color.withAlpha(90),
                              ),
                            ),
                            child: Text(
                              grade.label,
                              style: TextStyle(
                                color: grade.color,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 6,
                        children: [
                          Text('UTS: ${_displayScore(view.nilaiUts)}'),
                          Text('Tugas: ${_displayScore(view.nilaiTugas)}'),
                          Text('UAS: ${_displayScore(view.nilaiUas)}'),
                          Text(
                            'Akhir: ${_displayScore(view.nilaiAkhir)}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded, color: Colors.black54),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailStat(String label, String value) {
    return Container(
      width: 150,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDE6FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(
            4,
            (_) => Container(
              width: (MediaQuery.sizeOf(context).width - 48) / 2,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          height: 130,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        const SizedBox(height: 14),
        ...List.generate(
          5,
          (index) => Container(
            margin: EdgeInsets.only(bottom: index == 4 ? 0 : 10),
            height: 96,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      ],
    );
  }
}

enum _RaportSortOption {
  rankingTertinggi('Ranking Tertinggi'),
  rankingTerendah('Ranking Terendah'),
  namaAZ('Nama A-Z'),
  namaZA('Nama Z-A');

  final String label;
  const _RaportSortOption(this.label);
}

class _StudentRaportView {
  final RaportSiswaRingkasan siswa;
  final double? nilaiTugas;
  final double? nilaiUts;
  final double? nilaiUas;
  final double? nilaiAkhir;

  const _StudentRaportView({
    required this.siswa,
    required this.nilaiTugas,
    required this.nilaiUts,
    required this.nilaiUas,
    required this.nilaiAkhir,
  });
}

class _GradeMeta {
  final String label;
  final Color color;

  const _GradeMeta({required this.label, required this.color});
}
