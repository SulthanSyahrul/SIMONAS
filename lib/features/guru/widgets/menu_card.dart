import 'package:flutter/material.dart';

/// Widget reusable untuk menampilkan menu card di dashboard
/// Menggunakan gradient dan icon untuk tampilan yang menarik
class MenuCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const MenuCard({
    super.key,
    required this.title,
    required this.icon,
    required this.gradientColors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              Icon(
                icon,
                size: 48,
                color: Colors.white,
              ),
              const SizedBox(height: 12),
              
              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
