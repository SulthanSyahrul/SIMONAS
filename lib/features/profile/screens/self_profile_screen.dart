import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/role_display_helper.dart';
import '../providers/self_profile_provider.dart';

class SelfProfileScreen extends ConsumerWidget {
  final String uid;
  final String role;
  final SelfProfileType profileType;

  const SelfProfileScreen({
    super.key,
    required this.uid,
    required this.role,
    required this.profileType,
  });

  bool get _shouldShowTeachingInfo =>
      profileType == SelfProfileType.staff && role.trim().toLowerCase() == 'guru';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = SelfProfileArgs(uid: uid, role: role, type: profileType);
    final state = ref.watch(selfProfileProvider(args));
    final notifier = ref.read(selfProfileProvider(args).notifier);
    final user = state.user;
    final identifier = _identifierText(state);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil Saya'),
        actions: [
          IconButton(
            onPressed: state.isLoading
                ? null
                : () => notifier.loadProfile(forceRefresh: true),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: state.isLoading && user == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildProfileCard(
                  context,
                  userName: user?.nama ?? 'Profil belum tersedia',
                  roleLabel: _roleLabel(role),
                  identifier: identifier,
                  profileType: profileType,
                ),
                if (_shouldShowTeachingInfo) ...[
                  const SizedBox(height: 16),
                  _buildTeachingResponsibilitySection(context, state),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: user == null
                        ? null
                        : () => _openEditPage(context, ref, args, state),
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit Profil'),
                  ),
                ),
                const SizedBox(height: 16),
                _buildAccountSection(context, state),
                const SizedBox(height: 16),
                _buildProfileSection(context, state),
                if (state.error != null && state.error!.trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    state.error!,
                    style: const TextStyle(color: AppColors.error),
                  ),
                ],
              ],
            ),
    );
  }

  Future<void> _openEditPage(
    BuildContext context,
    WidgetRef ref,
    SelfProfileArgs args,
    SelfProfileState state,
  ) async {
    final result = await Navigator.of(context).push<_SelfProfileSaveResult>(
      MaterialPageRoute(
        builder: (_) => _EditSelfProfileScreen(args: args, initialState: state),
      ),
    );

    if (result != null && context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Berhasil'),
            content: Text(
              result.passwordChanged
                  ? 'Data dan password berhasil diperbarui.'
                  : 'Data berhasil diperbarui.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );

      ref.read(selfProfileProvider(args).notifier).clearError();
    }
  }

  Widget _buildProfileCard(
    BuildContext context, {
    required String userName,
    required String roleLabel,
    required String identifier,
    required SelfProfileType profileType,
  }) {
    final icon = profileType == SelfProfileType.siswa
        ? Icons.school
        : Icons.badge;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: profileType == SelfProfileType.siswa
                      ? const [Color(0xFF0EA5E9), Color(0xFF2563EB)]
                      : AppColors.menuGradient1,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Icon(icon, size: 52, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Text(
              userName,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              roleLabel,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withAlpha(38),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                identifier,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountSection(BuildContext context, SelfProfileState state) {
    final user = state.user;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Data Akun',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _infoRow('Nama', user?.nama ?? '-'),
            _infoRow('UID', user?.uid ?? uid),
            _infoRow('Role', _roleLabel(role)),
            _infoRow('Email', user?.email ?? '-'),
            _infoRow(
              'Username',
              (user?.username ?? '').trim().isEmpty ? '-' : user!.username!,
            ),
            _infoRow('Dibuat', _formatDateTime(user?.createdAt)),
            _infoRow('Diperbarui', _formatDateTime(user?.updatedAt)),
          ],
        ),
      ),
    );
  }

  Widget _buildTeachingResponsibilitySection(
    BuildContext context,
    SelfProfileState state,
  ) {
    final activeYear = state.activeTahunAjaran;
    final waliKelas = state.waliKelasAssignments;
    final taughtSubjects = state.taughtSubjects;
    final taughtClasses = state.taughtClasses;

    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.groups_rounded, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Wali Kelas',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                if (activeYear != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Tahun Ajaran Aktif: ${activeYear.nama}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (waliKelas.isEmpty)
                  const Text('Tidak menjadi wali kelas pada tahun ajaran aktif.')
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: waliKelas
                        .map((row) => _buildInfoChip(row.namaKelas))
                        .toList(),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.menu_book_rounded, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Mata Pelajaran Diampu',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (taughtSubjects.isEmpty)
                  const Text('Belum ada jadwal mengajar pada tahun ajaran aktif.')
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: taughtSubjects
                        .map((row) => _buildInfoChip(row.namaMapel))
                        .toList(),
                  ),
                if (taughtClasses.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Kelas Diampu: ${taughtClasses.map((row) => row.namaKelas).join(', ')}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileSection(BuildContext context, SelfProfileState state) {
    final isSiswa = profileType == SelfProfileType.siswa;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isSiswa ? 'Profil Siswa' : 'Profil Guru',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (isSiswa) ...[
              _infoRow('NIS', state.siswaProfile?.nis ?? '-'),
              _infoRow('Gender', state.siswaProfile?.gender ?? '-'),
              _infoRow('Tempat Lahir', state.siswaProfile?.tempatLahir ?? '-'),
              _infoRow(
                'Tanggal Lahir',
                _formatDate(state.siswaProfile?.tanggalLahir),
              ),
              _infoRow('Alamat', state.siswaProfile?.alamat ?? '-'),
            ] else ...[
              _infoRow('NIP', state.guruProfile?.nip ?? '-'),
              _infoRow('NUPTK', state.guruProfile?.nuptk ?? '-'),
              _infoRow('Gender', state.guruProfile?.gender ?? '-'),
              _infoRow('Tempat Lahir', state.guruProfile?.tempatLahir ?? '-'),
              _infoRow(
                'Tanggal Lahir',
                _formatDate(state.guruProfile?.tanggalLahir),
              ),
              _infoRow('Golongan', state.guruProfile?.golongan ?? '-'),
              _infoRow('Alamat', state.guruProfile?.alamat ?? '-'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(value.isEmpty ? '-' : value)),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primary.withAlpha(40)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _identifierText(SelfProfileState state) {
    if (profileType == SelfProfileType.siswa) {
      final nis = state.siswaProfile?.nis;
      return (nis == null || nis.trim().isEmpty) ? 'NIS: -' : 'NIS: $nis';
    }

    final nip = state.guruProfile?.nip;
    if (nip != null && nip.trim().isNotEmpty) {
      return 'NIP: $nip';
    }

    final nuptk = state.guruProfile?.nuptk;
    if (nuptk != null && nuptk.trim().isNotEmpty) {
      return 'NUPTK: $nuptk';
    }

    return 'UID: $uid';
  }

  String _roleLabel(String rawRole) {
    return roleLabelValue(rawRole);
  }

  String _formatDate(DateTime? value) {
    if (value == null) {
      return '-';
    }
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) {
      return '-';
    }
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month/${value.year} $hour:$minute';
  }
}

class _EditSelfProfileScreen extends ConsumerStatefulWidget {
  final SelfProfileArgs args;
  final SelfProfileState initialState;

  const _EditSelfProfileScreen({
    required this.args,
    required this.initialState,
  });

  @override
  ConsumerState<_EditSelfProfileScreen> createState() =>
      _EditSelfProfileScreenState();
}

class _EditSelfProfileScreenState
    extends ConsumerState<_EditSelfProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _namaController;
  late final TextEditingController _uidController;
  late final TextEditingController _roleController;
  late final TextEditingController _emailController;
  late final TextEditingController _usernameController;
  late final TextEditingController _identifierController;
  late final TextEditingController _secondaryIdentifierController;
  late final TextEditingController _alamatController;
  late final TextEditingController _tempatLahirController;
  late final TextEditingController _golonganController;
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;

  String? _selectedGender;
  DateTime? _selectedTanggalLahir;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  bool get _isSiswa => widget.args.type == SelfProfileType.siswa;

  @override
  void initState() {
    super.initState();
    final user = widget.initialState.user;
    final guru = widget.initialState.guruProfile;
    final siswa = widget.initialState.siswaProfile;

    _namaController = TextEditingController(text: user?.nama ?? '');
    _uidController = TextEditingController(text: user?.uid ?? widget.args.uid);
    _roleController = TextEditingController(text: _roleLabel(widget.args.role));
    _emailController = TextEditingController(text: user?.email ?? '');
    _usernameController = TextEditingController(text: user?.username ?? '');
    _identifierController = TextEditingController(
      text: _isSiswa ? (siswa?.nis ?? '') : (guru?.nip ?? ''),
    );
    _secondaryIdentifierController = TextEditingController(
      text: _isSiswa ? '' : (guru?.nuptk ?? ''),
    );
    _alamatController = TextEditingController(
      text: _isSiswa ? (siswa?.alamat ?? '') : (guru?.alamat ?? ''),
    );
    _tempatLahirController = TextEditingController(
      text: _isSiswa ? (siswa?.tempatLahir ?? '') : (guru?.tempatLahir ?? ''),
    );
    _golonganController = TextEditingController(text: guru?.golongan ?? '');
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    _selectedGender = _isSiswa ? siswa?.gender : guru?.gender;
    _selectedTanggalLahir = _isSiswa ? siswa?.tanggalLahir : guru?.tanggalLahir;
  }

  @override
  void dispose() {
    _namaController.dispose();
    _uidController.dispose();
    _roleController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _identifierController.dispose();
    _secondaryIdentifierController.dispose();
    _alamatController.dispose();
    _tempatLahirController.dispose();
    _golonganController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(selfProfileProvider(widget.args));
    final notifier = ref.read(selfProfileProvider(widget.args).notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profil')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: AppColors.info.withAlpha(26),
              elevation: 0,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Field identitas utama seperti nama, UID, role, NIP/NUPTK/NIS bersifat read-only dan tidak dapat diubah.',
                  style: TextStyle(color: AppColors.info),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildSectionTitle('Data Read-only'),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _namaController,
              label: 'Nama',
              readOnly: true,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _uidController,
              label: 'UID',
              readOnly: true,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _roleController,
              label: 'Role',
              readOnly: true,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _identifierController,
              label: _isSiswa ? 'NIS' : 'NIP',
              readOnly: true,
            ),
            if (!_isSiswa) ...[
              const SizedBox(height: 12),
              _buildTextField(
                controller: _secondaryIdentifierController,
                label: 'NUPTK',
                readOnly: true,
              ),
            ],
            const SizedBox(height: 24),
            _buildSectionTitle('Data Akun'),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _emailController,
              label: 'Email',
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                final text = (value ?? '').trim();
                if (text.isEmpty) {
                  return 'Email wajib diisi';
                }
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
                  return 'Format email tidak valid';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _usernameController,
              label: 'Username',
              validator: (value) {
                final text = (value ?? '').trim();
                if (text.isEmpty) {
                  return null;
                }
                if (text.length < 3) {
                  return 'Username minimal 3 karakter';
                }
                if (!RegExp(r'^[A-Za-z0-9._]+$').hasMatch(text)) {
                  return 'Gunakan huruf, angka, titik, atau underscore';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            _buildSectionTitle(_isSiswa ? 'Profil Siswa' : 'Profil Guru'),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _alamatController,
              label: 'Alamat',
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue:
                  (_selectedGender == null || _selectedGender!.trim().isEmpty)
                  ? null
                  : _normalizeGender(_selectedGender!),
              decoration: _inputDecoration('Gender'),
              items: const [
                DropdownMenuItem(value: 'Laki-laki', child: Text('Laki-laki')),
                DropdownMenuItem(value: 'Perempuan', child: Text('Perempuan')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedGender = value;
                });
              },
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _tempatLahirController,
              label: 'Tempat Lahir',
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickTanggalLahir,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: _inputDecoration('Tanggal Lahir'),
                child: Text(
                  _selectedTanggalLahir == null
                      ? 'Pilih tanggal lahir'
                      : _formatDate(_selectedTanggalLahir),
                  style: TextStyle(
                    color: _selectedTanggalLahir == null
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            if (!_isSiswa) ...[
              const SizedBox(height: 12),
              _buildTextField(
                controller: _golonganController,
                label: 'Golongan',
              ),
            ],
            const SizedBox(height: 24),
            _buildSectionTitle('Ubah Password (Opsional)'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordController,
              obscureText: !_isPasswordVisible,
              decoration: _inputDecoration('Password Baru').copyWith(
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                ),
              ),
              validator: (value) {
                final text = (value ?? '').trim();
                if (text.isEmpty) {
                  return null;
                }
                if (text.length < 6) {
                  return 'Password minimal 6 karakter';
                }
                if (text.contains(RegExp(r'\s'))) {
                  return 'Password tidak boleh mengandung spasi';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: !_isConfirmPasswordVisible,
              decoration: _inputDecoration('Konfirmasi Password Baru').copyWith(
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                    });
                  },
                  icon: Icon(
                    _isConfirmPasswordVisible
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                ),
              ),
              validator: (value) {
                final password = _passwordController.text.trim();
                final confirmation = (value ?? '').trim();
                if (password.isEmpty && confirmation.isEmpty) {
                  return null;
                }
                if (password.isEmpty) {
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
            const SizedBox(height: 28),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: state.isSaving ? null : () => _saveProfile(notifier),
                child: state.isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Simpan'),
              ),
            ),
            if (state.error != null && state.error!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                state.error!,
                style: const TextStyle(color: AppColors.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _saveProfile(SelfProfileNotifier notifier) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final password = _passwordController.text.trim();

    try {
      if (_isSiswa) {
        await notifier.updateSiswaProfile(
          email: _emailController.text.trim(),
          username: _usernameController.text.trim(),
          alamat: _alamatController.text.trim(),
          gender: (_selectedGender ?? '').trim(),
          tempatLahir: _tempatLahirController.text.trim(),
          tanggalLahir: _selectedTanggalLahir,
          password: password,
        );
      } else {
        await notifier.updateStaffProfile(
          email: _emailController.text.trim(),
          username: _usernameController.text.trim(),
          alamat: _alamatController.text.trim(),
          gender: (_selectedGender ?? '').trim(),
          tempatLahir: _tempatLahirController.text.trim(),
          tanggalLahir: _selectedTanggalLahir,
          golongan: _golonganController.text.trim(),
          password: password,
        );
      }

      notifier.finishSaving();

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(
        _SelfProfileSaveResult(passwordChanged: password.isNotEmpty),
      );
    } catch (_) {
      notifier.finishSaving();
    }
  }

  Future<void> _pickTanggalLahir() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedTanggalLahir ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      locale: const Locale('id', 'ID'),
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _selectedTanggalLahir = DateTime(picked.year, picked.month, picked.day);
    });
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool readOnly = false,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: _inputDecoration(label).copyWith(
        fillColor: readOnly
            ? Colors.grey.shade100
            : AppColors.primary.withAlpha(13),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: AppColors.primary.withAlpha(13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
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
    );
  }

  String _roleLabel(String rawRole) {
    return roleLabelValue(rawRole);
  }

  String _normalizeGender(String value) {
    final raw = value.trim().toLowerCase();
    if (raw == 'p' || raw == 'perempuan' || raw == 'wanita') {
      return 'Perempuan';
    }
    if (raw == 'l' ||
        raw == 'laki laki' ||
        raw == 'laki-laki' ||
        raw == 'pria') {
      return 'Laki-laki';
    }
    return value;
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

class _SelfProfileSaveResult {
  final bool passwordChanged;

  const _SelfProfileSaveResult({required this.passwordChanged});
}
