import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../providers/jurnal_absensi_supabase_provider.dart';

/// Widget reusable untuk menampilkan item history jurnal
/// Menggunakan Card dengan layout yang informatif
class JurnalHistoryCard extends StatelessWidget {
  final JurnalAbsensiItem jurnal;
  final VoidCallback? onTap;

  const JurnalHistoryCard({
    super.key,
    required this.jurnal,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Tanggal dan Kelas
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Tanggal
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDate(jurnal.tanggal),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                  // Kelas
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withAlpha(51),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppColors.primary.withAlpha(128),
                      ),
                    ),
                    child: Text(
                      'Kelas ${jurnal.kelasNama}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Mata Pelajaran
              Text(
                jurnal.mapelNama,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),

              // Materi
              Text(
                jurnal.materi,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),

              // Info: Tahun Ajaran, Semester, Jam ke
              Row(
                children: [
                  // Tahun Ajaran
                  Row(
                    children: [
                      const Icon(
                        Icons.school,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        jurnal.tahunAjaranNama,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  // Semester
                  Row(
                    children: [
                      const Icon(
                        Icons.event_note,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Semester ${jurnal.semester}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  // Jam ke
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Jam ke ${jurnal.jamAwal}-${jurnal.jamAkhir}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Footer: Status Kehadiran
              Row(
                children: [
                  const Icon(
                    Icons.person,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    jurnal.statusKehadiran,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: jurnal.statusKehadiran == 'Masuk'
                              ? AppColors.success
                              : AppColors.warning,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime? value) {
    if (value == null) {
      return '-';
    }
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }
}
