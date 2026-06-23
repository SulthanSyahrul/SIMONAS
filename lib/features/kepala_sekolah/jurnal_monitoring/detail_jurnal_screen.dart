import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../models/model_utils.dart';
import '../../../providers/supabase_providers.dart';

/// Screen untuk menampilkan detail jurnal
/// Menampilkan informasi lengkap jurnal dan daftar absensi siswa
/// Struktur data:
/// - Jurnal_Guru (jurnal_id, user_id, kelas_id, mata_pelajaran_id, tanggal, jam_ke, materi, status_kehadiran, catatan)
/// - Absensi_Siswa (absensi_id, jurnal_id, siswa_id, status_kehadiran)
/// Monitoring jurnal menggunakan relasi jurnal_id
class DetailJurnalScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> jurnalData;

  const DetailJurnalScreen({
    super.key,
    required this.jurnalData,
  });

  @override
  ConsumerState<DetailJurnalScreen> createState() => _DetailJurnalScreenState();
}

class _DetailJurnalScreenState extends ConsumerState<DetailJurnalScreen> {
  List<_AbsensiDisplayItem> _absensiData = const [];
  bool _isLoadingAbsensi = true;
  String? _absensiError;

  @override
  void initState() {
    super.initState();
    _loadAbsensiData();
  }

  String? get _jurnalId {
    final dynamic fromJurnalId = widget.jurnalData['jurnal_id'];
    if (fromJurnalId != null && fromJurnalId.toString().trim().isNotEmpty) {
      return fromJurnalId.toString().trim();
    }
    final dynamic fromId = widget.jurnalData['id'];
    if (fromId != null && fromId.toString().trim().isNotEmpty) {
      return fromId.toString().trim();
    }
    return null;
  }

