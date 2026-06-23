import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/role_display_helper.dart';
import '../../../core/services/auth_session_service.dart';
import '../../../models/guru_model.dart';
import '../../../models/siswa_model.dart';
import '../../../models/user_model.dart';
import '../../../models/user_role_model.dart';
import '../../../providers/supabase_providers.dart';
import '../../bk/dashboard/screens/dashboard_bk_screen.dart';
import '../../guru/dashboard/screens/guru_dashboard_screen.dart';
import '../../kepala_sekolah/dashboard/screens/kepala_sekolah_dashboard_screen.dart';
import '../../siswa/dashboard/screens/siswa_dashboard_screen.dart';

String normalizeRole(String role) {
  return normalizeRoleValue(role);
}

bool isSupportedRole(String role) {
  return isSupportedRoleValue(role);
}

String roleLabel(String role) {
  return roleLabelValue(role);
}

IconData roleIcon(String role) {
  return roleIconValue(role);
}

Widget? buildDashboardForRole({
  required String role,
  required String userId,
  Object? profile,
  bool canSwitchRole = false,
  void Function(BuildContext context)? onSwitchRoleRequested,
}) {
  switch (normalizeRole(role)) {
    case 'kepala_sekolah':
      return KepalaSekolahDashboardScreen(
        canSwitchRole: canSwitchRole,
        onSwitchRoleRequested: onSwitchRoleRequested,
      );
    case 'guru':
      return GuruDashboardScreen(
        guruUid: userId,
        initialGuruProfile: profile is GuruRecord ? profile : null,
        canSwitchRole: canSwitchRole,
        onSwitchRoleRequested: onSwitchRoleRequested,
      );
    case 'bk':
    case 'kemahasiswaan':
    case 'kesiswaan':
      return DashboardBkScreen(
        bkUid: userId,
        canSwitchRole: canSwitchRole,
        onSwitchRoleRequested: onSwitchRoleRequested,
      );
    case 'siswa':
      return SiswaDashboardScreen(
        siswaUid: userId,
        initialSiswaProfile: profile is SiswaRecord ? profile : null,
        canSwitchRole: canSwitchRole,
        onSwitchRoleRequested: onSwitchRoleRequested,
      );
    default:
      return null;
  }
}

class RoleSelectionScreen extends ConsumerStatefulWidget {
  final UserRecord user;
  final List<UserRoleRecord> roles;

  const RoleSelectionScreen({
    super.key,
    required this.user,
    required this.roles,
  });

  @override
  ConsumerState<RoleSelectionScreen> createState() =>
      _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends ConsumerState<RoleSelectionScreen> {
  bool _isNavigating = false;

  List<UserRoleRecord> _buildRoleOptions() {
    final byRole = <String, UserRoleRecord>{};

    for (final item in widget.roles) {
      final normalized = normalizeRole(item.role);
      if (!isSupportedRole(normalized)) {
        continue;
      }
      byRole.putIfAbsent(normalized, () => item);
    }

    final options = byRole.values.toList();
    options.sort((a, b) {
      final aIdx = orderedSupportedRoles.indexOf(normalizeRole(a.role));
      final bIdx = orderedSupportedRoles.indexOf(normalizeRole(b.role));
      return aIdx.compareTo(bIdx);
    });

    return options;
  }

  Future<void> _onSelectRole(UserRoleRecord selectedRole) async {
    if (_isNavigating) {
      return;
    }

    setState(() {
      _isNavigating = true;
    });

    try {
      final loginService = ref.read(authServiceProvider);
      final roleOptions = _buildRoleOptions();
      final session = await loginService.createSession(
        user: widget.user,
        role: selectedRole,
      );

      final target = buildDashboardForRole(
        role: session.role.role,
        userId: session.user.id,
        profile: session.profile,
        canSwitchRole: roleOptions.length > 1,
        onSwitchRoleRequested: (context) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) =>
                  RoleSelectionScreen(user: widget.user, roles: roleOptions),
            ),
            (route) => false,
          );
        },
      );

      if (target == null) {
        throw Exception('Role tidak didukung oleh aplikasi.');
      }

      await AuthSessionService().saveSession(
        userId: session.user.id,
        role: session.role.role,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => target),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal masuk dengan role terpilih: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isNavigating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = _buildRoleOptions();

    return Scaffold(
      appBar: AppBar(title: const Text('Pilih Role'), centerTitle: true),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: options.isEmpty
              ? const Center(child: Text('Tidak ada role yang bisa dipilih.'))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Akun ini memiliki lebih dari satu role. Pilih role untuk melanjutkan:',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    if (_isNavigating)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: LinearProgressIndicator(minHeight: 3),
                      ),
                    Expanded(
                      child: ListView.separated(
                        itemCount: options.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final selectedRole = options[index];
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.primaryLight,
                                child: Icon(
                                  roleIcon(selectedRole.role),
                                  color: AppColors.primary,
                                ),
                              ),
                              title: Text(roleLabel(selectedRole.role)),
                              subtitle: Text('ID: ${selectedRole.userId}'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: _isNavigating
                                  ? null
                                  : () => _onSelectRole(selectedRole),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
