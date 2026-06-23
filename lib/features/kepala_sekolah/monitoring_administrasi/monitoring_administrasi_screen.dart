import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import 'screens/silabus_monitoring_screen.dart';
import 'screens/prota_monitoring_screen.dart';
import 'screens/promes_monitoring_screen.dart';
import 'screens/rpp_monitoring_screen.dart';

/// Screen utama untuk Monitoring Administrasi Pembelajaran oleh Kepala Sekolah
/// Menampilkan pilihan menu untuk monitoring berbagai dokumen administrasi
/// 
/// Monitoring dipisahkan per jenis dokumen untuk memudahkan tracking kelengkapan
/// 
/// Struktur Database terpisah per jenis dokumen:
/// - Silabus (silabus_id, user_id, kelas_id, mata_pelajaran_id, tahun_ajaran_id, semester, file_pdf, tanggal_upload)
/// - Program_Tahunan (prota_id, user_id, ...)
/// - Program_Semester (promes_id, user_id, ...)
/// - Rencana_Pembelajaran (rpp_id, user_id, ...)
/// 
/// Filter di setiap monitoring: Tahun Ajaran + Semester
/// 
/// TODO: Integrasi Firebase Storage untuk akses file
/// TODO: Query Firestore berdasarkan tahun_ajaran_id dan semester
class MonitoringAdministrasiScreen extends StatelessWidget {
  const MonitoringAdministrasiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitoring Administrasi'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.89,
          children: [
            // Menu Monitoring Silabus
            _buildMenuCard(
              context: context,
              icon: Icons.description,
              title: 'Silabus',
              subtitle: 'Monitor silabus guru',
              gradientColors: const [Color(0xFF2196F3), Color(0xFF1976D2)],
              onTap: () => _navigateToSilabusMonitoring(context),
            ),

            // Menu Monitoring Program Tahunan
            _buildMenuCard(
              context: context,
              icon: Icons.calendar_today,
              title: 'Program Tahunan',
              subtitle: 'Monitor Prota guru',
              gradientColors: const [Color(0xFF4CAF50), Color(0xFF388E3C)],
              onTap: () => _navigateToProtaMonitoring(context),
            ),

            // Menu Monitoring Program Semester
            _buildMenuCard(
              context: context,
              icon: Icons.event_note,
              title: 'Program Semester',
              subtitle: 'Monitor Promes guru',
              gradientColors: const [Color(0xFFFF9800), Color(0xFFF57C00)],
              onTap: () => _navigateToPromesMonitoring(context),
            ),

            // Menu Monitoring Rencana Pembelajaran
            _buildMenuCard(
              context: context,
              icon: Icons.assignment,
              title: 'Rencana Pembelajaran',
              subtitle: 'Monitor RPP guru',
              gradientColors: const [Color(0xFF9C27B0), Color(0xFF7B1FA2)],
              onTap: () => _navigateToRppMonitoring(context),
            ),
          ],
        ),
      ),
    );
  }

  /// Build menu card
  Widget _buildMenuCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradientColors,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 48,
                color: Colors.white,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Navigate to Silabus Monitoring
  void _navigateToSilabusMonitoring(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SilabusMonitoringScreen(),
      ),
    );
  }

  /// Navigate to Prota Monitoring
  void _navigateToProtaMonitoring(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ProtaMonitoringScreen(),
      ),
    );
  }

  /// Navigate to Promes Monitoring
  void _navigateToPromesMonitoring(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const PromesMonitoringScreen(),
      ),
    );
  }

  /// Navigate to RPP Monitoring
  void _navigateToRppMonitoring(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const RppMonitoringScreen(),
      ),
    );
  }
}