  Future<void> _loadAbsensiData() async {
    final jurnalId = _jurnalId;
    if (jurnalId == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _absensiData = const [];
        _isLoadingAbsensi = false;
        _absensiError = null;
      });
      return;
    }

    setState(() {
      _isLoadingAbsensi = true;
      _absensiError = null;
    });

    try {
      final absensiService = ref.read(absensiJurnalServiceProvider);

      final linkedRows = await absensiService.getByJurnalId(jurnalId);
      final allRows = linkedRows;
      if (allRows.isEmpty) {
        if (!mounted) {
          return;
        }
        setState(() {
          _absensiData = const [];
          _isLoadingAbsensi = false;
          _absensiError = null;
        });
        return;
      }

      final mapped = allRows.map((row) {
        final namaSiswa = (row.siswaNama?.trim().isNotEmpty ?? false)
            ? row.siswaNama!.trim()
            : row.siswaId;
        final nis = row.nis?.trim();

        return _AbsensiDisplayItem(
          id: row.id,
          siswaId: row.siswaId,
          namaSiswa: namaSiswa,
          nis: (nis == null || nis.isEmpty) ? null : nis,
          statusKehadiran: _normalizeStatus(row.statusKehadiran),
          catatan: row.catatan?.trim(),
        );
      }).toList()..sort(
        (a, b) => a.namaSiswa.toLowerCase().compareTo(b.namaSiswa.toLowerCase()),
      );

      if (!mounted) {
        return;
      }
      setState(() {
        _absensiData = mapped;
        _isLoadingAbsensi = false;
        _absensiError = null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingAbsensi = false;
        _absensiError = 'Gagal memuat data absensi.';
      });
    }
  }

  String _normalizeStatus(String raw) {
    final value = raw.trim().toLowerCase();
    switch (value) {
      case 'hadir':
      case 'masuk':
        return 'Hadir';
      case 'izin':
        return 'Izin';
      case 'sakit':
        return 'Sakit';
      case 'alpa':
      case 'alpha':
        return 'Alpa';
      default:
        return raw.trim().isEmpty ? 'Hadir' : raw.trim();
    }
  }

  /// Hitung statistik kehadiran
  Map<String, int> get _statistics {
    final stats = {
      'Hadir': 0,
      'Izin': 0,
      'Sakit': 0,
      'Alpa': 0,
    };
    
    for (var absensi in _absensiData) {
      final status = absensi.statusKehadiran;
      stats[status] = (stats[status] ?? 0) + 1;
    }
    
    return stats;
  }

  /// Dapatkan warna berdasarkan status kehadiran
  Color _getStatusColor(String status) {
    switch (status) {
      case 'Hadir':
        return AppColors.success;
      case 'Izin':
        return AppColors.warning;
      case 'Sakit':
        return AppColors.info;
      case 'Alpa':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final jurnal = widget.jurnalData;
    final String statusKehadiran = jurnal['status_kehadiran'];
    final Color statusColor = statusKehadiran == 'Masuk' ? AppColors.success : AppColors.warning;
    final DateTime tanggal = DateTime.parse(jurnal['tanggal']);
    final stats = _statistics;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Jurnal'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Informasi Jurnal Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Informasi Jurnal',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: statusColor, width: 2),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow('Tahun Ajaran', jurnal['tahun_ajaran'] ?? '2024/2025'),
                          const Divider(height: 24),
                          _buildDetailRow('Semester', jurnal['semester'] ?? 'Semester 1'),
                          const Divider(height: 24),
                          _buildDetailRow('Tanggal', '${tanggal.day}/${tanggal.month}/${tanggal.year}'),
                          const Divider(height: 24),
                          _buildDetailRow(
                            'Jam Pelajaran',
                            'Jam ke ${jurnal['jam_awal'] ?? jurnal['jam_ke']} - ${jurnal['jam_akhir'] ?? jurnal['jam_ke']} '
                            '(${ModelUtils.getWaktuMulai(ModelUtils.integer(jurnal['jam_awal'] ?? jurnal['jam_ke'])) ?? '--:--'} - '
                            '${ModelUtils.getWaktuSelesai(ModelUtils.integer(jurnal['jam_akhir'] ?? jurnal['jam_ke'])) ?? '--:--'})',
                          ),
                          const Divider(height: 24),
                          _buildDetailRow('Kelas', jurnal['kelas']),
                          const Divider(height: 24),
                          _buildDetailRow('Mata Pelajaran', jurnal['mata_pelajaran']),
                          const Divider(height: 24),
                          _buildDetailRow('Nama Guru', jurnal['nama_guru']),
                          const Divider(height: 24),
                          _buildDetailRow('Status Kehadiran Guru', statusKehadiran, statusColor: statusColor),
                          const Divider(height: 24),
                          _buildDetailRow('Materi Pembelajaran', jurnal['materi']),
                          if (jurnal['catatan'] != null && jurnal['catatan'].toString().isNotEmpty) ...[
                            const Divider(height: 24),
                            _buildDetailRow('Catatan', jurnal['catatan']),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Statistik Kehadiran Siswa
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Statistik Kehadiran Siswa',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard('Hadir', stats['Hadir']!, AppColors.success),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard('Izin', stats['Izin']!, AppColors.warning),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard('Sakit', stats['Sakit']!, AppColors.info),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard('Alpa', stats['Alpa']!, AppColors.error),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Daftar Absensi Siswa
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Daftar Absensi Siswa',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_isLoadingAbsensi)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_absensiError != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        _absensiError!,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 13,
                        ),
                      ),
                    )
                  else if (_absensiData.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Belum ada data absensi.',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _absensiData.length,
                      itemBuilder: (context, index) {
                        final absensi = _absensiData[index];
                        return _buildAbsensiCard(absensi);
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? statusColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const Text(
          ': ',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        Expanded(
          child: statusColor != null
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(26),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                )
              : Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, int count, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: color, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAbsensiCard(_AbsensiDisplayItem absensi) {
    final String status = absensi.statusKehadiran;
    final Color statusColor = _getStatusColor(status);
    
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey[200]!, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: statusColor.withAlpha(26),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  absensi.namaSiswa.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    absensi.namaSiswa,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (absensi.nis != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'NIS: ${absensi.nis}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  if (absensi.catatan != null && absensi.catatan!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Catatan: ${absensi.catatan}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withAlpha(26),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusColor),
              ),
              child: Text(
                status,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AbsensiDisplayItem {
  final String id;
  final String siswaId;
  final String namaSiswa;
  final String? nis;
  final String statusKehadiran;
  final String? catatan;

  const _AbsensiDisplayItem({
    required this.id,
    required this.siswaId,
    required this.namaSiswa,
    required this.nis,
    required this.statusKehadiran,
    required this.catatan,
  });
}
