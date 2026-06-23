import 'package:flutter/material.dart';

import '../../features/auth/screens/login_screen.dart';
import '../services/auth_session_service.dart';

Future<void> logoutAndOpenLogin(BuildContext context) async {
  final navigator = Navigator.of(context);

  await AuthSessionService().clearSession();

  if (!navigator.mounted) {
    return;
  }

  navigator.pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const LoginScreen()),
    (route) => false,
  );
}
