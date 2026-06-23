import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/app_logout.dart';
import '../../../../core/providers/academic_year_provider.dart';
import '../../../../models/guru_model.dart';
import '../../../../providers/supabase_providers.dart';
import '../../../guru/widgets/menu_card.dart';
import '../../jadwal/screens/jadwal_screen.dart';
import '../../jurnal/jurnal_guru_screen.dart';
import '../../nilai/screens/nilai_screen.dart';
import '../../tugas/screens/tugas_screen.dart';
import '../../profile/screens/profile_guru_screen.dart';
import '../../administrasi_pembelajaran/administrasi_pembelajaran_screen.dart';
import '../../raport/screens/raport_screen.dart';

/// Dashboard utama untuk Guru
/// Menampilkan menu navigasi ke fitur-fitur guru
class GuruDashboardScreen extends ConsumerStatefulWidget {
  final String guruUid;
  final GuruRecord? initialGuruProfile;
  final bool canSwitchRole;
  final void Function(BuildContext context)? onSwitchRoleRequested;

  const GuruDashboardScreen({
    super.key,
    required this.guruUid,
    this.initialGuruProfile,
    this.canSwitchRole = false,
    this.onSwitchRoleRequested,
  });

  @override
  ConsumerState<GuruDashboardScreen> createState() =>
      _GuruDashboardScreenState();
}

class _GuruDashboardScreenState extends ConsumerState<GuruDashboardScreen> {
  // Provider untuk tahun ajaran
  final AcademicYearProvider _academicYearProvider = AcademicYearProvider();

  GuruRecord? _guruProfile;
  bool _isLoadingWaliKelas = true;
  bool _hasWaliKelasHistory = false;

  String get _guruRefForQueries {
    final internalId = _guruProfile?.id.trim();
    if (internalId != null && internalId.isNotEmpty) {
      return internalId;
    }
    return widget.guruUid;
  }

  @override
  void initState() {
    super.initState();
    _guruProfile = widget.initialGuruProfile;
    Future.microtask(_loadWaliKelasAccess);
  }

  @override
  void dispose() {
    _academicYearProvider.dispose();
    super.dispose();
  }

  /// Cek apakah guru memiliki histori wali kelas lintas tahun ajaran.
  Future<bool> _checkWaliKelas({bool forceRefresh = false}) async {
    if (!mounted) {
      return false;
    }

    final cached = _GuruDashboardWaliKelasCache.get(widget.guruUid);
    if (!forceRefresh && cached != null) {
      return cached;
    }

    try {
      final historiRows = await ref
          .read(historiWaliKelasServiceProvider)
          .getScopeByGuru(widget.guruUid, onlyAktif: true);

      final hasWaliHistory = historiRows.any(
        (row) => !row.isDeleted && row.isAktif,
      );
      _GuruDashboardWaliKelasCache.set(widget.guruUid, hasWaliHistory);
      return hasWaliHistory;
    } catch (_) {
      return false;
    }
  }

  Future<void> _loadWaliKelasAccess({bool forceRefresh = false}) async {
    final hasHistory = await _checkWaliKelas(forceRefresh: forceRefresh);
    if (!mounted) {
      return;
    }

    setState(() {
      _hasWaliKelasHistory = hasHistory;
      _isLoadingWaliKelas = false;
    });
  }

