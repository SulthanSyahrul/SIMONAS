import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/app_logout.dart';
import '../../../profile/providers/self_profile_provider.dart';
import '../../../profile/screens/self_profile_screen.dart';
import '../../manajemen_siswa/screens/manajemen_akun_siswa_screen.dart';
import '../../pengaturan_kelas/screens/pengaturan_kelas_screen.dart';
import '../../kenaikan_kelas/screens/kenaikan_kelas_screen.dart';
import '../../widgets/app_alert.dart';

/// Dashboard untuk BK (Bimbingan Konseling)
/// Sistem menggunakan Role-Based Access Control (RBAC)
/// BK/Kesiswaan mengelola: Manajemen Siswa, Pengaturan Kelas, dan Kenaikan Kelas.
class DashboardBkScreen extends StatelessWidget {
  final String bkUid;
  final bool canSwitchRole;
  final void Function(BuildContext context)? onSwitchRoleRequested;

  const DashboardBkScreen({
    super.key,
    required this.bkUid,
    this.canSwitchRole = false,
    this.onSwitchRoleRequested,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: canSwitchRole && onSwitchRoleRequested != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Kembali ke pilih role',
                onPressed: () => onSwitchRoleRequested!(context),
              )
            : null,
        title: const Text('Dashboard BK'),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.psychology, size: 48, color: Colors.white),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BK',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Pengelolaan Data Siswa & Kelas',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Menu Grid
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.92,
                children: [
                  _buildMenuCard(
                    context: context,
                    icon: Icons.people,
                    title: 'Manajemen\nAkun Siswa',
                    subtitle: 'Kelola Data Siswa',
                    gradientColors: const [
                      Color(0xFF667EEA),
                      Color(0xFF764BA2),
                    ],
                    onTap: () => _navigateToManajemenSiswa(context),
                  ),
                  _buildMenuCard(
                    context: context,
                    icon: Icons.class_,
                    title: 'Pengaturan\nKelas Siswa',
                    subtitle: 'Atur Kelas per Siswa',
                    gradientColors: const [
                      Color(0xFFF093FB),
                      Color(0xFFF5576C),
                    ],
                    onTap: () => _navigateToPengaturanKelas(context),
                  ),
                  _buildMenuCard(
                    context: context,
                    icon: Icons.upgrade,
                    title: 'Kenaikan\nKelas',
                    subtitle: 'Proses Kenaikan Kelas',
                    gradientColors: const [
                      Color(0xFF4FACFE),
                      Color(0xFF00F2FE),
                    ],
                    onTap: () => _navigateToKenaikanKelas(context),
                  ),
                  _buildMenuCard(
                    context: context,
                    icon: Icons.person,
                    title: 'Profil\nSaya',
                    subtitle: 'Lihat & Edit Profil',
                    gradientColors: const [
                      Color(0xFF43CEA2),
                      Color(0xFF185A9D),
                    ],
                    onTap: () => _navigateToProfile(context),
                  ),
                ],
              ),
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
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 40, color: Colors.white),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withAlpha(204),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Navigate to manajemen siswa
  void _navigateToManajemenSiswa(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const ManajemenAkunSiswaScreen()),
    );
  }

  /// Navigate to pengaturan kelas
  void _navigateToPengaturanKelas(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const PengaturanKelasScreen()),
    );
  }

  /// Navigate to kenaikan kelas
  void _navigateToKenaikanKelas(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const KenaikanKelasScreen()),
    );
  }

  void _navigateToProfile(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SelfProfileScreen(
          uid: bkUid,
          role: 'kesiswaan', // Keep database role 'kesiswaan'
          profileType: SelfProfileType.staff,
        ),
      ),
    );
  }

  /// Handle logout dengan konfirmasi
  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await AppAlert.confirm(
      context,
      title: 'Logout',
      message: 'Apakah Anda yakin ingin logout?',
      okText: 'Ya, logout',
      cancelText: 'Batal',
    );

    if (confirmed && context.mounted) {
      await logoutAndOpenLogin(context);
    }
  }
}
