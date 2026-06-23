import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_external_filter_bar.dart';
import '../../models/tahun_ajaran_model.dart';
import '../../providers/supabase_providers.dart';
import 'providers/nilai_siswa_supabase_provider.dart';

class NilaiSiswaScreen extends ConsumerStatefulWidget {
  final String siswaUid;

  const NilaiSiswaScreen({super.key, required this.siswaUid});

  @override
  ConsumerState<NilaiSiswaScreen> createState() => _NilaiSiswaScreenState();
}

class _NilaiSiswaScreenState extends ConsumerState<NilaiSiswaScreen> {
  List<TahunAjaranRecord> _tahunAjaranList = const [];
  String? _selectedTahunAjaranId;
  int _selectedSemester = 1;
  String _selectedMapelId = 'all';
  bool _isBootstrapping = true;
  bool _isFilterVisible = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(_bootstrap);
  }

  Future<void> _bootstrap() async {
    try {
      final tahunAjaran = await ref
          .read(tahunAjaranServiceProvider)
          .getAllIncremental();

      final sorted = [...tahunAjaran]
        ..sort((a, b) => b.nama.toLowerCase().compareTo(a.nama.toLowerCase()));
      final active = sorted.where((row) => row.aktif).toList();

      final selectedTahun = active.isNotEmpty
          ? active.first.id
          : (sorted.isNotEmpty ? sorted.first.id : null);
      final selectedSemester = active.isNotEmpty
          ? (active.first.semesterAktif ?? 1)
          : 1;

      if (!mounted) {
        return;
      }

      setState(() {
        _tahunAjaranList = sorted;
        _selectedTahunAjaranId = selectedTahun;
        _selectedSemester = selectedSemester;
        _isBootstrapping = false;
      });

      await _loadNilai();
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isBootstrapping = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal memuat filter nilai: $e')));
    }
  }

  Future<void> _loadNilai({bool forceRefresh = false}) async {
    final tahunAjaranId = _selectedTahunAjaranId;
    if (tahunAjaranId == null) {
      return;
    }

    final notifier = ref.read(
      nilaiSiswaSupabaseProvider(widget.siswaUid).notifier,
    );

    if (forceRefresh) {
      await notifier.refresh(
        tahunAjaranId: tahunAjaranId,
        semester: _selectedSemester,
      );
      return;
    }

    await notifier.getNilaiBySiswa(
      tahunAjaranId: tahunAjaranId,
      semester: _selectedSemester,
    );
  }

  Future<void> _resetFilters() async {
    if (_tahunAjaranList.isEmpty) {
      return;
    }

    final active = _tahunAjaranList.where((row) => row.aktif).toList();
    setState(() {
      _selectedTahunAjaranId = active.isNotEmpty
          ? active.first.id
          : _tahunAjaranList.first.id;
      _selectedSemester = active.isNotEmpty
          ? (active.first.semesterAktif ?? 1)
          : 1;
      _selectedMapelId = 'all';
    });
    await _loadNilai();
  }

  List<DropdownMenuItem<String>> _buildMapelItems(
    NilaiSiswaSupabaseState state,
  ) {
    final options = {
      for (final item in state.data) item.mapelId: item.mapelNama,
    }.entries.toList()..sort((a, b) => a.value.compareTo(b.value));

    return [
      const DropdownMenuItem<String>(
        value: 'all',
        child: Text('Semua Mata Pelajaran'),
      ),
      ...options.map(
        (entry) => DropdownMenuItem<String>(
          value: entry.key,
          child: Text(entry.value),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(nilaiSiswaSupabaseProvider(widget.siswaUid));
    final filteredData = _selectedMapelId == 'all'
        ? state.data
        : state.data.where((item) => item.mapelId == _selectedMapelId).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nilai Siswa'),
        backgroundColor: const Color(0xFF10B981),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: (_isBootstrapping || state.isLoading)
                ? null
                : () => _loadNilai(forceRefresh: true),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isBootstrapping
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadNilai(forceRefresh: true),
              child: ListView(
                children: [
                  _buildFilters(),
                  if (state.error != null && state.error!.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      color: AppColors.error.withAlpha(20),
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
                  _buildNilaiList(state, filteredData),
                ],
              ),
            ),
    );
  }

  Widget _buildFilters() {
    final state = ref.watch(nilaiSiswaSupabaseProvider(widget.siswaUid));
    return AppExternalFilterBar(
      isExpanded: _isFilterVisible,
      onToggle: () {
        setState(() {
          _isFilterVisible = !_isFilterVisible;
        });
      },
      onReset: _resetFilters,
      onApply: () {},
      isBusy: _isBootstrapping,
      children: [
        AppExternalFilterField(
          label: 'Tahun Ajaran',
          child: DropdownButtonFormField<String>(
            initialValue: _selectedTahunAjaranId,
            decoration: appExternalFilterDecoration(
              hintText: 'Pilih tahun ajaran',
              icon: Icons.school_rounded,
            ),
            items: _tahunAjaranList
                .map(
                  (row) => DropdownMenuItem<String>(
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
                _selectedTahunAjaranId = value;
              });
              await _loadNilai();
            },
          ),
        ),
        AppExternalFilterField(
          label: 'Semester',
          child: DropdownButtonFormField<int>(
            initialValue: _selectedSemester,
            decoration: appExternalFilterDecoration(
              hintText: 'Pilih semester',
              icon: Icons.calendar_month_rounded,
            ),
            items: const [
              DropdownMenuItem<int>(value: 1, child: Text('Ganjil')),
              DropdownMenuItem<int>(value: 2, child: Text('Genap')),
            ],
            onChanged: (value) async {
              if (value == null) {
                return;
              }
              setState(() {
                _selectedSemester = value;
              });
              await _loadNilai();
            },
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
            items: _buildMapelItems(state),
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() {
                _selectedMapelId = value;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNilaiList(
    NilaiSiswaSupabaseState state,
    List<NilaiSiswaItem> visibleData,
  ) {
    if (visibleData.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 96),
        child: Column(
          children: [
            Icon(Icons.assessment_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Center(
              child: Text(
                'Belum ada nilai untuk filter yang dipilih',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: visibleData.length,
      itemBuilder: (context, index) {
        final item = visibleData[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.mapelNama,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Kelas: ${item.kelasNama}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _buildNilaiBox('UTS', item.nilaiUts)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildNilaiBox('UAS', item.nilaiUas)),
                  ],
                ),
                if (item.catatan != null && item.catatan!.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      'Catatan: ${item.catatan}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNilaiBox(String label, double? value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withAlpha(18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatNilai(value),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF047857),
            ),
          ),
        ],
      ),
    );
  }

  String _formatNilai(double? value) {
    if (value == null) {
      return '-';
    }

    final rounded = value.roundToDouble();
    if (rounded == value) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }
}
