import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_external_filter_bar.dart';
import '../../models/jurnal_model.dart';
import '../../models/model_utils.dart';
import '../../providers/supabase_providers.dart';
import 'providers/histori_presensi_siswa_supabase_provider.dart';

class HistoriPresensiSiswaScreen extends ConsumerStatefulWidget {
  final String siswaUid;

  const HistoriPresensiSiswaScreen({super.key, required this.siswaUid});

  @override
  ConsumerState<HistoriPresensiSiswaScreen> createState() =>
      _HistoriPresensiSiswaScreenState();
}

class _HistoriPresensiSiswaScreenState
    extends ConsumerState<HistoriPresensiSiswaScreen>
    with TickerProviderStateMixin {
  static const String _allValue = '__all__';

  bool _isFilterVisible = false;
  bool _isMetadataLoading = false;
  String _selectedTahunAjaran = _allValue;
  String _selectedSemester = _allValue;
  String _selectedBulan = _allValue;
  String _selectedStatus = _allValue;
  String _selectedMapel = _allValue;
  DateTimeRange? _selectedDateRange;

  final Map<String, _JurnalMeta> _jurnalMetaById = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadHistori);
  }

  Future<void> _loadHistori({bool forceRefresh = false}) async {
    final notifier = ref.read(
      historiPresensiSiswaSupabaseProvider(widget.siswaUid).notifier,
    );

    if (forceRefresh) {
      await notifier.refresh();
    } else {
      await notifier.getHistoriPresensi();
    }

    if (!mounted) {
      return;
    }

    final state = ref.read(
      historiPresensiSiswaSupabaseProvider(widget.siswaUid),
    );
    await _loadJournalMetadata(state.data, forceRefresh: forceRefresh);
  }

  Future<void> _loadJournalMetadata(
    List<HistoriPresensiItem> items, {
    required bool forceRefresh,
  }) async {
    final jurnalIds = items
        .map((item) => item.jurnalId.trim())
        .where((value) => value.isNotEmpty)
        .toSet();

    if (jurnalIds.isEmpty) {
      return;
    }

    final knownIds = _jurnalMetaById.keys.toSet();
    final idsToLoad = forceRefresh ? jurnalIds : jurnalIds.difference(knownIds);
    if (idsToLoad.isEmpty) {
      return;
    }

    if (mounted) {
      setState(() {
        _isMetadataLoading = true;
      });
    }

    try {
      final jurnalService = ref.read(jurnalServiceProvider);
      final kelasRecords = await ref
          .read(kelasServiceProvider)
          .getAllIncremental(forceFullFetch: forceRefresh);
      final kelasNames = {
        for (final row in kelasRecords) row.id: row.namaKelas,
      };

      final tahunRecords = await ref
          .read(tahunAjaranServiceProvider)
          .getAllIncremental(forceFullFetch: forceRefresh);
      final tahunNames = {for (final row in tahunRecords) row.id: row.nama};

      final mapelRecords = await ref
          .read(mapelServiceProvider)
          .getAllIncremental(forceFullFetch: forceRefresh);
      final mapelNames = {
        for (final row in mapelRecords) row.id: row.namaMapel,
      };

      final guruRecords = await ref
          .read(userServiceProvider)
          .getByRole('guru', forceRefresh: forceRefresh);
      final guruNamesByUid = {
        for (final guru in guruRecords) guru.uid: guru.nama,
      };

      final fetchedEntries = await Future.wait(
        idsToLoad.map((jurnalId) async {
          final record = await jurnalService.getById(jurnalId);
          if (record == null) {
            return null;
          }

          return MapEntry(
            jurnalId,
            _JurnalMeta.fromRecord(
              record,
              kelasNames: kelasNames,
              tahunNames: tahunNames,
              mapelNames: mapelNames,
              guruNamesByUid: guruNamesByUid,
            ),
          );
        }),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        for (final entry in fetchedEntries) {
          if (entry != null) {
            _jurnalMetaById[entry.key] = entry.value;
          }
        }
        _isMetadataLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isMetadataLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(
      historiPresensiSiswaSupabaseProvider(widget.siswaUid),
    );
    final allItems = _buildViewItems(state.data);
    final filteredItems = _applyFilters(allItems);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Histori Presensi'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: state.isLoading
                ? null
                : () => _loadHistori(forceRefresh: true),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _isFilterVisible = !_isFilterVisible;
              });
            },
            icon: Icon(
              _isFilterVisible
                  ? Icons.filter_alt_off
                  : Icons.filter_alt_outlined,
            ),
            tooltip: _isFilterVisible ? 'Hide Filter' : 'Show Filter',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadHistori(forceRefresh: true),
        child: _buildBody(context, state, allItems, filteredItems),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    HistoriPresensiSiswaState state,
    List<_AttendanceViewItem> allItems,
    List<_AttendanceViewItem> filteredItems,
  ) {
    if (state.isLoading && state.data.isEmpty) {
      return _buildLoadingState(context);
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        if (state.error != null && state.error!.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildErrorBanner(context, state.error!),
        ],
        if (state.isLoading || _isMetadataLoading) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(minHeight: 3),
        ],
        const SizedBox(height: 16),
        _buildSummarySection(context, filteredItems),
        const SizedBox(height: 16),
        _buildFilterSection(context, allItems),
        const SizedBox(height: 16),
        _buildGroupedList(context, filteredItems),
      ],
    );
  }

  Widget _buildErrorBanner(BuildContext context, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withAlpha(18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.error.withAlpha(45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppColors.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
          TextButton(
            onPressed: () => _loadHistori(forceRefresh: true),
            child: const Text('Coba lagi'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection(
    BuildContext context,
    List<_AttendanceViewItem> items,
  ) {
    final hadir = items.where((item) => item.statusKey == 'hadir').length;
    final izin = items.where((item) => item.statusKey == 'izin').length;
    final sakit = items.where((item) => item.statusKey == 'sakit').length;
    final alpa = items.where((item) => item.statusKey == 'alpa').length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cardWidth = width >= 1100
            ? (width - 36) / 4
            : width >= 720
            ? (width - 12) / 2
            : width;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: cardWidth,
              child: _buildSummaryCard(
                context,
                title: 'Total Hadir',
                value: hadir,
                color: const Color(0xFF16A34A),
                icon: Icons.verified_outlined,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildSummaryCard(
                context,
                title: 'Izin',
                value: izin,
                color: const Color(0xFFF59E0B),
                icon: Icons.event_busy_outlined,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildSummaryCard(
                context,
                title: 'Sakit',
                value: sakit,
                color: const Color(0xFF0EA5E9),
                icon: Icons.sick_outlined,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildSummaryCard(
                context,
                title: 'Alpa',
                value: alpa,
                color: const Color(0xFFEF4444),
                icon: Icons.cancel_outlined,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard(
    BuildContext context, {
    required String title,
    required int value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(45)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withAlpha(22),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value.toString(),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection(
    BuildContext context,
    List<_AttendanceViewItem> allItems,
  ) {
    final tahunOptions = _buildTahunOptions(allItems);
    final semesterOptions = _buildSemesterOptions(allItems);
    final bulanOptions = _buildBulanOptions(allItems);
    final mapelOptions = _buildMapelOptions(allItems);
    final statusOptions = <String>[_allValue, 'Hadir', 'Izin', 'Sakit', 'Alpa'];

    final selectedTahun = _resolveSelection(_selectedTahunAjaran, tahunOptions);
    final selectedSemester = _resolveSelection(
      _selectedSemester,
      semesterOptions,
    );
    final selectedBulan = _resolveSelection(_selectedBulan, bulanOptions);
    final selectedStatus = _resolveSelection(_selectedStatus, statusOptions);
    final selectedMapel = _resolveSelection(_selectedMapel, mapelOptions);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Colors.transparent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final fieldWidth = width >= 1080
              ? (width - 24) / 3
              : width >= 720
              ? (width - 12) / 2
              : width;

          return AppExternalFilterBar(
            title: 'Filter Data',
            margin: EdgeInsets.zero,
            isExpanded: _isFilterVisible,
            onToggle: () {
              setState(() {
                _isFilterVisible = !_isFilterVisible;
              });
            },
            onReset: _resetFilters,
            onApply: () => setState(() {}),
            children: [
              SizedBox(
                width: fieldWidth,
                child: _buildDropdownField(
                  context,
                  label: 'Tahun Ajaran',
                  icon: Icons.school_outlined,
                  allLabel: 'Semua Tahun Ajaran',
                  value: selectedTahun,
                  items: tahunOptions,
                  onChanged: tahunOptions.length <= 1
                      ? null
                      : (value) {
                          setState(() {
                            _selectedTahunAjaran = value ?? _allValue;
                          });
                        },
                ),
              ),
              SizedBox(
                width: fieldWidth,
                child: _buildDropdownField(
                  context,
                  label: 'Semester',
                  icon: Icons.calendar_month_outlined,
                  allLabel: 'Semua Semester',
                  value: selectedSemester,
                  items: semesterOptions,
                  onChanged: semesterOptions.length <= 1
                      ? null
                      : (value) {
                          setState(() {
                            _selectedSemester = value ?? _allValue;
                          });
                        },
                ),
              ),
              SizedBox(
                width: fieldWidth,
                child: _buildDropdownField(
                  context,
                  label: 'Bulan',
                  icon: Icons.date_range_outlined,
                  allLabel: 'Semua Bulan',
                  value: selectedBulan,
                  items: bulanOptions,
                  onChanged: bulanOptions.length <= 1
                      ? null
                      : (value) {
                          setState(() {
                            _selectedBulan = value ?? _allValue;
                          });
                        },
                ),
              ),
              SizedBox(
                width: fieldWidth,
                child: _buildDropdownField(
                  context,
                  label: 'Status Kehadiran',
                  icon: Icons.fact_check_outlined,
                  allLabel: 'Semua Status',
                  value: selectedStatus,
                  items: statusOptions,
                  onChanged: (value) {
                    setState(() {
                      _selectedStatus = value ?? _allValue;
                    });
                  },
                ),
              ),
              SizedBox(
                width: fieldWidth,
                child: _buildDropdownField(
                  context,
                  label: 'Mata Pelajaran',
                  icon: Icons.menu_book_outlined,
                  allLabel: 'Semua Mata Pelajaran',
                  value: selectedMapel,
                  items: mapelOptions,
                  onChanged: mapelOptions.length <= 1
                      ? null
                      : (value) {
                          setState(() {
                            _selectedMapel = value ?? _allValue;
                          });
                        },
                ),
              ),
              SizedBox(
                width: fieldWidth,
                child: _buildDateRangeField(context, allItems),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDropdownField(
    BuildContext context, {
    required String label,
    required IconData icon,
    required String allLabel,
    required String value,
    required List<String> items,
    required ValueChanged<String?>? onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      items: items
          .map(
            (item) => DropdownMenuItem<String>(
              value: item,
              child: Text(item == _allValue ? allLabel : item),
            ),
          )
          .toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
    );
  }

  Widget _buildDateRangeField(
    BuildContext context,
    List<_AttendanceViewItem> allItems,
  ) {
    final label = _selectedDateRange == null
        ? 'Semua Tanggal'
        : '${_formatShortDate(_selectedDateRange!.start)} - ${_formatShortDate(_selectedDateRange!.end)}';

    return InkWell(
      onTap: allItems.isEmpty ? null : () => _pickDateRange(context, allItems),
      borderRadius: BorderRadius.circular(16),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Date Range',
          prefixIcon: const Icon(Icons.date_range_outlined),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: _selectedDateRange == null
                      ? AppColors.textSecondary
                      : AppColors.textPrimary,
                ),
              ),
            ),
            if (_selectedDateRange != null)
              IconButton(
                onPressed: () {
                  setState(() {
                    _selectedDateRange = null;
                  });
                },
                icon: const Icon(Icons.clear_rounded),
                tooltip: 'Hapus rentang tanggal',
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDateRange(
    BuildContext context,
    List<_AttendanceViewItem> allItems,
  ) async {
    final dates = allItems.map((item) => item.effectiveDate).toList();
    final earliest = dates.reduce((a, b) => a.isBefore(b) ? a : b);
    final latest = dates.reduce((a, b) => a.isAfter(b) ? a : b);

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(earliest.year - 1, 1, 1),
      lastDate: DateTime(latest.year + 1, 12, 31),
      initialDateRange: _selectedDateRange,
      helpText: 'Pilih rentang tanggal',
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _selectedDateRange = picked;
    });
  }

  Widget _buildGroupedList(
    BuildContext context,
    List<_AttendanceViewItem> items,
  ) {
    if (items.isEmpty) {
      return _buildEmptyState(context);
    }

    final monthKeys = <String>[];
    final grouped = <String, Map<String, List<_AttendanceViewItem>>>{};
    final dateOrderByMonth = <String, List<String>>{};

    for (final item in items) {
      final monthKey = _monthKey(item.effectiveDate);
      final dateKey = _dateKey(item.effectiveDate);

      if (!grouped.containsKey(monthKey)) {
        monthKeys.add(monthKey);
        grouped[monthKey] = <String, List<_AttendanceViewItem>>{};
        dateOrderByMonth[monthKey] = <String>[];
      }

      final monthGroup = grouped[monthKey]!;
      if (!monthGroup.containsKey(dateKey)) {
        monthGroup[dateKey] = <_AttendanceViewItem>[];
        dateOrderByMonth[monthKey]!.add(dateKey);
      }

      monthGroup[dateKey]!.add(item);
    }

    final children = <Widget>[];
    for (final monthKey in monthKeys) {
      final monthDate = DateTime.parse('$monthKey-01');
      final monthLabel = _formatMonthYear(monthDate);
      final dateKeys = dateOrderByMonth[monthKey] ?? const <String>[];
      final monthGroup =
          grouped[monthKey] ?? const <String, List<_AttendanceViewItem>>{};

      children.add(
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withAlpha(22),
                AppColors.primary.withAlpha(10),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.primary.withAlpha(45)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(22),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.calendar_month_outlined,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  monthLabel,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      for (final dateKey in dateKeys) {
        final dateDate = DateTime.parse(dateKey);
        final dateLabel = _formatLongDate(dateDate);
        final dateItems = monthGroup[dateKey] ?? const <_AttendanceViewItem>[];

        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 4),
            child: Text(
              dateLabel,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        );

        for (final item in dateItems) {
          children.add(_buildAttendanceCard(context, item));
        }

        children.add(const SizedBox(height: 8));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildAttendanceCard(BuildContext context, _AttendanceViewItem item) {
    final statusColor = _statusColor(item.statusLabel);
    final meta = item.meta;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: statusColor.withAlpha(45)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(9),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    _formatLongDateTime(item.effectiveDate),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _buildStatusBadge(statusColor, item.statusLabel),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildInfoTile(
                  icon: Icons.menu_book_outlined,
                  label: 'Mata Pelajaran',
                  value: meta?.mapelNama ?? '-',
                ),
                _buildInfoTile(
                  icon: Icons.person_outline,
                  label: 'Guru',
                  value: meta?.guruNama ?? '-',
                ),
                _buildInfoTile(
                  icon: Icons.schedule_outlined,
                  label: 'Jam ke',
                  value: meta?.jamLabel ?? '-',
                ),
                _buildInfoTile(
                  icon: Icons.class_outlined,
                  label: 'Kelas',
                  value: meta?.kelasNama ?? '-',
                ),
              ],
            ),
            if ((item.catatan ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.sticky_note_2_outlined,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item.catatan!.trim(),
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (meta != null) ...[
              const SizedBox(height: 12),
              Text(
                'Tahun Ajaran: ${meta.tahunAjaranLabel}  •  Semester: ${meta.semesterLabel}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (meta.materi != null && meta.materi!.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Materi: ${meta.materi!.trim()}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withAlpha(180)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(Color color, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.divider.withAlpha(140)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.fact_check_outlined,
                size: 54,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Belum ada histori presensi',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Data presensi akan tampil di sini setelah siswa memiliki catatan kehadiran.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _buildLoadingHero(),
        const SizedBox(height: 16),
        _buildSkeletonSummary(),
        const SizedBox(height: 16),
        _buildSkeletonFilter(),
        const SizedBox(height: 16),
        ...List<Widget>.generate(3, (index) => _buildSkeletonCard(index)),
      ],
    );
  }

  Widget _buildLoadingHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(18),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(22),
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          const SizedBox(height: 18),
          Container(width: 180, height: 18, decoration: _skeletonDecoration()),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            height: 12,
            decoration: _skeletonDecoration(),
          ),
          const SizedBox(height: 8),
          Container(width: 220, height: 12, decoration: _skeletonDecoration()),
        ],
      ),
    );
  }

  Widget _buildSkeletonSummary() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cardWidth = width >= 1100
            ? (width - 36) / 4
            : width >= 720
            ? (width - 12) / 2
            : width;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: List.generate(
            4,
            (index) => SizedBox(
              width: cardWidth,
              child: Container(
                height: 94,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: _skeletonDecoration(radius: 16),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 88,
                            height: 10,
                            decoration: _skeletonDecoration(),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: 42,
                            height: 20,
                            decoration: _skeletonDecoration(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSkeletonFilter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 150, height: 14, decoration: _skeletonDecoration()),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            height: 52,
            decoration: _skeletonDecoration(radius: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonCard(int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  width: 160,
                  height: 14,
                  decoration: _skeletonDecoration(),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 92,
                height: 26,
                decoration: _skeletonDecoration(radius: 999),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(
              4,
              (itemIndex) => Container(
                width: 150,
                height: 82,
                decoration: _skeletonDecoration(radius: 16),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            height: 54,
            decoration: _skeletonDecoration(radius: 16),
          ),
        ],
      ),
    );
  }

  BoxDecoration _skeletonDecoration({double radius = 12}) {
    return BoxDecoration(
      color: Colors.grey.shade200,
      borderRadius: BorderRadius.circular(radius),
    );
  }

  List<_AttendanceViewItem> _buildViewItems(List<HistoriPresensiItem> items) {
    final mapped = items
        .map(
          (item) => _AttendanceViewItem(
            item: item,
            meta: _jurnalMetaById[item.jurnalId],
          ),
        )
        .toList();

    mapped.sort((a, b) => b.effectiveDate.compareTo(a.effectiveDate));
    return mapped;
  }

  List<_AttendanceViewItem> _applyFilters(List<_AttendanceViewItem> items) {
    final tahunOptions = _buildTahunOptions(items);
    final semesterOptions = _buildSemesterOptions(items);
    final bulanOptions = _buildBulanOptions(items);
    final mapelOptions = _buildMapelOptions(items);
    final statusOptions = <String>[_allValue, 'Hadir', 'Izin', 'Sakit', 'Alpa'];

    final selectedTahun = _resolveSelection(_selectedTahunAjaran, tahunOptions);
    final selectedSemester = _resolveSelection(
      _selectedSemester,
      semesterOptions,
    );
    final selectedBulan = _resolveSelection(_selectedBulan, bulanOptions);
    final selectedStatus = _resolveSelection(_selectedStatus, statusOptions);
    final selectedMapel = _resolveSelection(_selectedMapel, mapelOptions);

    return items.where((item) {
      final matchesTahun =
          selectedTahun == _allValue || item.tahunAjaranLabel == selectedTahun;
      final matchesSemester =
          selectedSemester == _allValue ||
          item.semesterLabel == selectedSemester;
      final matchesBulan =
          selectedBulan == _allValue || item.monthLabel == selectedBulan;
      final matchesStatus =
          selectedStatus == _allValue || item.statusLabel == selectedStatus;
      final matchesMapel =
          selectedMapel == _allValue || item.mapelLabel == selectedMapel;
      final matchesDateRange =
          _selectedDateRange == null ||
          !item.effectiveDate.isBefore(
                _startOfDay(_selectedDateRange!.start),
              ) &&
              !item.effectiveDate.isAfter(_endOfDay(_selectedDateRange!.end));

      return matchesTahun &&
          matchesSemester &&
          matchesBulan &&
          matchesStatus &&
          matchesMapel &&
          matchesDateRange;
    }).toList();
  }

  List<String> _buildTahunOptions(List<_AttendanceViewItem> items) {
    final values = <String>{};
    for (final item in items) {
      if (item.tahunAjaranLabel != null &&
          item.tahunAjaranLabel!.trim().isNotEmpty) {
        values.add(item.tahunAjaranLabel!);
      }
    }
    final sorted = values.toList()..sort((a, b) => b.compareTo(a));
    return <String>[_allValue, ...sorted];
  }

  List<String> _buildSemesterOptions(List<_AttendanceViewItem> items) {
    final values = <String>{};
    for (final item in items) {
      if (item.semesterLabel.trim().isNotEmpty) {
        values.add(item.semesterLabel);
      }
    }
    final sorted = values.toList()..sort((a, b) => a.compareTo(b));
    return <String>[_allValue, ...sorted];
  }

  List<String> _buildBulanOptions(List<_AttendanceViewItem> items) {
    final values = <String>{};
    for (final item in items) {
      values.add(item.monthLabel);
    }
    final sorted = values.toList();
    return <String>[_allValue, ...sorted];
  }

  List<String> _buildMapelOptions(List<_AttendanceViewItem> items) {
    final values = <String>{};
    for (final item in items) {
      if (item.mapelLabel.trim().isNotEmpty) {
        values.add(item.mapelLabel);
      }
    }
    final sorted = values.toList()..sort((a, b) => a.compareTo(b));
    return <String>[_allValue, ...sorted];
  }

  void _resetFilters() {
    setState(() {
      _selectedTahunAjaran = _allValue;
      _selectedSemester = _allValue;
      _selectedBulan = _allValue;
      _selectedStatus = _allValue;
      _selectedMapel = _allValue;
      _selectedDateRange = null;
    });
  }

  String _resolveSelection(String current, List<String> options) {
    if (options.contains(current)) {
      return current;
    }
    return _allValue;
  }

  String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String _monthKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    return '${date.year}-$month';
  }

  DateTime _startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  DateTime _endOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day, 23, 59, 59, 999, 999);

  String _formatShortDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  String _formatLongDate(DateTime date) {
    final months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatMonthYear(DateTime date) {
    final months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  String _formatLongDateTime(DateTime date) {
    return '${_formatLongDate(date)} • ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Color _statusColor(String status) {
    final normalized = status.toLowerCase();

    if (normalized == 'hadir') {
      return const Color(0xFF16A34A);
    }
    if (normalized == 'izin') {
      return const Color(0xFFF59E0B);
    }
    if (normalized == 'sakit') {
      return const Color(0xFF0EA5E9);
    }
    if (normalized == 'alpha' || normalized == 'alpa') {
      return const Color(0xFFEF4444);
    }

    return Colors.grey;
  }
}

class _JurnalMeta {
  final String jurnalId;
  final String? tahunAjaranLabel;
  final String semesterLabel;
  final String kelasNama;
  final String mapelNama;
  final String guruNama;
  final int jamAwal;
  final int jamAkhir;
  final String? materi;
  final DateTime? tanggal;

  const _JurnalMeta({
    required this.jurnalId,
    required this.tahunAjaranLabel,
    required this.semesterLabel,
    required this.kelasNama,
    required this.mapelNama,
    required this.guruNama,
    required this.jamAwal,
    required this.jamAkhir,
    required this.materi,
    required this.tanggal,
  });

  String get jamLabel => 'Jam ke $jamAwal - $jamAkhir (${ModelUtils.getWaktuMulai(jamAwal) ?? '--:--'} - ${ModelUtils.getWaktuSelesai(jamAkhir) ?? '--:--'})';

  factory _JurnalMeta.fromRecord(
    JurnalRecord record, {
    required Map<String, String> kelasNames,
    required Map<String, String> tahunNames,
    required Map<String, String> mapelNames,
    required Map<String, String> guruNamesByUid,
  }) {
    return _JurnalMeta(
      jurnalId: record.id,
      tahunAjaranLabel:
          tahunNames[record.tahunAjaranId] ?? record.tahunAjaranId,
      semesterLabel: 'Semester ${record.semester}',
      kelasNama: kelasNames[record.kelasId] ?? record.kelasId,
      mapelNama: mapelNames[record.mataPelajaranId] ?? record.mataPelajaranId,
      guruNama: guruNamesByUid[record.userId] ?? record.userId,
      jamAwal: record.jamAwal,
      jamAkhir: record.jamAkhir,
      materi: record.materi,
      tanggal: record.tanggal,
    );
  }
}

class _AttendanceViewItem {
  final HistoriPresensiItem item;
  final _JurnalMeta? meta;

  const _AttendanceViewItem({required this.item, required this.meta});

  DateTime get effectiveDate =>
      meta?.tanggal ?? item.tanggal ?? DateTime.fromMillisecondsSinceEpoch(0);

  String get statusKey => item.statusKehadiran.trim().toLowerCase();

  String get statusLabel {
    final normalized = statusKey;
    if (normalized == 'hadir') {
      return 'Hadir';
    }
    if (normalized == 'izin') {
      return 'Izin';
    }
    if (normalized == 'sakit') {
      return 'Sakit';
    }
    if (normalized == 'alpha' || normalized == 'alpa') {
      return 'Alpa';
    }
    return item.statusKehadiran;
  }

  String? get tahunAjaranLabel => meta?.tahunAjaranLabel;

  String get semesterLabel => meta?.semesterLabel ?? '-';

  String get monthLabel {
    final months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    final date = effectiveDate;
    return '${months[date.month - 1]} ${date.year}';
  }

  String get mapelLabel => meta?.mapelNama ?? '-';

  String? get catatan => item.catatan;
}
