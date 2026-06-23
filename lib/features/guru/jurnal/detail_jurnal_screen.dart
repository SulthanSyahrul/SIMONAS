import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../providers/jurnal_absensi_supabase_provider.dart';

/// Screen untuk menampilkan detail jurnal mengajar guru
/// Menampilkan:
/// 1. Informasi Jurnal (tanggal, jam ke, kelas, mata pelajaran, status kehadiran, materi, catatan)
/// 2. Absensi Siswa (daftar siswa dengan status kehadiran)
/// 
/// Data jurnal diambil dari: Jurnal_Guru
/// - jurnal_id, user_id, kelas_id, mata_pelajaran_id, tahun_ajaran_id, semester
/// - tanggal, jam_ke, materi, status_kehadiran, catatan
/// 
/// Absensi siswa diambil dari: Absensi_Siswa
/// - absensi_id, jurnal_id, siswa_id, status_kehadiran
/// 
/// TODO: Query absensi siswa berdasarkan jurnal_id
/// TODO: Integrasi Firestore collection Absensi_Siswa
/// TODO: Load data secara realtime
class DetailJurnalScreen extends StatefulWidget {
  final JurnalAbsensiItem jurnal;

  const DetailJurnalScreen({
    super.key,
    required this.jurnal,
  });

  @override
  State<DetailJurnalScreen> createState() => _DetailJurnalScreenState();
}

class _DetailJurnalScreenState extends State<DetailJurnalScreen> {
  // Dummy data absensi siswa
  // Absensi siswa ditampilkan berdasarkan jurnal_id
  late List<Map<String, dynamic>> _absensiSiswa;

  @override
  void initState() {
    super.initState();
    _loadAbsensiSiswa();
  }

  /// Load data absensi siswa berdasarkan jurnal_id
  /// TODO: Implement actual query to Firestore
  void _loadAbsensiSiswa() {
    // Dummy data absensi siswa
    _absensiSiswa = _getDummyAbsensiSiswa();
  }

