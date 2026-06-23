import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../tabs/prota_monitoring_tab.dart';

/// Screen untuk Monitoring Program Tahunan oleh Kepala Sekolah
/// Menampilkan monitoring kelengkapan program tahunan dari semua guru
/// dengan filter Tahun Ajaran dan Semester
class ProtaMonitoringScreen extends StatelessWidget {
  const ProtaMonitoringScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitoring Program Tahunan'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: const ProtaMonitoringTab(),
    );
  }
}
