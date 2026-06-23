import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/role_display_helper.dart';
import '../widgets/app_alert.dart';

/// Screen untuk menambah akun guru baru
/// Mengikuti struktur tabel User database
class TambahGuruScreen extends StatefulWidget {
  const TambahGuruScreen({super.key});

  @override
  State<TambahGuruScreen> createState() => _TambahGuruScreenState();
}

class _TambahGuruScreenState extends State<TambahGuruScreen> {
  final _formKey = GlobalKey<FormState>();

  // User data
  final _namaController = TextEditingController();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  // Guru profile data
  final _nipController = TextEditingController();
  final _nuptkController = TextEditingController();
  final _alamatController = TextEditingController();
  final _golonganController = TextEditingController();
  final _tempatLahirController = TextEditingController();

  bool _isPasswordVisible = false;
  final Set<String> _selectedRoles = <String>{'guru'};
  String _selectedStatus = 'aktif';
  String _selectedGender = 'Laki-laki';
  DateTime? _selectedTanggalLahir;

  @override
  void dispose() {
    _namaController.dispose();
    _emailController.dispose();
    _nipController.dispose();
    _nuptkController.dispose();
    _alamatController.dispose();
    _golonganController.dispose();
    _tempatLahirController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Validasi dan simpan data
  Future<void> _simpanGuru() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedTanggalLahir == null) {
        AppAlert.error(context, message: 'Tanggal lahir wajib dipilih');
        return;
      }

      final newGuru = {
        'nama': _namaController.text.trim(),
        'email': _emailController.text.trim(),
        'role': primaryRoleValue(_selectedRoles),
        'roles': sortRoleValues(_selectedRoles),
        'username': _usernameController.text.trim(),
        'password': _passwordController.text,
        'status': _selectedStatus,
        'active': _selectedStatus == 'aktif',
        'nip': _nipController.text.trim(),
        'nuptk': _nuptkController.text.trim(),
        'alamat': _alamatController.text.trim(),
        'gender': _selectedGender,
        'golongan': _golonganController.text.trim(),
        'tanggal_lahir': _selectedTanggalLahir,
        'tempat_lahir': _tempatLahirController.text.trim(),
      };

