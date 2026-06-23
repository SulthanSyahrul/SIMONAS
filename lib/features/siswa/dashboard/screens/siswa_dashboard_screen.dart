import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/app_logout.dart';
import '../../../../models/siswa_model.dart';
import '../../../../providers/supabase_providers.dart';
import '../../../profile/providers/self_profile_provider.dart';
import '../../../profile/screens/self_profile_screen.dart';
import '../../histori_presensi_siswa_screen.dart';
import '../../jadwal_siswa_screen.dart';
import '../../nilai_siswa_screen.dart';
import '../../tugas_siswa_screen.dart';

class SiswaDashboardScreen extends ConsumerStatefulWidget {
  final String siswaUid;
  final SiswaRecord? initialSiswaProfile;
  final bool canSwitchRole;
  final void Function(BuildContext context)? onSwitchRoleRequested;

  const SiswaDashboardScreen({
    super.key,
    required this.siswaUid,
    this.initialSiswaProfile,
    this.canSwitchRole = false,
    this.onSwitchRoleRequested,
  });

  @override
  ConsumerState<SiswaDashboardScreen> createState() =>
      _SiswaDashboardScreenState();
}

class _SiswaDashboardScreenState extends ConsumerState<SiswaDashboardScreen> {
  String _namaSiswa = 'Siswa';
  bool _isLoadingProfile = true;

  @override
  void initState() {
    super.initState();
    final initialName = widget.initialSiswaProfile?.nama?.trim() ?? '';
    if (initialName.isNotEmpty) {
      _namaSiswa = initialName;
      _isLoadingProfile = false;
      return;
    }
    Future.microtask(_loadProfile);
  }

  Future<void> _loadProfile() async {
    try {
      final displayName = await ref
          .read(siswaServiceProvider)
          .getDisplayNameByUid(widget.siswaUid);
      if (!mounted) {
        return;
      }

      setState(() {
        _namaSiswa = (displayName ?? '').trim().isNotEmpty
            ? displayName!.trim()
            : widget.siswaUid;
        _isLoadingProfile = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _namaSiswa = widget.siswaUid;
        _isLoadingProfile = false;
      });
    }
  }

  void _navigateToJadwal() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JadwalSiswaScreen(siswaUid: widget.siswaUid),
      ),
    );
  }

  void _navigateToNilai() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NilaiSiswaScreen(siswaUid: widget.siswaUid),
      ),
    );
  }

  void _navigateToTugas() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TugasSiswaScreen(siswaUid: widget.siswaUid),
      ),
    );
  }

  void _navigateToHistoriPresensi() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            HistoriPresensiSiswaScreen(siswaUid: widget.siswaUid),
      ),
    );
  }

  void _navigateToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SelfProfileScreen(
          uid: widget.siswaUid,
          role: 'siswa',
          profileType: SelfProfileType.siswa,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: widget.canSwitchRole && widget.onSwitchRoleRequested != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Kembali ke pilih role',
                onPressed: () => widget.onSwitchRoleRequested!(context),
              )
            : null,
        title: const Text('Dashboard Siswa'),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Profile',
            onPressed: _isLoadingProfile ? null : _loadProfile,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await logoutAndOpenLogin(context);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, Color(0xFF1E88E5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withAlpha(51),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.person,
                      size: 48,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _isLoadingProfile ? 'Memuat...' : _namaSiswa,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(51),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'UID: ${widget.siswaUid}',
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.1,
                children: [
                  _buildMenuCard(
                    icon: Icons.schedule,
                    title: 'Jadwal\nPelajaran',
                    color: const Color(0xFF3B82F6),
                    onTap: _navigateToJadwal,
                  ),
                  _buildMenuCard(
                    icon: Icons.assessment,
                    title: 'Nilai\nSiswa',
                    color: const Color(0xFF10B981),
                    onTap: _navigateToNilai,
                  ),
                  _buildMenuCard(
                    icon: Icons.assignment,
                    title: 'Tugas\nSiswa',
                    color: const Color(0xFFF59E0B),
                    onTap: _navigateToTugas,
                  ),
                  _buildMenuCard(
                    icon: Icons.history_edu,
                    title: 'Histori\nPresensi',
                    color: const Color(0xFF0EA5E9),
                    onTap: _navigateToHistoriPresensi,
                  ),
                  _buildMenuCard(
                    icon: Icons.person,
                    title: 'Profil\nSaya',
                    color: const Color(0xFF8B5CF6),
                    onTap: _navigateToProfile,
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.info.withAlpha(26),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.info.withAlpha(51)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.info, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Semua data ditarik khusus untuk akun siswa yang sedang login.',
                      style: TextStyle(fontSize: 13, color: AppColors.info),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withValues(alpha: 0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: Colors.white),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
