import 'package:flutter/material.dart';
import '../../../../core/providers/academic_year_provider.dart';
import '../../../../core/utils/app_logout.dart';
import '../../widgets/app_alert.dart';
import '../../monitoring/screens/monitoring_kelas_screen.dart';
import '../../monitoring_administrasi/monitoring_administrasi_screen.dart';
import '../../jurnal_monitoring/jurnal_monitoring_screen.dart';
import '../../manajemen_akademik/manajemen_akademik_screen.dart';
import '../../manajemen_akun/manajemen_akun_guru_screen.dart';
import '../../mapel/screens/mapel_management_screen.dart';
import '../../tahun_ajaran/screens/tahun_ajaran_management_screen.dart';

/// Dashboard untuk Kepala Sekolah
/// Menampilkan menu utama untuk monitoring dan manajemen sekolah
class KepalaSekolahDashboardScreen extends StatefulWidget {
  final bool canSwitchRole;
  final void Function(BuildContext context)? onSwitchRoleRequested;

  const KepalaSekolahDashboardScreen({
    super.key,
    this.canSwitchRole = false,
    this.onSwitchRoleRequested,
  });

  @override
  State<KepalaSekolahDashboardScreen> createState() =>
      _KepalaSekolahDashboardScreenState();
}

class _KepalaSekolahDashboardScreenState
    extends State<KepalaSekolahDashboardScreen> {
  final AcademicYearProvider _academicYearProvider = AcademicYearProvider();

  @override
  void dispose() {
    _academicYearProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _academicYearProvider,
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(
            leading:
                widget.canSwitchRole && widget.onSwitchRoleRequested != null
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Kembali ke pilih role',
                    onPressed: () => widget.onSwitchRoleRequested!(context),
                  )
                : null,
            title: const Text('Dashboard Kepala Sekolah'),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'Logout',
                onPressed: () => _handleLogout(context),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.86,
              children: [
                _buildMenuCard(
                  context: context,
                  icon: Icons.monitor,
                  title: 'Monitoring Kelas',
                  subtitle: 'Status Kelas',
                  gradientColors: const [Color(0xFF667EEA), Color(0xFF764BA2)],
                  onTap: () => _navigateToMonitoring(context),
                ),
                _buildMenuCard(
                  context: context,
                  icon: Icons.folder_special,
                  title: 'Monitoring Administrasi',
                  subtitle: 'Dokumen Guru',
                  gradientColors: const [Color(0xFFF093FB), Color(0xFFF5576C)],
                  onTap: () => _navigateToMonitoringAdministrasi(context),
                ),
                _buildMenuCard(
                  context: context,
                  icon: Icons.menu_book,
                  title: 'Monitoring Jurnal',
                  subtitle: 'Jurnal Mengajar',
                  gradientColors: const [Color(0xFFFFD89B), Color(0xFFFF8E53)],
                  onTap: () => _navigateToJurnalMonitoring(context),
                ),
                _buildMenuCard(
                  context: context,
                  icon: Icons.school,
                  title: 'Manajemen Akademik',
                  subtitle: 'Jadwal & Wali Kelas',
                  gradientColors: const [Color(0xFF4FACFE), Color(0xFF00F2FE)],
                  onTap: () => _navigateToManajemen(context),
                ),
                _buildMenuCard(
                  context: context,
                  icon: Icons.calendar_month,
                  title: 'Manajemen Tahun Ajaran',
                  subtitle: 'Aktif, Riwayat, dan Data',
                  gradientColors: const [Color(0xFF00B894), Color(0xFF00CEC9)],
                  onTap: () => _navigateToTahunAjaranManagement(context),
                ),
                _buildMenuCard(
                  context: context,
                  icon: Icons.people,
                  title: 'Manajemen Akun Guru',
                  subtitle: 'Kelola Akun Guru',
                  gradientColors: const [Color(0xFFFA709A), Color(0xFFFEE140)],
                  onTap: () => _navigateToManajemenAkun(context),
                ),
                _buildMenuCard(
                  context: context,
                  icon: Icons.auto_stories,
                  title: 'Manajemen Mapel',
                  subtitle: 'Kelola Mata Pelajaran',
                  gradientColors: const [Color(0xFF43E97B), Color(0xFF38F9D7)],
                  onTap: () => _navigateToManajemenMapel(context),
                ),
              ],
            ),
          ),
        );
      },
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
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 48, color: Colors.white),
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
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withAlpha(204),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Navigate to monitoring kelas
  void _navigateToMonitoring(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            MonitoringKelasScreen(academicYearProvider: _academicYearProvider),
      ),
    );
  }

  /// Navigate to monitoring administrasi
  void _navigateToMonitoringAdministrasi(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const MonitoringAdministrasiScreen(),
      ),
    );
  }

  /// Navigate to monitoring jurnal pembelajaran
  void _navigateToJurnalMonitoring(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const JurnalMonitoringScreen()),
    );
  }

  /// Navigate to manajemen akademik
  void _navigateToManajemen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ManajemenAkademikScreen(
          academicYearProvider: _academicYearProvider,
        ),
      ),
    );
  }

  /// Navigate to manajemen tahun ajaran
  void _navigateToTahunAjaranManagement(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const TahunAjaranManagementScreen(),
      ),
    );
  }

  /// Navigate to manajemen akun guru
  void _navigateToManajemenAkun(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const ManajemenAkunGuruScreen()),
    );
  }

  /// Navigate to manajemen mata pelajaran
  void _navigateToManajemenMapel(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const MapelManagementScreen()),
    );
  }

  /// Handle logout dengan konfirmasi
  void _handleLogout(BuildContext context) {
    AppAlert.confirm(
      context,
      title: 'Logout',
      message: 'Apakah Anda yakin ingin logout?',
    ).then((confirmed) async {
      if (!confirmed || !context.mounted) {
        return;
      }
      await logoutAndOpenLogin(context);
    });
  }
}
