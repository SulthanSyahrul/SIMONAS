import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../tabs/silabus_monitoring_tab.dart';

/// Screen untuk Monitoring Silabus oleh Kepala Sekolah
/// Menampilkan monitoring kelengkapan silabus dari semua guru
/// dengan filter Tahun Ajaran dan Semester
class SilabusMonitoringScreen extends StatelessWidget {
  const SilabusMonitoringScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitoring Silabus'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: const SilabusMonitoringTab(),
    );
  }
}