      Navigator.pop(context, newGuru);
    }
  }

  Future<void> _pickTanggalLahir() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedTanggalLahir ?? DateTime(1990, 1, 1),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      locale: const Locale('id', 'ID'),
    );

    if (picked != null) {
      setState(() {
        _selectedTanggalLahir = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tambah Akun Guru'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Info card
            Card(
              color: AppColors.info.withAlpha(26),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: AppColors.info.withAlpha(51)),
              ),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.info, size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Form ini akan menyimpan data akun (users) dan profil (guru) secara terpisah.',
                        style: TextStyle(fontSize: 13, color: AppColors.info),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            _buildSectionTitle('Data Akun (users)'),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _namaController,
              label: 'Nama Lengkap',
              hint: 'Contoh: Budi Santoso, S.Pd',
              icon: Icons.person,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Nama tidak boleh kosong';
                }
                if (value.length < 3) {
                  return 'Nama minimal 3 karakter';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _emailController,
              label: 'Email',
              hint: 'Contoh: budi.santoso@smpjenar.sch.id',
              icon: Icons.email,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                final text = (value ?? '').trim();
                if (text.isEmpty) {
                  return 'Email tidak boleh kosong';
                }
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
                  return 'Format email tidak valid';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Field Username & Password
            _buildTextField(
              controller: _usernameController,
              label: 'Username',
              hint: 'Contoh: budi.santoso',
              icon: Icons.account_circle,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Username tidak boleh kosong';
                }
                if (value.length < 5) {
                  return 'Username minimal 5 karakter';
                }
                if (!RegExp(r'^[a-z0-9._]+$').hasMatch(value)) {
                  return 'Username hanya boleh huruf kecil, angka, titik, dan underscore';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildSectionTitle('Role Akun'),
            const SizedBox(height: 12),
            _buildRoleSelector(),
            const SizedBox(height: 16),

            // Field Password
            TextFormField(
              controller: _passwordController,
              obscureText: !_isPasswordVisible,
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: 'Minimal 6 karakter',
                prefixIcon: const Icon(Icons.lock, color: AppColors.primary),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                ),
                filled: true,
                fillColor: AppColors.primary.withAlpha(13),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.error),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.error, width: 2),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Password tidak boleh kosong';
                }
                if (value.length < 6) {
                  return 'Password minimal 6 karakter';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Status akun
            _buildSectionTitle('Status Akun'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(13),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pilih Status Akun',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatusOption(
                          'aktif',
                          'Aktif',
                          Icons.check_circle,
                          AppColors.success,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatusOption(
                          'nonaktif',
                          'Nonaktif',
                          Icons.cancel,
                          Colors.grey[600]!,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _buildSectionTitle('Data Profil Guru (guru)'),
            const SizedBox(height: 12),

            _buildTextField(
              controller: _nipController,
              label: 'NIP (Nomor Induk Pegawai)',
              hint: 'Contoh: 198505152010011001',
              icon: Icons.badge,
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'NIP tidak boleh kosong';
                }
                if (value.length != 18) {
                  return 'NIP harus 18 digit';
                }
                if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
                  return 'NIP hanya boleh berisi angka';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _nuptkController,
              label: 'NUPTK',
              hint: 'Contoh: 1234567890123456',
              icon: Icons.confirmation_number,
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  return 'NUPTK tidak boleh kosong';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _alamatController,
              label: 'Alamat',
              hint: 'Alamat lengkap domisili',
              icon: Icons.home,
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  return 'Alamat tidak boleh kosong';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _tempatLahirController,
              label: 'Tempat Lahir',
              hint: 'Contoh: Boyolali',
              icon: Icons.place,
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  return 'Tempat lahir tidak boleh kosong';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickTanggalLahir,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Tanggal Lahir',
                  prefixIcon: const Icon(Icons.calendar_month, color: AppColors.primary),
                  filled: true,
                  fillColor: AppColors.primary.withAlpha(13),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                ),
                child: Text(
                  _selectedTanggalLahir == null
                      ? 'Pilih tanggal lahir'
                      : '${_selectedTanggalLahir!.day}/${_selectedTanggalLahir!.month}/${_selectedTanggalLahir!.year}',
                  style: TextStyle(
                    color: _selectedTanggalLahir == null
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              initialValue: _selectedGender,
              decoration: InputDecoration(
                labelText: 'Gender',
                prefixIcon: const Icon(Icons.wc, color: AppColors.primary),
                filled: true,
                fillColor: AppColors.primary.withAlpha(13),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
              ),
              items: const [
                DropdownMenuItem(value: 'Laki-laki', child: Text('Laki-laki')),
                DropdownMenuItem(value: 'Perempuan', child: Text('Perempuan')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedGender = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _golonganController,
              label: 'Golongan',
              hint: 'Contoh: III/b',
              icon: Icons.class_,
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  return 'Golongan tidak boleh kosong';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            const SizedBox(height: 8),

            // Tombol Simpan
            ElevatedButton(
              onPressed: _simpanGuru,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.save),
                  SizedBox(width: 8),
                  Text(
                    'Simpan Akun Guru',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tombol Batal
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: Colors.grey[400]!),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Batal',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildRoleSelector() {
    final options = const [
      'kepala_sekolah',
      'kesiswaan',
      'guru',
    ];

    return FormField<List<String>>(
      initialValue: sortRoleValues(_selectedRoles),
      validator: (_) {
        if (_selectedRoles.isEmpty) {
          return 'Minimal satu role harus dipilih';
        }
        return null;
      },
      builder: (field) {
        return InputDecorator(
          decoration: InputDecoration(
            labelText: 'Role',
            prefixIcon: const Icon(
              Icons.admin_panel_settings,
              color: AppColors.primary,
            ),
            filled: true,
            fillColor: AppColors.primary.withAlpha(13),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            errorText: field.errorText,
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((role) {
              final selected = _selectedRoles.contains(role);
              return FilterChip(
                selected: selected,
                onSelected: (isSelected) {
                  setState(() {
                    if (isSelected) {
                      _selectedRoles.add(role);
                    } else {
                      _selectedRoles.remove(role);
                    }
                    field.didChange(sortRoleValues(_selectedRoles));
                  });
                },
                label: Text(roleLabelValue(role)),
                avatar: Icon(roleIconValue(role), size: 18),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required String? Function(String?) validator,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.primary),
        filled: true,
        fillColor: AppColors.primary.withAlpha(13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildStatusOption(
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    final isSelected = _selectedStatus == value;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedStatus = value;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withAlpha(26) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? color : Colors.grey[500],
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
