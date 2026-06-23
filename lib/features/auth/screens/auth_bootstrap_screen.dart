import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/auth_session_service.dart';
import '../../../core/services/app_metrics.dart';
import '../../../providers/supabase_providers.dart';
import 'login_screen.dart';
import 'role_selection_screen.dart';

class AuthBootstrapScreen extends ConsumerStatefulWidget {
  final Future<void> bootstrapFuture;

  const AuthBootstrapScreen({super.key, required this.bootstrapFuture});

  @override
  ConsumerState<AuthBootstrapScreen> createState() =>
      _AuthBootstrapScreenState();
}

class _AuthBootstrapScreenState extends ConsumerState<AuthBootstrapScreen> {
  late final Future<Widget> _initialScreenFuture;
  final PerfTimer _screenTimer = PerfTimer('auth_bootstrap_screen');

  @override
  void initState() {
    super.initState();
    _initialScreenFuture = _resolveInitialScreen();
  }

  Future<Widget> _resolveInitialScreen() async {
    final sessionService = AuthSessionService();
    final storedSessionFuture = sessionService.getValidSession();
    await widget.bootstrapFuture;
    final storedSession = await storedSessionFuture;

    if (storedSession == null) {
      AppMetrics().markStartupCompleted();
      AppMetrics().recordScreenLoad(
        'auth_bootstrap',
        _screenTimer.elapsed,
      );
      return const LoginScreen();
    }

    try {
      final loginService = ref.read(authServiceProvider);
      final restored = await loginService.restoreSession(
        selectedRole: storedSession.role,
      );
      final roleOptions = restored.principal.roles;

      final target = buildDashboardForRole(
        role: restored.session.role.role,
        userId: restored.session.user.id,
        profile: restored.session.profile,
        canSwitchRole: roleOptions.length > 1,
        onSwitchRoleRequested: roleOptions.length > 1
            ? (context) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => RoleSelectionScreen(
                      user: restored.principal.user,
                      roles: roleOptions,
                    ),
                  ),
                  (route) => false,
                );
              }
            : null,
      );

      if (target == null) {
        await sessionService.clearSession();
        AppMetrics().markStartupCompleted();
        AppMetrics().recordScreenLoad(
          'auth_bootstrap',
          _screenTimer.elapsed,
        );
        return const LoginScreen();
      }

      AppMetrics().markStartupCompleted();
      AppMetrics().recordScreenLoad('auth_bootstrap', _screenTimer.elapsed);
      return target;
    } catch (_) {
      await sessionService.clearSession();
      AppMetrics().markStartupCompleted();
      AppMetrics().recordScreenLoad('auth_bootstrap', _screenTimer.elapsed);
      return const LoginScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _initialScreenFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _AuthBootstrapLoadingScreen();
        }

        return snapshot.data ?? const LoginScreen();
      },
    );
  }
}

class _AuthBootstrapLoadingScreen extends StatelessWidget {
  const _AuthBootstrapLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(28),
                borderRadius: BorderRadius.circular(24),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.school_rounded,
                size: 44,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.8,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Menyiapkan aplikasi...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Memulihkan sesi login dan layanan inti',
              style: TextStyle(color: Colors.white.withAlpha(220)),
            ),
          ],
        ),
      ),
    );
  }
}
