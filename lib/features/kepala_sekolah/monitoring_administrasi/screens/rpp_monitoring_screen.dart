import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../tabs/rpp_monitoring_tab.dart';

/// Screen untuk Monitoring Rencana Pelaksanaan Pembelajaran (RPP) oleh Kepala Sekolah
/// Menampilkan monitoring kelengkapan RPP dari semua guru
/// dengan filter Tahun Ajaran dan Semester
class RppMonitoringScreen extends StatelessWidget {
  const RppMonitoringScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitoring Rencana Pembelajaran'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: const RppMonitoringTab(),
    );
  }
}
