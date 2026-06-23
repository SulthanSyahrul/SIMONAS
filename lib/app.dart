import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/constants/app_theme.dart';
import 'features/auth/screens/auth_bootstrap_screen.dart';

/// Root widget aplikasi
/// Mengatur theme dan initial route
class MyApp extends StatelessWidget {
  final Future<void> bootstrapFuture;

  const MyApp({super.key, required this.bootstrapFuture});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Info aplikasi
      title: 'SIMONAS',

      // Nonaktifkan banner debug
      debugShowCheckedModeBanner: false,

      // Tema aplikasi
      theme: AppTheme.lightTheme,

      // Localization untuk DatePicker dan widget Material lainnya
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('id', 'ID'), // Indonesian
        Locale('en', 'US'), // English
      ],
      locale: const Locale('id', 'ID'),

      // Halaman awal
      home: AuthBootstrapScreen(bootstrapFuture: bootstrapFuture),
    );
  }
}
