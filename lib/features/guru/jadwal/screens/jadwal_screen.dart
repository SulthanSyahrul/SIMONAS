import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/academic_year_provider.dart';
import '../../../../core/widgets/app_external_filter_bar.dart';
import '../../../../providers/supabase_providers.dart';
import '../../providers/jadwal_guru_supabase_provider.dart';

/// Screen untuk menampilkan jadwal mengajar guru
/// Data bersumber dari Firestore berdasarkan `guru_uid`.
class GuruJadwalScreen extends ConsumerStatefulWidget {
  final AcademicYearProvider academicYearProvider;
  final String guruUid;

  const GuruJadwalScreen({
    super.key,
    required this.academicYearProvider,
    required this.guruUid,
  });

  @override
  ConsumerState<GuruJadwalScreen> createState() => _GuruJadwalScreenState();
}

class _GuruJadwalScreenState extends ConsumerState<GuruJadwalScreen> {
  String _semesterFilter = 'all';
  bool _isFilterVisible = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadReferenceData);
  }

  String? get _selectedTahunAjaranId {
    return ref.read(tahunAjaranProvider).selectedTahunAjaranId;
  }

  Future<void> _loadReferenceData({bool forceRefreshData = false}) async {
    try {
      await ref
          .read(tahunAjaranProvider.notifier)
          .loadTahunAjaran(forceRefreshData: forceRefreshData);

      final tahunAjaranState = ref.read(tahunAjaranProvider);
      widget.academicYearProvider.replaceAvailableYears(
        tahunAjaranState.options.map((item) => item.nama).toList(),
        preferredYear: tahunAjaranState.selectedOption?.nama,
      );

      final tahunAjaranId = tahunAjaranState.selectedTahunAjaranId;
      if (tahunAjaranId == null) {
        return;
      }

      await _reloadJadwal(
        tahunAjaranId: tahunAjaranId,
        forceRefreshData: forceRefreshData,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal memuat tahun ajaran: $e')));
    }
  }

  Future<void> _reloadJadwal({
    required String tahunAjaranId,
    bool forceRefreshData = false,
  }) async {
    try {
      final tahunAjaranState = ref.read(tahunAjaranProvider);
      final selectedLabel = tahunAjaranState.selectedOption?.nama;
      if (selectedLabel != null && selectedLabel.trim().isNotEmpty) {
        widget.academicYearProvider.setYear(selectedLabel);
      }

      await ref
          .read(jadwalGuruSupabaseProvider(widget.guruUid).notifier)
          .getJadwalByGuru(
            tahunAjaranId: tahunAjaranId,
            forceRefreshData: forceRefreshData,
            forceRefreshCache: forceRefreshData,
          );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal memuat jadwal: $e')));
    }
  }

  Future<void> _onTahunAjaranChanged(String? tahunAjaranId) async {
    if (tahunAjaranId == null) {
      return;
    }

    ref.read(tahunAjaranProvider.notifier).setSelectedTahunAjaran(tahunAjaranId);
    final selected = ref.read(tahunAjaranProvider).selectedOption;
    if (selected != null) {
      widget.academicYearProvider.setYear(selected.nama);
    }
    await _reloadJadwal(tahunAjaranId: tahunAjaranId);
  }

  List<JadwalGuruItem> _filterData(List<JadwalGuruItem> items) {
    if (_semesterFilter == 'all') {
      return items;
    }

    final selectedSemester = int.tryParse(_semesterFilter);
    if (selectedSemester == null) {
      return items;
    }

    return items
        .where((item) => item.semester == selectedSemester)
        .toList(growable: false);
  }

  Map<String, List<JadwalGuruItem>> _groupByHari(List<JadwalGuruItem> items) {
    final grouped = <String, List<JadwalGuruItem>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.hari, () => <JadwalGuruItem>[]);
      grouped[item.hari]!.add(item);
    }

    const dayOrder = <String, int>{
      'Senin': 1,
      'Selasa': 2,
      'Rabu': 3,
      'Kamis': 4,
      'Jumat': 5,
      'Sabtu': 6,
      'Minggu': 7,
    };

    final entries = grouped.entries.toList()
      ..sort(
        (a, b) => (dayOrder[a.key] ?? 99).compareTo(dayOrder[b.key] ?? 99),
      );

    final sorted = <String, List<JadwalGuruItem>>{};
    for (final entry in entries) {
      entry.value.sort((a, b) {
        if (a.semester != b.semester) {
          return a.semester.compareTo(b.semester);
        }
        if (a.jamAwal != b.jamAwal) {
          return a.jamAwal.compareTo(b.jamAwal);
        }
        return a.jamAkhir.compareTo(b.jamAkhir);
      });
      sorted[entry.key] = entry.value;
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(jadwalGuruSupabaseProvider(widget.guruUid));
    final tahunAjaranState = ref.watch(tahunAjaranProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jadwal Mengajar'),
        actions: [
          IconButton(
            onPressed: () => _loadReferenceData(forceRefreshData: true),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: AppExternalFilterBar(
              margin: EdgeInsets.zero,
              isExpanded: _isFilterVisible,
              onToggle: () {
                setState(() {
                  _isFilterVisible = !_isFilterVisible;
                });
              },
              onReset: () async {
                final activeId = tahunAjaranState.options
                    .where((item) => item.aktif)
                    .map((item) => item.id)
                    .cast<String?>()
                    .firstWhere((item) => item != null, orElse: () => null);
                final nextId =
                    activeId ??
                    (tahunAjaranState.options.isEmpty
                        ? null
                        : tahunAjaranState.options.first.id);
                if (nextId == null) {
                  return;
                }

                setState(() {
                  _semesterFilter = 'all';
                });
                await _onTahunAjaranChanged(nextId);
              },
              onApply: () {},
              children: [
                AppExternalFilterField(
                  label: 'Tahun Ajaran',
                  child: DropdownButtonFormField<String>(
                    initialValue: tahunAjaranState.selectedTahunAjaranId,
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
                  label: 'Semester',
                  child: DropdownButtonFormField<String>(
                    initialValue: _semesterFilter,
                    decoration: appExternalFilterDecoration(
                      hintText: 'Semua semester',
                      icon: Icons.calendar_month_rounded,
                    ),
                    items: const [
                      DropdownMenuItem<String>(
                        value: 'all',
                        child: Text('Semua Semester'),
                      ),
                      DropdownMenuItem<String>(
                        value: '1',
                        child: Text('Semester 1'),
                      ),
                      DropdownMenuItem<String>(
                        value: '2',
                        child: Text('Semester 2'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _semesterFilter = value ?? 'all';
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _buildBody(state),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(JadwalGuruState state) {
    final filteredItems = _filterData(state.data);

    if (state.isLoading && state.data.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.data.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(state.error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () async {
                  final tahunAjaranId = _selectedTahunAjaranId;
                  if (tahunAjaranId == null) {
                    return;
                  }
                  await _reloadJadwal(
                    tahunAjaranId: tahunAjaranId,
                    forceRefreshData: true,
                  );
                },
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    if (filteredItems.isEmpty) {
      return _buildEmptyState(context);
    }

    final groupedEntries = _groupByHari(filteredItems).entries.toList();
    final tahunAjaranId = _selectedTahunAjaranId;

    return RefreshIndicator(
      onRefresh: () async {
        if (tahunAjaranId == null) {
          return;
        }
        await _reloadJadwal(
          tahunAjaranId: tahunAjaranId,
          forceRefreshData: true,
        );
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 16),
        itemCount: groupedEntries.length,
        itemBuilder: (context, index) {
          final group = groupedEntries[index];
          final hari = group.key;
          final jadwals = group.value;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  hari,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              ...jadwals.map(_buildJadwalCard),
              if (index < groupedEntries.length - 1)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(thickness: 1),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildJadwalCard(JadwalGuruItem jadwal) {
    final waktuMulai = jadwal.waktuMulai ?? '--:--';
    final waktuSelesai = jadwal.waktuSelesai ?? '--:--';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(child: Text('${jadwal.jamKe}')),
        title: Text(jadwal.mapelNama),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kelas: ${jadwal.kelasNama}'),
            Text('Semester: ${jadwal.semester}'),
            Text(
              jadwal.jamAwal == jadwal.jamAkhir
                  ? 'Jam ke ${jadwal.jamAwal} ($waktuMulai - $waktuSelesai)'
                  : 'Jam ke ${jadwal.jamAwal} - ${jadwal.jamAkhir} ($waktuMulai - $waktuSelesai)',
            ),
          ],
        ),
      ),
    );
  }

  /// Widget untuk kondisi ketika tidak ada jadwal
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Tidak ada jadwal',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Jadwal mengajar belum tersedia untuk filter yang dipilih',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}
