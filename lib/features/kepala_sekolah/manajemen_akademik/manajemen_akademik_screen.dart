import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/providers/academic_year_provider.dart';
import '../../../models/tahun_ajaran_model.dart';
import '../../../providers/supabase_providers.dart';
import 'jadwal_guru_tab.dart';
import '../tahun_ajaran/screens/tahun_ajaran_management_screen.dart';
import 'wali_kelas_tab.dart';

class ManajemenAkademikScreen extends ConsumerStatefulWidget {
  final AcademicYearProvider academicYearProvider;

  const ManajemenAkademikScreen({
    super.key,
    required this.academicYearProvider,
  });

  @override
  ConsumerState<ManajemenAkademikScreen> createState() =>
      _ManajemenAkademikScreenState();
}

class _ManajemenAkademikScreenState
    extends ConsumerState<ManajemenAkademikScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<TahunAjaranRecord> _tahunAjaranOptions = const [];
  String? _selectedTahunAjaranId;
  bool _isLoadingYears = true;
  String? _errorYears;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    Future.microtask(_loadTahunAjaran);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTahunAjaran() async {
    setState(() {
      _isLoadingYears = true;
      _errorYears = null;
    });

    try {
      final years = await ref
          .read(tahunAjaranServiceProvider)
          .getAllLite();
      final sorted = [...years]
        ..sort((a, b) => b.nama.toLowerCase().compareTo(a.nama.toLowerCase()));

      String? nextSelectedId = _selectedTahunAjaranId;
      if (sorted.isNotEmpty) {
        final active = sorted.where((item) => item.aktif).toList();
        if (nextSelectedId == null ||
            !sorted.any((item) => item.id == nextSelectedId)) {
          nextSelectedId = active.isNotEmpty
              ? active.first.id
              : sorted.first.id;
        }
      } else {
        nextSelectedId = null;
      }

      setState(() {
        _tahunAjaranOptions = sorted;
        _selectedTahunAjaranId = nextSelectedId;
        _isLoadingYears = false;
      });

      final selectedLabel = _selectedTahunAjaranLabel;
      if (selectedLabel != null &&
          widget.academicYearProvider.availableYears.contains(selectedLabel)) {
        widget.academicYearProvider.setYear(selectedLabel);
      }
    } catch (e) {
      setState(() {
        _isLoadingYears = false;
        _errorYears = 'Gagal memuat tahun ajaran: $e';
      });
    }
  }

  String? get _selectedTahunAjaranLabel {
    if (_selectedTahunAjaranId == null) {
      return null;
    }

    for (final item in _tahunAjaranOptions) {
      if (item.id == _selectedTahunAjaranId) {
        return item.nama;
      }
    }
    return null;
  }

  Future<void> _openTahunAjaranManagement() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => const TahunAjaranManagementScreen(),
      ),
    );

    if (!mounted) {
      return;
    }

    await _loadTahunAjaran();
  }

  @override
  Widget build(BuildContext context) {
    final selectedId = _selectedTahunAjaranId;
    final selectedLabel = _selectedTahunAjaranLabel;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Akademik'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Jadwal Guru'),
            Tab(text: 'Wali Kelas'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _isLoadingYears ? null : _loadTahunAjaran,
            child: const Text(
              'Refresh',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            onPressed: _openTahunAjaranManagement,
            icon: const Icon(Icons.manage_accounts_outlined),
            tooltip: 'Kelola Tahun Ajaran',
          ),
        ],
      ),
      body: _isLoadingYears
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_errorYears != null && _errorYears!.isNotEmpty)
                  Container(
                    width: double.infinity,
                    color: AppColors.error.withAlpha(20),
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      _errorYears!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                Expanded(
                  child: selectedId == null
                      ? const Center(
                          child: Text(
                            'Belum ada data tahun ajaran. Tambahkan tahun ajaran terlebih dahulu.',
                          ),
                        )
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            JadwalGuruTab(
                              selectedTahunAjaran: selectedLabel ?? '-',
                              tahunAjaranId: selectedId,
                              tahunAjaranOptions: _tahunAjaranOptions,
                              onTahunAjaranChanged: _onTahunAjaranChanged,
                            ),
                            WaliKelasTab(
                              selectedTahunAjaran: selectedLabel ?? '-',
                              tahunAjaranId: selectedId,
                              tahunAjaranOptions: _tahunAjaranOptions,
                              onTahunAjaranChanged: _onTahunAjaranChanged,
                            ),
                          ],
                        ),
                ),
              ],
            ),
    );
  }

  void _onTahunAjaranChanged(String value) {
    setState(() {
      _selectedTahunAjaranId = value;
    });

    final selected = _tahunAjaranOptions
        .where((item) => item.id == value)
        .toList();
    if (selected.isNotEmpty &&
        widget.academicYearProvider.availableYears.contains(
          selected.first.nama,
        )) {
      widget.academicYearProvider.setYear(selected.first.nama);
    }
  }
}
