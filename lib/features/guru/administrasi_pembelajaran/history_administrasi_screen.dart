import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_external_filter_bar.dart';

/// Screen untuk history administrasi pembelajaran
/// Menampilkan data dari 4 tabel:
/// - Silabus
/// - Program_Tahunan
/// - Program_Semester
/// - Rencana_Pembelajaran
///
/// Dengan filter:
/// - Jenis Dokumen (All, Silabus, Prota, Promes, RPP)
/// - Tahun Ajaran
/// - Semester
///
/// TODO: Query data dari Firestore (4 tabel digabung)
/// TODO: Implementasi filter
/// TODO: Implementasi view PDF
class HistoryAdministrasiScreen extends StatefulWidget {
  const HistoryAdministrasiScreen({super.key});

  @override
  State<HistoryAdministrasiScreen> createState() =>
      _HistoryAdministrasiScreenState();
}

class _HistoryAdministrasiScreenState extends State<HistoryAdministrasiScreen> {
  // Filter states
  String _selectedJenisDokumen = 'Semua';
  String? _selectedTahunAjaran;
  String? _selectedSemester;
  bool _isFilterVisible = true;

  // Dropdown data
  final List<String> _jenisDokumenList = [
    'Semua',
    'Silabus',
    'Program Tahunan',
    'Program Semester',
    'RPP',
  ];

  final List<String> _tahunAjaranList = ['2025/2026', '2024/2025', '2023/2024'];

  final List<String> _semesterList = ['Ganjil', 'Genap'];

