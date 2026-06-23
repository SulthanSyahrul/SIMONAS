import 'package:flutter/material.dart';
import '../providers/academic_year_provider.dart';

/// Widget untuk AppBar title dengan tahun ajaran statis di sebelah kiri
/// Digunakan di semua screen guru untuk konsistensi UI
class AppBarTitleWithYear extends StatelessWidget {
  final AcademicYearProvider provider;
  final String title;

  const AppBarTitleWithYear({
    super.key,
    required this.provider,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Tahun ajaran statis di kiri
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(26),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: Colors.white.withAlpha(77),
              width: 1,
            ),
          ),
          child: const Text(
            '2025/2026',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        
        const SizedBox(width: 12),
        
        // Divider vertikal
        Container(
          height: 24,
          width: 1,
          color: Colors.white.withAlpha(77),
        ),
        
        const SizedBox(width: 12),
        
        // Judul halaman
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
