import 'package:flutter/material.dart';

/// Kelas untuk mendefinisikan warna-warna yang digunakan di seluruh aplikasi
/// Menggunakan skema warna yang modern dan konsisten
class AppColors {
  // Primary colors - Biru profesional untuk tema pendidikan
  static const Color primary = Color(0xFF2196F3);
  static const Color primaryDark = Color(0xFF1976D2);
  static const Color primaryLight = Color(0xFFBBDEFB);

  // Accent colors
  static const Color accent = Color(0xFF4CAF50);
  static const Color accentDark = Color(0xFF388E3C);

  // Background colors
  static const Color background = Color(0xFFF5F5F5);
  static const Color cardBackground = Colors.white;

  // Text colors
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textLight = Colors.white;

  // Status colors untuk absensi
  static const Color success = Color(0xFF4CAF50); // Hadir
  static const Color warning = Color(0xFFFFC107); // Izin
  static const Color error = Color(0xFFF44336); // Alpa
  static const Color info = Color(0xFF2196F3); // Sakit

  // Divider & borders
  static const Color divider = Color(0xFFE0E0E0);
  static const Color border = Color(0xFFBDBDBD);

  // Menu card colors - gradien untuk dashboard
  static const List<Color> menuGradient1 = [Color(0xFF2196F3), Color(0xFF1976D2)];
  static const List<Color> menuGradient2 = [Color(0xFF4CAF50), Color(0xFF388E3C)];
  static const List<Color> menuGradient3 = [Color(0xFFFF9800), Color(0xFFF57C00)];
  static const List<Color> menuGradient4 = [Color(0xFF9C27B0), Color(0xFF7B1FA2)];
  static const List<Color> menuGradient5 = [Color(0xFFF44336), Color(0xFFD32F2F)];
}