  Future<void> _loadGuruProfile({bool forceRefresh = false}) async {
    if (!mounted) {
      return;
    }

    if (!forceRefresh && _guruProfile != null) {
      return;
    }

    try {
      final guruProfile = await ref.read(guruServiceProvider).getFirstByUid(
        widget.guruUid,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _guruProfile = guruProfile;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final guruName = _guruProfile?.nama;

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
            title: const Text('Dashboard Guru'),
            centerTitle: true,
            actions: [
              // Tombol logout
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
                onPressed: () async {
                  await _loadGuruProfile(forceRefresh: true);
                  await _loadWaliKelasAccess(forceRefresh: true);
                },
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'Logout',
                onPressed: () => _handleLogout(context),
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header dengan info guru
                _buildHeader(guruName),

                // Grid menu
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      children: [
                        // Menu Jadwal Mengajar
                        MenuCard(
                          title: 'Jadwal Mengajar',
                          icon: Icons.schedule,
                          gradientColors: AppColors.menuGradient1,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => GuruJadwalScreen(
                                  academicYearProvider: _academicYearProvider,
                                  guruUid: _guruRefForQueries,
                                ),
                              ),
                            );
                          },
                        ),

                        // Menu Jurnal Guru (sudah termasuk absensi)
                        MenuCard(
                          title: 'Jurnal & Absensi',
                          icon: Icons.book,
                          gradientColors: AppColors.menuGradient2,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => JurnalGuruScreen(
                                  academicYearProvider: _academicYearProvider,
                                  guruUid: _guruRefForQueries,
                                ),
                              ),
                            );
                          },
                        ),

                        // Menu Nilai
                        MenuCard(
                          title: 'Nilai',
                          icon: Icons.grade,
                          gradientColors: AppColors.menuGradient3,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => GuruNilaiScreen(
                                  academicYearProvider: _academicYearProvider,
                                  guruUid: _guruRefForQueries,
                                ),
                              ),
                            );
                          },
                        ),

                        // Menu Tugas
                        MenuCard(
                          title: 'Tugas',
                          icon: Icons.assignment,
                          gradientColors: AppColors.menuGradient4,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => GuruTugasScreen(
                                  academicYearProvider: _academicYearProvider,
                                  guruUid: _guruRefForQueries,
                                ),
                              ),
                            );
                          },
                        ),

                        // Menu Administrasi Pembelajaran
                        MenuCard(
                          title: 'Administrasi Pembelajaran',
                          icon: Icons.folder_special,
                          gradientColors: AppColors.menuGradient2,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    AdministrasiPembelajaranScreen(
                                      academicYearProvider:
                                          _academicYearProvider,
                                      guruUid: _guruRefForQueries,
                                    ),
                              ),
                            );
                          },
                        ),

                        if (!_isLoadingWaliKelas && _hasWaliKelasHistory)
                          MenuCard(
                            title: 'Raport',
                            icon: Icons.card_membership,
                            gradientColors: AppColors.menuGradient3,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => RaportScreen(
                                    academicYearProvider:
                                        _academicYearProvider,
                                    guruUid: _guruRefForQueries,
                                  ),
                                ),
                              );
                            },
                          ),

                        // Menu Profil
                        MenuCard(
                          title: 'Profil',
                          icon: Icons.person,
                          gradientColors: AppColors.menuGradient1,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => ProfileGuruScreen(
                                  academicYearProvider: _academicYearProvider,
                                  guruUid: _guruRefForQueries,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Widget header dengan info guru dan tahun ajaran
  Widget _buildHeader(String? guruName) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primary,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nama guru
          const Text(
            'Selamat Datang,',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            (guruName == null || guruName.trim().isEmpty)
                ? 'Bapak/Ibu Guru'
                : guruName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          // Info tambahan
          Row(
            children: [
              const Icon(Icons.school, color: Colors.white70, size: 16),
              const SizedBox(width: 4),
              Text(
                'SMP Negeri 1 Jenar',
                style: TextStyle(
                  color: Colors.white.withAlpha(230),
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.calendar_today, color: Colors.white70, size: 16),
              const SizedBox(width: 4),
              Text(
                'TA ${_academicYearProvider.selectedYear}',
                style: TextStyle(
                  color: Colors.white.withAlpha(230),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Handle logout dengan konfirmasi
  void _handleLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Apakah Anda yakin ingin logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              await logoutAndOpenLogin(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

class _GuruDashboardWaliKelasCache {
  static const Duration _ttl = Duration(minutes: 15);
  static final Map<String, bool> _values = <String, bool>{};
  static final Map<String, DateTime> _fetchedAt = <String, DateTime>{};

  static bool? get(String guruUid) {
    final key = guruUid.trim();
    final value = _values[key];
    final fetchedAt = _fetchedAt[key];
    if (value == null || fetchedAt == null) {
      return null;
    }
    if (DateTime.now().difference(fetchedAt) >= _ttl) {
      _values.remove(key);
      _fetchedAt.remove(key);
      return null;
    }
    return value;
  }

  static void set(String guruUid, bool value) {
    final key = guruUid.trim();
    if (key.isEmpty) {
      return;
    }
    _values[key] = value;
    _fetchedAt[key] = DateTime.now();
  }
}
