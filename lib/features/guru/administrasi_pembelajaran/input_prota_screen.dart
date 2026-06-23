import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Screen untuk input Program Tahunan (Prota)
/// Menyimpan data ke tabel Program_Tahunan dengan struktur:
/// - prota_id
/// - user_id
/// - kelas_id
/// - mata_pelajaran_id
/// - tahun_ajaran_id
/// - semester
/// - file_pdf
/// - tanggal_upload
/// 
/// TODO: Integrasi Firebase Storage untuk upload file PDF
/// TODO: Metadata file disimpan di Firestore (tabel Program_Tahunan)
/// TODO: Validasi file hanya PDF dan ukuran maksimal
class InputProtaScreen extends StatefulWidget {
  const InputProtaScreen({super.key});

  @override
  State<InputProtaScreen> createState() => _InputProtaScreenState();
}

class _InputProtaScreenState extends State<InputProtaScreen> {
  // Form key
  final _formKey = GlobalKey<FormState>();

  // Form fields
  String? _selectedTahunAjaran;
  String? _selectedSemester;
  String? _selectedKelas;
  String? _selectedMataPelajaran;
  String? _selectedFileName;

  // Dropdown data
  final List<String> _tahunAjaranList = [
    '2025/2026',
    '2024/2025',
    '2023/2024',
  ];

  final List<String> _semesterList = [
    'Ganjil',
    'Genap',
  ];

  final List<String> _kelasList = [
    '7A',
    '7B',
    '8A',
    '8B',
    '9A',
    '9B',
  ];

  final List<String> _mataPelajaranList = [
    'Matematika',
    'IPA',
    'IPS',
    'Bahasa Indonesia',
    'Bahasa Inggris',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Input Program Tahunan'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info card
                Card(
                  color: AppColors.success.withAlpha(26),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: AppColors.success,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Upload program tahunan pembelajaran per semester',
                            style: TextStyle(
                              color: AppColors.success,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Section title
                const Text(
                  'Informasi Program Tahunan',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),

                // Tahun Ajaran
                _buildDropdownField(
                  label: 'Tahun Ajaran',
                  value: _selectedTahunAjaran,
                  items: _tahunAjaranList,
                  onChanged: (value) {
                    setState(() {
                      _selectedTahunAjaran = value;
                    });
                  },
                  icon: Icons.calendar_today,
                ),
                const SizedBox(height: 16),

                // Semester
                _buildDropdownField(
                  label: 'Semester',
                  value: _selectedSemester,
                  items: _semesterList,
                  onChanged: (value) {
                    setState(() {
                      _selectedSemester = value;
                    });
                  },
                  icon: Icons.event_note,
                ),
                const SizedBox(height: 16),

                // Kelas
                _buildDropdownField(
                  label: 'Kelas',
                  value: _selectedKelas,
                  items: _kelasList,
                  onChanged: (value) {
                    setState(() {
                      _selectedKelas = value;
                    });
                  },
                  icon: Icons.class_,
                ),
                const SizedBox(height: 16),

                // Mata Pelajaran
                _buildDropdownField(
                  label: 'Mata Pelajaran',
                  value: _selectedMataPelajaran,
                  items: _mataPelajaranList,
                  onChanged: (value) {
                    setState(() {
                      _selectedMataPelajaran = value;
                    });
                  },
                  icon: Icons.book,
                ),
                const SizedBox(height: 24),

                // Upload Section
                const Text(
                  'Upload File PDF',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),

                // File upload card
                _buildFileUploadCard(),
                const SizedBox(height: 32),

                // Simpan button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isFormComplete() ? _handleSimpan : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey[300],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Simpan Program Tahunan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build dropdown field
  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: value,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AppColors.primary),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
          hint: Text('Pilih $label'),
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            );
          }).toList(),
          onChanged: onChanged,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return '$label harus dipilih';
            }
            return null;
          },
        ),
      ],
    );
  }

  /// Build file upload card
  Widget _buildFileUploadCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'File Program Tahunan (PDF)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            if (_selectedFileName == null)
              OutlinedButton.icon(
                onPressed: _handleFileUpload,
                icon: const Icon(Icons.upload_file),
                label: const Text('Upload PDF'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.success.withAlpha(26),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.success.withAlpha(77)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.picture_as_pdf,
                      color: AppColors.success,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedFileName!,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'File siap diupload',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _selectedFileName = null;
                        });
                      },
                      icon: Icon(
                        Icons.close,
                        color: AppColors.error,
                      ),
                      tooltip: 'Hapus file',
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Check if form is complete
  bool _isFormComplete() {
    return _selectedTahunAjaran != null &&
        _selectedSemester != null &&
        _selectedKelas != null &&
        _selectedMataPelajaran != null &&
        _selectedFileName != null;
  }

  /// Handle file upload
  /// TODO: Implementasi file picker untuk memilih PDF
  /// TODO: Validasi file hanya PDF dan ukuran maksimal
  void _handleFileUpload() {
    // Simulasi file picker
    setState(() {
      _selectedFileName = 'Prota_${_selectedMataPelajaran ?? 'Dokumen'}_${_selectedKelas ?? ''}_2025.pdf';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('File berhasil dipilih'),
        backgroundColor: AppColors.success,
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Handle simpan
  /// TODO: Upload file ke Firebase Storage
  /// TODO: Simpan metadata ke Firestore (tabel Program_Tahunan)
  void _handleSimpan() {
    if (_formKey.currentState!.validate()) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Konfirmasi'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Simpan program tahunan dengan data:'),
              const SizedBox(height: 12),
              _buildConfirmRow('Tahun Ajaran', _selectedTahunAjaran ?? ''),
              _buildConfirmRow('Semester', _selectedSemester ?? ''),
              _buildConfirmRow('Kelas', _selectedKelas ?? ''),
              _buildConfirmRow('Mata Pelajaran', _selectedMataPelajaran ?? ''),
              _buildConfirmRow('File', _selectedFileName ?? ''),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _saveProta();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: const Text('Simpan'),
            ),
          ],
        ),
      );
    }
  }

  /// Build confirm row
  Widget _buildConfirmRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  /// Save program tahunan
  /// TODO: Implement actual save to Firestore
  Future<void> _saveProta() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) {
      return;
    }

    navigator.pop();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Program Tahunan berhasil disimpan'),
        backgroundColor: AppColors.success,
        duration: Duration(seconds: 2),
      ),
    );
    navigator.pop();
  }
}
