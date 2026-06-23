import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/academic_year_provider.dart';
import '../../../../core/widgets/app_external_filter_bar.dart';
import '../../../../models/monitoring_kelas_model.dart';
import '../../../../models/model_utils.dart';
import '../../../../providers/supabase_providers.dart';
import '../../widgets/app_alert.dart';
import '../../providers/monitoring_kelas_provider.dart';

/// Screen untuk monitoring kelas (realtime + history)
/// Status kelas dihitung dari data jurnal harian yang masuk.
class MonitoringKelasScreen extends ConsumerStatefulWidget {
  final AcademicYearProvider academicYearProvider;

  const MonitoringKelasScreen({super.key, required this.academicYearProvider});

  @override
  ConsumerState<MonitoringKelasScreen> createState() =>
      _MonitoringKelasScreenState();
}

class _MonitoringKelasScreenState extends ConsumerState<MonitoringKelasScreen> {
  bool _isFilterVisible = true;

  Future<void> _selectDate(DateTime currentDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime.now().subtract(const Duration(days: 60)),
      lastDate: DateTime.now(),
      locale: const Locale('id', 'ID'),
    );

    if (picked != null && mounted) {
      await ref.read(monitoringKelasProvider.notifier).setDate(picked);
    }
  }

  bool _isRealtimeMonitoring(DateTime selectedDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return selectedDate.isAtSameMomentAs(today);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(monitoringKelasProvider);
    final isRealtime = _isRealtimeMonitoring(state.selectedDate);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Monitoring Kelas'),
        actions: [
          IconButton(
            onPressed: state.isLoading
                ? null
                : () => ref.read(monitoringKelasProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isRealtime
                      ? Colors.green.withAlpha(26)
                      : Colors.blue.withAlpha(26),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isRealtime ? Colors.green : Colors.blue,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isRealtime ? Icons.circle : Icons.history,
                      size: 12,
                      color: isRealtime ? Colors.green : Colors.blue,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isRealtime ? 'Realtime' : 'History',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isRealtime ? Colors.green : Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(monitoringKelasProvider.notifier).refresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _buildFilterSection(state),
            _buildInfoSection(),
            if (state.error != null && state.error!.isNotEmpty)
              Container(
                width: double.infinity,
                color: AppColors.error.withAlpha(20),
                padding: const EdgeInsets.all(12),
                child: Text(
                  state.error!,
                  style: const TextStyle(fontSize: 12, color: AppColors.error),
                ),
              ),
            if (state.isLoading && state.monitoringList.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 120),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              _buildMonitoringGrid(state.monitoringList),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection(MonitoringKelasState state) {
    return AppExternalFilterBar(
      isExpanded: _isFilterVisible,
      onToggle: () {
        setState(() {
          _isFilterVisible = !_isFilterVisible;
        });
      },
      onReset: () async {
        final now = DateTime.now();
        await ref
            .read(monitoringKelasProvider.notifier)
            .setDate(DateTime(now.year, now.month, now.day));
        await ref.read(monitoringKelasProvider.notifier).setJamKe(1);
      },
      onApply: () => ref.read(monitoringKelasProvider.notifier).refresh(),
      isBusy: state.isLoading,
      children: [
        AppExternalFilterField(
          label: 'Tanggal',
          child: InkWell(
            onTap: () => _selectDate(state.selectedDate),
            child: InputDecorator(
              decoration: appExternalFilterDecoration(
                hintText: 'Pilih tanggal',
                icon: Icons.calendar_today_rounded,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _formatDate(state.selectedDate),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
        ),
        AppExternalFilterField(
          label: 'Jam Pelajaran',
          child: DropdownButtonFormField<int>(
            initialValue: state.selectedJamKe,
            decoration: appExternalFilterDecoration(
              hintText: 'Pilih jam',
              icon: Icons.schedule_rounded,
            ),
            items: state.jamOptions
                .map(
                  (jam) => DropdownMenuItem(
                    value: jam,
                    child: Text(
                      'Jam ke-$jam (${ModelUtils.getWaktuMulai(jam) ?? '--:--'} - ${ModelUtils.getWaktuSelesai(jam) ?? '--:--'})',
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                ref.read(monitoringKelasProvider.notifier).setJamKe(value);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.info.withAlpha(26),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.info.withAlpha(77)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildLegendItem(StatusMonitoring.masuk),
          _buildLegendItem(StatusMonitoring.izin),
          _buildLegendItem(StatusMonitoring.belumIsi),
        ],
      ),
    );
  }

  Widget _buildLegendItem(StatusMonitoring status) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: Color(status.colorValue),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(status.label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildMonitoringGrid(List<MonitoringKelasModel> monitoringList) {
    if (monitoringList.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 96),
        child: Center(
          child: Text(
            'Tidak ada data monitoring kelas untuk filter ini.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: monitoringList
            .map((monitoring) => _buildKelasCard(monitoring))
            .toList(),
      ),
    );
  }

  Widget _buildKelasCard(MonitoringKelasModel monitoring) {
    return InkWell(
      onTap: () => _showKelasDetail(monitoring),
      child: Container(
        width: 102,
        height: 102,
        decoration: BoxDecoration(
          color: Color(monitoring.status.colorValue),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(26),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              monitoring.kelasNama,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(51),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                monitoring.status.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showKelasDetail(MonitoringKelasModel monitoring) async {
    final buffer = StringBuffer();
    String? guruName = monitoring.namaGuru;
    String? mataPelajaranName = monitoring.mataPelajaran;

    if ((guruName == null || guruName.isEmpty) &&
        monitoring.guruUid != null &&
        monitoring.guruUid!.isNotEmpty) {
      final guruService = ref.read(guruServiceProvider);
      final guruRecord = await guruService.getById(monitoring.guruUid!) ??
          (await guruService.getByUid(monitoring.guruUid!)).cast<dynamic>().firstOrNull;

      if (guruRecord != null) {
        guruName = guruRecord.nama;
      } else {
        guruName = monitoring.guruUid;
      }
    }

    if ((mataPelajaranName == null || mataPelajaranName.isEmpty) &&
        monitoring.mataPelajaranId != null &&
        monitoring.mataPelajaranId!.isNotEmpty) {
      final mapelRecord = await ref
          .read(mapelServiceProvider)
          .getById(monitoring.mataPelajaranId!);
      mataPelajaranName = mapelRecord?.namaMapel ?? monitoring.mataPelajaranId;
    }

    if (!mounted) {
      return;
    }

    buffer.writeln('Status: ${monitoring.status.label}');
    buffer.writeln(
      'Tanggal: ${monitoring.tanggal.day}/${monitoring.tanggal.month}/${monitoring.tanggal.year}',
    );
    if (monitoring.jamKe > 0) {
      buffer.writeln('Jam ke: ${monitoring.jamKe}');
    }
    if (guruName != null && guruName.isNotEmpty) {
      buffer.writeln('Guru: $guruName');
    }
    if (mataPelajaranName != null && mataPelajaranName.isNotEmpty) {
      buffer.writeln('Mata Pelajaran: $mataPelajaranName');
    }

    AppAlert.info(
      context,
      title: 'Detail ${monitoring.kelasNama}',
      message: buffer.toString().trim(),
    );
  }

  String _formatDate(DateTime date) {
    const days = [
      'Minggu',
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
    ];
    const months = [
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

    return '${days[date.weekday % 7]}, ${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