  // TODO: Replace with actual data from Firestore
  final List<Map<String, dynamic>> _dummyData = [
    {
      'jenis_dokumen': 'Silabus',
      'tahun_ajaran': '2024/2025',
      'semester': 'Ganjil',
      'kelas': '7A',
      'mata_pelajaran': 'Matematika',
      'tanggal_upload': '2024-08-15',
      'file_url': 'https://example.com/silabus_matematika_7a.pdf',
    },
    {
      'jenis_dokumen': 'Program Tahunan',
      'tahun_ajaran': '2024/2025',
      'semester': 'Ganjil',
      'kelas': '7A',
      'mata_pelajaran': 'Matematika',
      'tanggal_upload': '2024-08-10',
      'file_url': 'https://example.com/prota_matematika_7a.pdf',
    },
    {
      'jenis_dokumen': 'Program Semester',
      'tahun_ajaran': '2024/2025',
      'semester': 'Ganjil',
      'kelas': '7A',
      'mata_pelajaran': 'IPA',
      'tanggal_upload': '2024-08-20',
      'file_url': 'https://example.com/promes_ipa_7a.pdf',
    },
    {
      'jenis_dokumen': 'RPP',
      'tahun_ajaran': '2024/2025',
      'semester': 'Ganjil',
      'kelas': '8B',
      'mata_pelajaran': 'Bahasa Indonesia',
      'tanggal_upload': '2024-08-25',
      'file_url': 'https://example.com/rpp_bahasa_8b.pdf',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final filteredData = _getFilteredData();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Administrasi'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          _buildFilterSection(),
          const Divider(height: 1),
          if (filteredData.isEmpty)
            _buildEmptyState()
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: filteredData.length,
              itemBuilder: (context, index) {
                return _buildHistoryCard(filteredData[index]);
              },
            ),
        ],
      ),
    );
  }

  /// Build filter section
  Widget _buildFilterSection() {
    return AppExternalFilterBar(
      isExpanded: _isFilterVisible,
      onToggle: () {
        setState(() {
          _isFilterVisible = !_isFilterVisible;
        });
      },
      onReset: _resetFilter,
      onApply: () => setState(() {}),
      children: [
        AppExternalFilterField(
          label: 'Jenis Dokumen',
          child: DropdownButtonFormField<String>(
            initialValue: _selectedJenisDokumen,
            decoration: appExternalFilterDecoration(
              hintText: 'Pilih jenis dokumen',
              icon: Icons.description_rounded,
            ),
            items: _jenisDokumenList.map((item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(item, style: const TextStyle(fontSize: 14)),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedJenisDokumen = value!;
              });
            },
          ),
        ),
        AppExternalFilterField(
          label: 'Tahun Ajaran',
          child: DropdownButtonFormField<String>(
            initialValue: _selectedTahunAjaran,
            decoration: appExternalFilterDecoration(
              hintText: 'Semua tahun ajaran',
              icon: Icons.calendar_today_rounded,
            ),
            items: _tahunAjaranList.map((item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(item, style: const TextStyle(fontSize: 14)),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedTahunAjaran = value;
              });
            },
          ),
        ),
        AppExternalFilterField(
          label: 'Semester',
          child: DropdownButtonFormField<String>(
            initialValue: _selectedSemester,
            decoration: appExternalFilterDecoration(
              hintText: 'Semua semester',
              icon: Icons.event_note_rounded,
            ),
            items: _semesterList.map((item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(item, style: const TextStyle(fontSize: 14)),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedSemester = value;
              });
            },
          ),
        ),
      ],
    );
  }

  /// Build history card
  Widget _buildHistoryCard(Map<String, dynamic> data) {
    final jenisDokumen = data['jenis_dokumen'] as String;
    final color = _getColorByJenisDokumen(jenisDokumen);
    final icon = _getIconByJenisDokumen(jenisDokumen);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with jenis dokumen
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withAlpha(26),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        jenisDokumen,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      Text(
                        data['mata_pelajaran'] as String,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Details
            _buildDetailRow(
              Icons.calendar_today,
              'Tahun Ajaran',
              data['tahun_ajaran'] as String,
            ),
            const SizedBox(height: 6),
            _buildDetailRow(
              Icons.event_note,
              'Semester',
              data['semester'] as String,
            ),
            const SizedBox(height: 6),
            _buildDetailRow(Icons.class_, 'Kelas', data['kelas'] as String),
            const SizedBox(height: 6),
            _buildDetailRow(
              Icons.access_time,
              'Tanggal Upload',
              data['tanggal_upload'] as String,
            ),
            const SizedBox(height: 12),

            // Action button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _viewPdf(data['file_url'] as String),
                icon: const Icon(Icons.picture_as_pdf, size: 18),
                label: const Text('Lihat File'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build detail row
  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  /// Build empty state
  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 96),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Tidak ada data',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Belum ada dokumen yang diupload',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  /// Get filtered data
  /// TODO: Implement actual query to Firestore
  List<Map<String, dynamic>> _getFilteredData() {
    return _dummyData.where((item) {
      // Filter by jenis dokumen
      if (_selectedJenisDokumen != 'Semua' &&
          item['jenis_dokumen'] != _selectedJenisDokumen) {
        return false;
      }

      // Filter by tahun ajaran
      if (_selectedTahunAjaran != null &&
          item['tahun_ajaran'] != _selectedTahunAjaran) {
        return false;
      }

      // Filter by semester
      if (_selectedSemester != null && item['semester'] != _selectedSemester) {
        return false;
      }

      return true;
    }).toList();
  }

  /// Reset filter
  void _resetFilter() {
    setState(() {
      _selectedJenisDokumen = 'Semua';
      _selectedTahunAjaran = null;
      _selectedSemester = null;
    });
  }

  /// Get color by jenis dokumen
  Color _getColorByJenisDokumen(String jenis) {
    switch (jenis) {
      case 'Silabus':
        return const Color(0xFF2196F3);
      case 'Program Tahunan':
        return const Color(0xFF4CAF50);
      case 'Program Semester':
        return const Color(0xFFFF9800);
      case 'RPP':
        return const Color(0xFF9C27B0);
      default:
        return AppColors.primary;
    }
  }

  /// Get icon by jenis dokumen
  IconData _getIconByJenisDokumen(String jenis) {
    switch (jenis) {
      case 'Silabus':
        return Icons.description;
      case 'Program Tahunan':
        return Icons.calendar_today;
      case 'Program Semester':
        return Icons.event_note;
      case 'RPP':
        return Icons.assignment;
      default:
        return Icons.file_present;
    }
  }

  /// View PDF
  /// TODO: Implement PDF viewer
  void _viewPdf(String url) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Membuka file: $url'),
        backgroundColor: AppColors.info,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