  /// Get dummy absensi siswa
  /// Status kehadiran: Hadir, Izin, Sakit, Alpa
  List<Map<String, dynamic>> _getDummyAbsensiSiswa() {
    return [
      {
        'absensi_id': 1,
        'jurnal_id': widget.jurnal.id,
        'siswa_id': 1,
        'nama_siswa': 'Ahmad Fauzi',
        'status_kehadiran': 'Hadir',
      },
      {
        'absensi_id': 2,
        'jurnal_id': widget.jurnal.id,
        'siswa_id': 2,
        'nama_siswa': 'Budi Santoso',
        'status_kehadiran': 'Hadir',
      },
      {
        'absensi_id': 3,
        'jurnal_id': widget.jurnal.id,
        'siswa_id': 3,
        'nama_siswa': 'Citra Dewi',
        'status_kehadiran': 'Izin',
      },
      {
        'absensi_id': 4,
        'jurnal_id': widget.jurnal.id,
        'siswa_id': 4,
        'nama_siswa': 'Dewi Lestari',
        'status_kehadiran': 'Hadir',
      },
      {
        'absensi_id': 5,
        'jurnal_id': widget.jurnal.id,
        'siswa_id': 5,
        'nama_siswa': 'Eka Putra',
        'status_kehadiran': 'Sakit',
      },
      {
        'absensi_id': 6,
        'jurnal_id': widget.jurnal.id,
        'siswa_id': 6,
        'nama_siswa': 'Fajar Ramadhan',
        'status_kehadiran': 'Hadir',
      },
      {
        'absensi_id': 7,
        'jurnal_id': widget.jurnal.id,
        'siswa_id': 7,
        'nama_siswa': 'Gita Ayu',
        'status_kehadiran': 'Alpa',
      },
      {
        'absensi_id': 8,
        'jurnal_id': widget.jurnal.id,
        'siswa_id': 8,
        'nama_siswa': 'Hadi Wijaya',
        'status_kehadiran': 'Hadir',
      },
      {
        'absensi_id': 9,
        'jurnal_id': widget.jurnal.id,
        'siswa_id': 9,
        'nama_siswa': 'Indah Permata',
        'status_kehadiran': 'Hadir',
      },
      {
        'absensi_id': 10,
        'jurnal_id': widget.jurnal.id,
        'siswa_id': 10,
        'nama_siswa': 'Joko Susanto',
        'status_kehadiran': 'Hadir',
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
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
            // Section 1: Informasi Jurnal
            _buildInformasiJurnalSection(),

            const Divider(height: 1, thickness: 1),

            // Section 2: Absensi Siswa
            _buildAbsensiSiswaSection(),
          ],
        ),
      ),
    );
  }

  /// Build section informasi jurnal
  Widget _buildInformasiJurnalSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              const Text(
                'Informasi Jurnal',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              // Tahun Ajaran
              _buildInfoRow(
                icon: Icons.school,
                label: 'Tahun Ajaran',
                value: widget.jurnal.tahunAjaranNama,
              ),
              const SizedBox(height: 12),

              // Semester
              _buildInfoRow(
                icon: Icons.event_note,
                label: 'Semester',
                value: 'Semester ${widget.jurnal.semester}',
              ),
              const SizedBox(height: 12),

              // Tanggal
              _buildInfoRow(
                icon: Icons.calendar_today,
                label: 'Tanggal',
                value: _formatDate(widget.jurnal.tanggal),
              ),
              const SizedBox(height: 12),

              // Jam ke
              _buildInfoRow(
                icon: Icons.access_time,
                label: 'Jam ke',
                value: 'Jam ke ${widget.jurnal.jamAwal} - ${widget.jurnal.jamAkhir}',
              ),
              const SizedBox(height: 12),

              // Kelas
              _buildInfoRow(
                icon: Icons.class_,
                label: 'Kelas',
                value: widget.jurnal.kelasNama,
              ),
              const SizedBox(height: 12),

              // Mata Pelajaran
              _buildInfoRow(
                icon: Icons.book,
                label: 'Mata Pelajaran',
                value: widget.jurnal.mapelNama,
              ),
              const SizedBox(height: 12),

              // Status Kehadiran Guru
              _buildInfoRow(
                icon: Icons.person,
                label: 'Status Kehadiran Guru',
                value: widget.jurnal.statusKehadiran,
                valueColor: widget.jurnal.statusKehadiran == 'Masuk'
                    ? AppColors.success
                    : AppColors.warning,
              ),
              const SizedBox(height: 12),

              // Materi Pembelajaran
              _buildInfoRow(
                icon: Icons.description,
                label: 'Materi Pembelajaran',
                value: widget.jurnal.materi,
              ),
              const SizedBox(height: 12),

              // Catatan
              _buildInfoRow(
                icon: Icons.note,
                label: 'Catatan',
                value: ((widget.jurnal.catatan ?? '').isEmpty)
                    ? '-'
                    : widget.jurnal.catatan!,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build info row
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: AppColors.primary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build section absensi siswa
  Widget _buildAbsensiSiswaSection() {
    // Hitung statistik kehadiran
    final hadir = _absensiSiswa
        .where((s) => s['status_kehadiran'] == 'Hadir')
        .length;
    final izin = _absensiSiswa
        .where((s) => s['status_kehadiran'] == 'Izin')
        .length;
    final sakit = _absensiSiswa
        .where((s) => s['status_kehadiran'] == 'Sakit')
        .length;
    final alpa = _absensiSiswa
        .where((s) => s['status_kehadiran'] == 'Alpa')
        .length;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          const Text(
            'Absensi Siswa',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),

          // Statistik ringkas
          Card(
            elevation: 1,
            color: Colors.grey[50],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('Hadir', hadir, AppColors.success),
                  _buildStatItem('Izin', izin, AppColors.warning),
                  _buildStatItem('Sakit', sakit, AppColors.info),
                  _buildStatItem('Alpa', alpa, AppColors.error),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // List absensi siswa
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _absensiSiswa.length,
            itemBuilder: (context, index) {
              final absensi = _absensiSiswa[index];
              return _buildAbsensiCard(absensi);
            },
          ),
        ],
      ),
    );
  }

  /// Build statistik item
  Widget _buildStatItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
          ),
        ),
      ],
    );
  }

  /// Build absensi card
  Widget _buildAbsensiCard(Map<String, dynamic> absensi) {
    final status = absensi['status_kehadiran'] as String;
    final color = _getStatusColor(status);
    final icon = _getStatusIcon(status);

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: color.withAlpha(77),
          width: 1,
        ),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withAlpha(26),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
        title: Text(
          absensi['nama_siswa'] as String,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withAlpha(26),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withAlpha(77),
              width: 1,
            ),
          ),
          child: Text(
            status,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ),
    );
  }

  /// Get status color
  /// Hadir → Hijau, Izin → Kuning, Sakit → Biru, Alpa → Merah
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

  /// Get status icon
  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Hadir':
        return Icons.check_circle;
      case 'Izin':
        return Icons.event_busy;
      case 'Sakit':
        return Icons.local_hospital;
      case 'Alpa':
        return Icons.cancel;
      default:
        return Icons.help;
    }
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
