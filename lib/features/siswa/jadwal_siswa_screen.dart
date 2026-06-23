import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_external_filter_bar.dart';
import '../../models/tahun_ajaran_model.dart';
import '../../providers/supabase_providers.dart';
import 'providers/jadwal_siswa_supabase_provider.dart';

class JadwalSiswaScreen extends ConsumerStatefulWidget {
  final String siswaUid;

  const JadwalSiswaScreen({super.key, required this.siswaUid});

  @override
  ConsumerState<JadwalSiswaScreen> createState() => _JadwalSiswaScreenState();
}

class _JadwalSiswaScreenState extends ConsumerState<JadwalSiswaScreen> {
  List<TahunAjaranRecord> _tahunAjaranList = const [];
  String? _selectedTahunAjaranId;
  int _selectedSemester = 1;
  String _selectedHari = 'all';
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

      await _loadJadwal();
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isBootstrapping = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal memuat filter jadwal: $e')));
    }
  }

  Future<void> _loadJadwal({bool forceRefresh = false}) async {
    final tahunAjaranId = _selectedTahunAjaranId;
    if (tahunAjaranId == null) {
      return;
    }

    final notifier = ref.read(
      jadwalSiswaSupabaseProvider(widget.siswaUid).notifier,
    );

    if (forceRefresh) {
      await notifier.refresh(
        tahunAjaranId: tahunAjaranId,
        semester: _selectedSemester,
      );
      return;
    }

    await notifier.getJadwalBySiswa(
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
      _selectedHari = 'all';
    });
    await _loadJadwal();
  }

  List<DropdownMenuItem<String>> _buildHariItems(JadwalSiswaState state) {
    final hari = state.data.map((item) => item.hari).toSet().toList()..sort();
    return [
      const DropdownMenuItem<String>(value: 'all', child: Text('Semua Hari')),
      ...hari.map(
        (item) => DropdownMenuItem<String>(value: item, child: Text(item)),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(jadwalSiswaSupabaseProvider(widget.siswaUid));
    final filteredData = _selectedHari == 'all'
        ? state.data
        : state.data.where((item) => item.hari == _selectedHari).toList();
    final groupedByHari = <String, List<JadwalSiswaItem>>{};
    for (final row in filteredData) {
      groupedByHari.putIfAbsent(row.hari, () => []);
      groupedByHari[row.hari]!.add(row);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jadwal Pelajaran'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: (_isBootstrapping || state.isLoading)
                ? null
                : () => _loadJadwal(forceRefresh: true),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isBootstrapping
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadJadwal(forceRefresh: true),
              child: ListView(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(13),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 36,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Kelas ${state.kelasNama ?? '-'}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
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
                  _buildJadwalList(groupedByHari),
                ],
              ),
            ),
    );
  }

  Widget _buildFilters() {
    final state = ref.watch(jadwalSiswaSupabaseProvider(widget.siswaUid));
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
              await _loadJadwal();
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
              await _loadJadwal();
            },
          ),
        ),
        AppExternalFilterField(
          label: 'Hari',
          child: DropdownButtonFormField<String>(
            initialValue: _selectedHari,
            decoration: appExternalFilterDecoration(
              hintText: 'Pilih hari',
              icon: Icons.view_week_rounded,
            ),
            items: _buildHariItems(state),
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() {
                _selectedHari = value;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildJadwalList(Map<String, List<JadwalSiswaItem>> groupedByHari) {
    const dayOrder = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
    final activeDays = dayOrder
        .where((day) => (groupedByHari[day] ?? const []).isNotEmpty)
        .toList();

    if (activeDays.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 96),
        child: Column(
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Center(
              child: Text(
                'Tidak ada jadwal untuk filter yang dipilih',
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
      itemCount: activeDays.length,
      itemBuilder: (context, index) {
        final hari = activeDays[index];
        final rows = groupedByHari[hari] ?? const [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.today, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    hari,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            ...rows.map(_buildJadwalCard),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildJadwalCard(JadwalSiswaItem item) {
    final waktu = (item.waktuMulai != null && item.waktuSelesai != null)
        ? '${item.waktuMulai} - ${item.waktuSelesai}'
        : '-';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  item.jamKe.toString(),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.mapelNama,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.jamKe == item.jamAkhir
                        ? 'Jam ke-${item.jamKe}  •  Waktu: $waktu'
                        : 'Jam ke-${item.jamKe} s.d. ke-${item.jamAkhir}  •  Waktu: $waktu',
                  ),
                  if (item.ruangan != null && item.ruangan!.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text('Ruangan: ${item.ruangan}'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
