import 'package:flutter/material.dart';
import '../../../core/utils/role_display_helper.dart';
import '../../../core/constants/app_colors.dart';
import '../widgets/app_alert.dart';

/// Screen untuk mengedit akun guru
class EditGuruScreen extends StatefulWidget {
  final Map<String, dynamic> guru;

  const EditGuruScreen({
    super.key,
    required this.guru,
  });

  @override
  State<EditGuruScreen> createState() => _EditGuruScreenState();
}

class _EditGuruScreenState extends State<EditGuruScreen> {
  final _formKey = GlobalKey<FormState>();
  static const int _minimumPasswordLength = 6;

  // User data
  late TextEditingController _namaController;
  late TextEditingController _emailController;
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  late TextEditingController _confirmPasswordController;

  // Guru profile data
  late TextEditingController _nipController;
  late TextEditingController _nuptkController;
  late TextEditingController _alamatController;
  late TextEditingController _golonganController;
  late TextEditingController _tempatLahirController;

  late String _selectedStatus;
  late final Set<String> _selectedRoles;
  late String _selectedGender;
  DateTime? _selectedTanggalLahir;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  @override
  void initState() {
    super.initState();

    _namaController = TextEditingController(text: (widget.guru['nama'] ?? '').toString());
    _emailController = TextEditingController(text: (widget.guru['email'] ?? '').toString());
    _usernameController = TextEditingController(text: (widget.guru['username'] ?? '').toString());
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();

    _nipController = TextEditingController(text: (widget.guru['nip'] ?? '').toString());
    _nuptkController = TextEditingController(text: (widget.guru['nuptk'] ?? '').toString());
    _alamatController = TextEditingController(text: (widget.guru['alamat'] ?? '').toString());
    _golonganController = TextEditingController(text: (widget.guru['golongan'] ?? '').toString());
    _tempatLahirController = TextEditingController(text: (widget.guru['tempat_lahir'] ?? '').toString());

    final statusRaw = (widget.guru['status'] ?? 'aktif').toString().toLowerCase();
    _selectedStatus = statusRaw == 'nonaktif' ? 'nonaktif' : 'aktif';

    final rawRoles = widget.guru['roles'];
    if (rawRoles is Iterable) {
      _selectedRoles = Set<String>.from(
        sortRoleValues(rawRoles.map((item) => item.toString())),
      );
    } else {
      _selectedRoles = Set<String>.from(
        sortRoleValues(<String>[
          (widget.guru['role'] ?? 'guru').toString(),
        ]),
      );
    }

    final genderRaw = (widget.guru['gender'] ?? '').toString();
    _selectedGender = _normalizeGender(genderRaw);
    _selectedTanggalLahir = _parseDate(widget.guru['tanggal_lahir']);
  }

  @override
  void dispose() {
    _namaController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nipController.dispose();
    _nuptkController.dispose();
    _alamatController.dispose();
    _golonganController.dispose();
    _tempatLahirController.dispose();
    super.dispose();
  }

  /// Validasi dan update data
  void _updateGuru() {
    if (_formKey.currentState!.validate()) {
      if (_selectedTanggalLahir == null) {
        AppAlert.error(context, message: 'Tanggal lahir wajib dipilih');
        return;
      }

      final updatedGuru = Map<String, dynamic>.from(widget.guru);
      updatedGuru['nama'] = _namaController.text.trim();
      updatedGuru['email'] = _emailController.text.trim();
      updatedGuru['role'] = primaryRoleValue(_selectedRoles);
      updatedGuru['roles'] = sortRoleValues(_selectedRoles);
      updatedGuru['username'] = _usernameController.text.trim();
      updatedGuru['status'] = _selectedStatus;
      updatedGuru['active'] = _selectedStatus == 'aktif';

      updatedGuru['nip'] = _nipController.text.trim();
      updatedGuru['nuptk'] = _nuptkController.text.trim();
      updatedGuru['alamat'] = _alamatController.text.trim();
      updatedGuru['gender'] = _selectedGender;
      updatedGuru['golongan'] = _golonganController.text.trim();
      updatedGuru['tanggal_lahir'] = _selectedTanggalLahir;
      updatedGuru['tempat_lahir'] = _tempatLahirController.text.trim();
      updatedGuru['password'] = _passwordController.text.trim();
      updatedGuru['password_changed'] = _passwordController.text.trim().isNotEmpty;

      Navigator.pop(context, updatedGuru);
    }
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is DateTime) {
      return DateTime(value.year, value.month, value.day);
    }
    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) {
      return null;
    }
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  String _normalizeGender(String raw) {
    final value = raw.trim().toLowerCase();
    if (value == 'p' || value == 'perempuan' || value == 'wanita') {
      return 'Perempuan';
    }
    if (value == 'l' ||
        value == 'laki-laki' ||
        value == 'laki laki' ||
        value == 'pria') {
      return 'Laki-laki';
    }
    return 'Laki-laki';
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
        title: const Text('Edit Akun Guru'),
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
                        'Perubahan akan memperbarui data akun (users) dan profil (guru).',
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
            const SizedBox(height: 24),

            _buildSectionTitle('Akun Login'),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _usernameController,
              label: 'Username',
              hint: 'Contoh: budi.santoso',
              icon: Icons.account_circle,
              readOnly: true,
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

            TextFormField(
              controller: _passwordController,
              obscureText: !_isPasswordVisible,
              decoration: InputDecoration(
                labelText: 'Password Baru (Opsional)',
                hintText: 'Kosongkan jika tidak ingin mengubah password',
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
                final text = (value ?? '').trim();
                if (text.isEmpty) {
                  return null;
                }
                if (text.length < _minimumPasswordLength) {
                  return 'Password minimal $_minimumPasswordLength karakter';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: !_isConfirmPasswordVisible,
              decoration: InputDecoration(
                labelText: 'Konfirmasi Password Baru',
                hintText: 'Ulangi password baru',
                prefixIcon: const Icon(Icons.lock_reset, color: AppColors.primary),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isConfirmPasswordVisible
                        ? Icons.visibility
                        : Icons.visibility_off,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () {
                    setState(() {
                      _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
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
                final password = _passwordController.text.trim();
                final confirmation = (value ?? '').trim();
                if (password.isEmpty && confirmation.isEmpty) {
                  return null;
                }
                if (password.isEmpty && confirmation.isNotEmpty) {
                  return 'Isi password baru terlebih dahulu';
                }
                if (confirmation.isEmpty) {
                  return 'Konfirmasi password baru wajib diisi';
                }
                if (confirmation != password) {
                  return 'Konfirmasi password tidak cocok';
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
            const SizedBox(height: 16),
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
            const SizedBox(height: 32),

            // Tombol Simpan
            ElevatedButton(
              onPressed: _updateGuru,
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
                    'Simpan Perubahan',
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
    bool readOnly = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
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
