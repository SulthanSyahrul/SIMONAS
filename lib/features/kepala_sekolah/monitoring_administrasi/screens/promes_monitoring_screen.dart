import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../tabs/promes_monitoring_tab.dart';

/// Screen untuk Monitoring Program Semester oleh Kepala Sekolah
/// Menampilkan monitoring kelengkapan program semester dari semua guru
/// dengan filter Tahun Ajaran dan Semester
class PromesMonitoringScreen extends StatelessWidget {
  const PromesMonitoringScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitoring Program Semester'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: const PromesMonitoringTab(),
    );
  }
}
