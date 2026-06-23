import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/auth_session_service.dart';
import '../../../providers/supabase_providers.dart';
import '../../kepala_sekolah/widgets/app_alert.dart';
import 'role_selection_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
    });

    try {
      final loginService = ref.read(authServiceProvider);
      final principal = await loginService.login(
        usernameOrEmail: _usernameController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) {
        return;
      }

      if (principal.roles.length == 1) {
        final session = await loginService.createSession(
          user: principal.user,
          role: principal.roles.first,
        );
        final targetScreen = buildDashboardForRole(
          role: session.role.role,
          userId: session.user.id,
          profile: session.profile,
        );

        if (targetScreen == null) {
          _showError('Role pengguna tidak didukung.');
          return;
        }

        await AuthSessionService().saveSession(
          userId: session.user.id,
          role: session.role.role,
        );

        if (!mounted) {
          return;
        }

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => targetScreen),
        );
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => RoleSelectionScreen(
            user: principal.user,
            roles: principal.roles,
          ),
        ),
      );
    } catch (e) {
      String errMsg = 'Terjadi kesalahan saat login. Silakan coba lagi.';
      final errStr = e.toString();
      
      if (e is AuthException) {
        if (e.message.toLowerCase().contains('invalid login credentials')) {
          errMsg = 'Username/email atau password salah.';
        } else {
          errMsg = e.message;
        }
      } else if (errStr.contains('Akun tidak ditemukan') || errStr.contains('tidak terdaftar')) {
        errMsg = 'Username atau email tidak terdaftar.';
      } else if (errStr.contains('Exception: ')) {
        errMsg = errStr.replaceFirst('Exception: ', '');
      } else {
        errMsg = errStr;
      }
      
      _showError(errMsg);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }

    AppAlert.error(context, message: message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.school, size: 80, color: AppColors.primary),
                  const SizedBox(height: 16),
                  Text(
                    'Monitoring Kelas',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'SMP Negeri 1 Jenar',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 48),
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _usernameController,
                            decoration: const InputDecoration(
                              labelText: 'Username atau Email',
                              hintText: 'Masukkan username atau email',
                              prefixIcon: Icon(Icons.person),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Username tidak boleh kosong';
                              }
                              return null;
                            },
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: !_isPasswordVisible,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              hintText: 'Masukkan password',
                              prefixIcon: const Icon(Icons.lock),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isPasswordVisible
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isPasswordVisible = !_isPasswordVisible;
                                  });
                                },
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Password tidak boleh kosong';
                              }
                              return null;
                            },
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _handleLogin(),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleLogin,
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Login'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withAlpha(51),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.primary.withAlpha(128),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gunakan akun yang terdaftar pada data users Supabase.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Sistem mendukung akun multi-role secara otomatis.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}