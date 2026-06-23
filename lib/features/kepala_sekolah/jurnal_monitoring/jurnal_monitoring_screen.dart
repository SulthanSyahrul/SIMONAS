import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import 'tabs/history_tab.dart';

/// Screen utama untuk Monitoring Jurnal oleh Kepala Sekolah
/// Monitoring jurnal menggunakan relasi jurnal_id
/// Tujuan:
/// - Memantau aktivitas pembelajaran guru
/// - Melihat kehadiran guru
/// - Melihat materi yang diajarkan
/// - Melihat absensi siswa
/// - Melihat histori jurnal pembelajaran
/// 
/// TODO: Query Firestore berdasarkan tanggal
/// TODO: Query berdasarkan kelas dan guru
class JurnalMonitoringScreen extends StatelessWidget {
  const JurnalMonitoringScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitoring Jurnal'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: const HistoryTab(),
    );
  }
}
