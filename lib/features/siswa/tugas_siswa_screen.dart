import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_external_filter_bar.dart';
import '../../models/tahun_ajaran_model.dart';
import '../../providers/supabase_providers.dart';
import 'providers/tugas_siswa_supabase_provider.dart';

class TugasSiswaScreen extends ConsumerStatefulWidget {
  final String siswaUid;

  const TugasSiswaScreen({super.key, required this.siswaUid});

  @override
  ConsumerState<TugasSiswaScreen> createState() => _TugasSiswaScreenState();
}

class _TugasSiswaScreenState extends ConsumerState<TugasSiswaScreen> {
  List<TahunAjaranRecord> _tahunAjaranList = const [];
  String? _selectedTahunAjaranId;
  int _selectedSemester = 1;
  String _selectedMapelId = 'all';
  String _selectedDeadlineStatus = 'all';
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

      await _loadTugas();
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isBootstrapping = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal memuat filter tugas: $e')));
    }
  }

  Future<void> _loadTugas({bool forceRefresh = false}) async {
    final tahunAjaranId = _selectedTahunAjaranId;
    if (tahunAjaranId == null) {
      return;
    }

    final notifier = ref.read(
      tugasSiswaSupabaseProvider(widget.siswaUid).notifier,
    );

    if (forceRefresh) {
      await notifier.refresh(
        tahunAjaranId: tahunAjaranId,
        semester: _selectedSemester,
      );
      return;
    }

    await notifier.getTugasBySiswa(
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
      _selectedDeadlineStatus = 'all';
    });
    await _loadTugas();
  }

  List<DropdownMenuItem<String>> _buildMapelItems(TugasSiswaState state) {
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

  bool _matchesDeadlineStatus(DateTime? deadline) {
    if (_selectedDeadlineStatus == 'all') {
      return true;
    }
    if (deadline == null) {
      return _selectedDeadlineStatus == 'tanpa_deadline';
    }

    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    final normalizedDeadline = DateTime(
      deadline.year,
      deadline.month,
      deadline.day,
    );

    switch (_selectedDeadlineStatus) {
      case 'aktif':
        return normalizedDeadline.isAfter(
              normalizedToday.subtract(const Duration(days: 1)),
            ) ||
            normalizedDeadline == normalizedToday;
      case 'lewat':
        return normalizedDeadline.isBefore(normalizedToday);
      case 'tanpa_deadline':
        return false;
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tugasSiswaSupabaseProvider(widget.siswaUid));
    final filteredData = state.data.where((item) {
      final byMapel =
          _selectedMapelId == 'all' || item.mapelId == _selectedMapelId;
      final byDeadline = _matchesDeadlineStatus(item.deadline);
      return byMapel && byDeadline;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tugas Siswa'),
        backgroundColor: const Color(0xFFF59E0B),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: (_isBootstrapping || state.isLoading)
                ? null
                : () => _loadTugas(forceRefresh: true),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isBootstrapping
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadTugas(forceRefresh: true),
              child: ListView(
                children: [
                  if (state.kelasNama != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF59E0B), Color(0xFFEA580C)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFF59E0B).withAlpha(51),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Tugas untuk Kelas',
                            style: TextStyle(fontSize: 12, color: Colors.white70),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            state.kelasNama!,
                            style: const TextStyle(
                              fontSize: 24,
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
                  _buildTugasList(state, filteredData),
                ],
              ),
            ),
    );
  }

  Widget _buildFilters() {
    final state = ref.watch(tugasSiswaSupabaseProvider(widget.siswaUid));
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
              await _loadTugas();
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
              await _loadTugas();
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
        AppExternalFilterField(
          label: 'Status Deadline',
          child: DropdownButtonFormField<String>(
            initialValue: _selectedDeadlineStatus,
            decoration: appExternalFilterDecoration(
              hintText: 'Pilih status deadline',
              icon: Icons.timer_outlined,
            ),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('Semua Deadline')),
              DropdownMenuItem(value: 'aktif', child: Text('Masih Aktif')),
              DropdownMenuItem(value: 'lewat', child: Text('Lewat Deadline')),
              DropdownMenuItem(
                value: 'tanpa_deadline',
                child: Text('Tanpa Deadline'),
              ),
            ],
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() {
                _selectedDeadlineStatus = value;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTugasList(
    TugasSiswaState state,
    List<TugasSiswaItem> visibleData,
  ) {
    if (visibleData.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 96),
        child: Column(
          children: [
            Icon(Icons.assignment_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Center(
              child: Text(
                'Belum ada tugas untuk filter yang dipilih',
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
        final deadlineColor = _getDeadlineColor(item.deadline);

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
                  item.judul,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.mapelNama,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 10),
                Text(item.deskripsi),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: deadlineColor.withAlpha(24),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.event, size: 16, color: deadlineColor),
                      const SizedBox(width: 8),
                      Text(
                        'Deadline: ${_formatDate(item.deadline)}',
                        style: TextStyle(
                          color: deadlineColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: (item.nilai != null
                            ? const Color(0xFF0F766E)
                            : Colors.grey)
                        .withAlpha(24),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.grade_rounded,
                        size: 16,
                        color: item.nilai != null
                            ? const Color(0xFF0F766E)
                            : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        item.nilai != null
                            ? 'Nilai: ${_formatNilai(item.nilai)}'
                            : 'Nilai: Belum dinilai',
                        style: TextStyle(
                          color: item.nilai != null
                              ? const Color(0xFF0F766E)
                              : Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return '-';
    }
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  String _formatNilai(double? nilai) {
    if (nilai == null) {
      return '-';
    }
    if (nilai == nilai.roundToDouble()) {
      return nilai.toInt().toString();
    }
    return nilai.toStringAsFixed(2);
  }

  Color _getDeadlineColor(DateTime? deadline) {
    if (deadline == null) {
      return Colors.grey;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDate = DateTime(deadline.year, deadline.month, deadline.day);

    if (dueDate.isBefore(today)) {
      return AppColors.error;
    }

    if (dueDate.difference(today).inDays <= 2) {
      return const Color(0xFFD97706);
    }

    return const Color(0xFF0F766E);
  }
}
