import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../core/services/app_metrics.dart';
import '../../../../../core/widgets/app_external_filter_bar.dart';
import '../../../kepala_sekolah/widgets/app_alert.dart';
import '../../providers/manajemen_siswa_bk_supabase_provider.dart';

class ManajemenAkunSiswaScreen extends ConsumerStatefulWidget {
  const ManajemenAkunSiswaScreen({super.key});

  @override
  ConsumerState<ManajemenAkunSiswaScreen> createState() =>
      _ManajemenAkunSiswaScreenState();
}

class _ManajemenAkunSiswaScreenState
    extends ConsumerState<ManajemenAkunSiswaScreen> {
  static const bool _allowEditNis = true;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _selectedStatus = bkSiswaFilterSemua;
  bool _isFilterVisible = true;
  Timer? _searchDebounce;
  final PerfTimer _screenTimer = PerfTimer('manajemen_akun_siswa_screen');
  bool _hasRecordedScreenLoad = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
    Future.microtask(_loadData);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    await ref
        .read(manajemenSiswaBkProvider.notifier)
        .getSiswa(
          status: _selectedStatus,
          searchQuery: _searchController.text,
          forceRefresh: forceRefresh,
        );
    if (!_hasRecordedScreenLoad && mounted) {
      _hasRecordedScreenLoad = true;
      AppMetrics().recordScreenLoad(
        'manajemen_akun_siswa',
        _screenTimer.elapsed,
      );
    }
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) {
        return;
      }
      _loadData();
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels + 320 < position.maxScrollExtent) {
      return;
    }

    ref.read(manajemenSiswaBkProvider.notifier).loadMoreSiswa();
  }

  Future<void> _showSiswaFormDialog({BkSiswaItem? item}) async {
    final isEdit = item != null;
    if (isEdit) {
      await _showEditSiswaFormDialog(item);
      return;
    }

    final formKey = GlobalKey<FormState>();
    final namaController = TextEditingController();
    final emailController = TextEditingController();
    final usernameController = TextEditingController();
    final nisController = TextEditingController();
    final passwordController = TextEditingController();
    final noHpController = TextEditingController();
    final tempatLahirController = TextEditingController();
    final alamatController = TextEditingController();

    String? selectedGender;
    DateTime? selectedTanggalLahir;
    var isPasswordVisible = false;

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final screenSize = MediaQuery.sizeOf(dialogContext);
            final dialogWidth = screenSize.width > 1200
                ? 980.0
                : screenSize.width > 900
                ? 920.0
                : screenSize.width > 640
                ? 760.0
                : screenSize.width * 0.96;

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: dialogWidth,
                  maxHeight: screenSize.height * 0.92,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.primary.withAlpha(26)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x26000000),
                        blurRadius: 30,
                        offset: Offset(0, 18),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary.withAlpha(20),
                                AppColors.accent.withAlpha(14),
                                Colors.white,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppColors.primary.withAlpha(32),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.person_add_alt_rounded,
                                  color: AppColors.primary,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Tambah Siswa',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    SizedBox(height: 6),
                                    Text(
                                      'Lengkapi data akun siswa untuk membuat akun baru.',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        height: 1.45,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          height: 1,
                          color: AppColors.divider.withAlpha(120),
                        ),
                        Flexible(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
                            child: Form(
                              key: formKey,
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final isWide = constraints.maxWidth >= 760;

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _buildDialogSectionHeader(
                                        title: 'Informasi Akun',
                                        subtitle:
                                            'Data utama untuk login dan identitas akun siswa.',
                                      ),
                                      const SizedBox(height: 14),
                                      _buildResponsiveFieldPair(
                                        isWide: isWide,
                                        first: _buildModernTextField(
                                          controller: emailController,
                                          label: 'Email',
                                          hint: 'Contoh: siswa@sekolah.sch.id',
                                          icon: Icons.email_outlined,
                                          keyboardType:
                                              TextInputType.emailAddress,
                                          validator: (value) {
                                            final text = (value ?? '').trim();
                                            if (text.isEmpty) {
                                              return 'Email wajib diisi';
                                            }
                                            if (!RegExp(
                                              r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                            ).hasMatch(text)) {
                                              return 'Format email tidak valid';
                                            }
                                            return null;
                                          },
                                        ),
                                        second: _buildModernTextField(
                                          controller: usernameController,
                                          label: 'Username',
                                          hint: 'Contoh: nama.user atau nis',
                                          icon: Icons.alternate_email_rounded,
                                          validator: (value) {
                                            final text = (value ?? '').trim();
                                            if (text.isEmpty) {
                                              return 'Username wajib diisi';
                                            }
                                            if (text.length < 3) {
                                              return 'Username minimal 3 karakter';
                                            }
                                            if (!RegExp(
                                              r'^[a-z0-9._]+$',
                                            ).hasMatch(text)) {
                                              return 'Username hanya boleh huruf kecil, angka, titik, dan underscore';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      _buildModernPasswordField(
                                        controller: passwordController,
                                        label: 'Password',
                                        hint: 'Minimal 6 karakter',
                                        isVisible: isPasswordVisible,
                                        onToggleVisibility: () {
                                          setStateDialog(() {
                                            isPasswordVisible =
                                                !isPasswordVisible;
                                          });
                                        },
                                        validator: (value) {
                                          final text = (value ?? '').trim();
                                          if (text.isEmpty) {
                                            return 'Password wajib diisi';
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
                                      const SizedBox(height: 22),
                                      _buildDialogSectionHeader(
                                        title: 'Informasi Pribadi',
                                        subtitle:
                                            'Data profil siswa untuk melengkapi identitas siswa.',
                                      ),
                                      const SizedBox(height: 14),
                                      _buildResponsiveFieldPair(
                                        isWide: isWide,
                                        first: _buildModernTextField(
                                          controller: namaController,
                                          label: 'Nama Lengkap',
                                          hint: 'Contoh: Ahmad Rizky Pratama',
                                          icon: Icons.person_outline_rounded,
                                          validator: (value) {
                                            final text = (value ?? '').trim();
                                            if (text.isEmpty) {
                                              return 'Nama siswa wajib diisi';
                                            }
                                            return null;
                                          },
                                        ),
                                        second: _buildModernTextField(
                                          controller: nisController,
                                          label: 'NIS',
                                          hint: 'Nomor induk siswa',
                                          icon: Icons
                                              .confirmation_number_outlined,
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [
                                            FilteringTextInputFormatter
                                                .digitsOnly,
                                          ],
                                          validator: (value) {
                                            final text = (value ?? '').trim();
                                            if (text.isEmpty) {
                                              return 'NIS wajib diisi';
                                            }
                                            if (!RegExp(
                                              r'^\d+$',
                                            ).hasMatch(text)) {
                                              return 'NIS harus berupa angka';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      _buildResponsiveFieldPair(
                                        isWide: isWide,
                                        first: _buildModernTextField(
                                          controller: tempatLahirController,
                                          label: 'Tempat Lahir',
                                          optional: true,
                                          hint: 'Contoh: Jenar',
                                          icon: Icons.location_city_outlined,
                                          keyboardType: TextInputType.name,
                                          inputFormatters: [
                                            FilteringTextInputFormatter.deny(
                                              RegExp(r'\d'),
                                            ),
                                          ],
                                          validator: (value) {
                                            final text = (value ?? '').trim();
                                            if (text.isEmpty) {
                                              return null;
                                            }
                                            if (RegExp(r'\d').hasMatch(text)) {
                                              return 'Tempat lahir harus berupa teks';
                                            }
                                            return null;
                                          },
                                        ),
                                        second: _buildModernDropdownField(
                                          value: selectedGender,
                                          label: 'Jenis Kelamin',
                                          optional: true,
                                          hint: 'Pilih jenis kelamin',
                                          icon: Icons.wc_rounded,
                                          items: const [
                                            DropdownMenuItem(
                                              value: 'Laki-laki',
                                              child: Text('Laki-laki'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'Perempuan',
                                              child: Text('Perempuan'),
                                            ),
                                          ],
                                          onChanged: (value) {
                                            setStateDialog(() {
                                              selectedGender = value;
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      _buildResponsiveFieldPair(
                                        isWide: isWide,
                                        first: _buildModernDateField(
                                          label: 'Tanggal Lahir',
                                          optional: true,
                                          hint: 'Pilih tanggal lahir',
                                          value: selectedTanggalLahir,
                                          icon: Icons.cake_outlined,
                                          onTap: () async {
                                            final picked = await showDatePicker(
                                              context: dialogContext,
                                              initialDate:
                                                  selectedTanggalLahir ??
                                                  DateTime(2010, 1, 1),
                                              firstDate: DateTime(1990),
                                              lastDate: DateTime.now(),
                                              locale: const Locale('id', 'ID'),
                                            );
                                            if (picked == null) {
                                              return;
                                            }
                                            setStateDialog(() {
                                              selectedTanggalLahir = DateTime(
                                                picked.year,
                                                picked.month,
                                                picked.day,
                                              );
                                            });
                                          },
                                          formatDate: _formatDate,
                                        ),
                                        second: _buildModernTextField(
                                          controller: noHpController,
                                          label: 'No HP',
                                          optional: true,
                                          hint: 'Contoh: 08xxxxxxxxxx',
                                          icon: Icons.phone_rounded,
                                          keyboardType: TextInputType.phone,
                                          inputFormatters: [
                                            FilteringTextInputFormatter
                                                .digitsOnly,
                                          ],
                                          validator: (value) {
                                            final text = (value ?? '').trim();
                                            if (text.isEmpty) {
                                              return null;
                                            }
                                            if (!RegExp(
                                              r'^\d+$',
                                            ).hasMatch(text)) {
                                              return 'No HP harus berupa angka';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      _buildModernTextField(
                                        controller: alamatController,
                                        label: 'Alamat',
                                        optional: true,
                                        hint: 'Tulis alamat domisili siswa',
                                        icon: Icons.location_on_outlined,
                                        maxLines: 3,
                                        minLines: 3,
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border(
                              top: BorderSide(
                                color: AppColors.divider.withAlpha(110),
                              ),
                            ),
                          ),
                          padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final isWideActions = constraints.maxWidth >= 520;

                              final cancelButton = OutlinedButton(
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(false),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.textSecondary,
                                  side: BorderSide(
                                    color: AppColors.primary.withAlpha(60),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 22,
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text('Batal'),
                              );

                              final saveButton = ElevatedButton.icon(
                                onPressed: () {
                                  FocusScope.of(dialogContext).unfocus();
                                  if (!formKey.currentState!.validate()) {
                                    return;
                                  }
                                  Navigator.of(dialogContext).pop(true);
                                },
                                icon: const Icon(Icons.save_rounded, size: 18),
                                label: const Text('Simpan'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 14,
                                  ),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              );

                              if (!isWideActions) {
                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    saveButton,
                                    const SizedBox(height: 10),
                                    cancelButton,
                                  ],
                                );
                              }

                              return Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  cancelButton,
                                  const SizedBox(width: 12),
                                  saveButton,
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    final nama = namaController.text.trim();
    final email = emailController.text.trim();
    final username = usernameController.text.trim();
    final nis = nisController.text.trim();
    final password = passwordController.text.trim();
    final noHp = noHpController.text.trim();
    final tempatLahir = tempatLahirController.text.trim();
    final alamat = alamatController.text.trim();

    namaController.dispose();
    emailController.dispose();
    usernameController.dispose();
    nisController.dispose();
    passwordController.dispose();
    noHpController.dispose();
    tempatLahirController.dispose();
    alamatController.dispose();

    if (shouldSave != true) {
      return;
    }

    if (!mounted) {
      return;
    }

    try {
      final result = await ref
          .read(manajemenSiswaBkProvider.notifier)
          .createSiswa(
            nama: nama,
            email: email,
            username: username.isEmpty ? null : username,
            nis: nis.isEmpty ? null : nis,
            password: password,
            noHp: noHp.isEmpty ? null : noHp,
            tempatLahir: tempatLahir.isEmpty ? null : tempatLahir,
            alamat: alamat.isEmpty ? null : alamat,
            jenisKelamin: selectedGender,
            tanggalLahir: selectedTanggalLahir,
            statusAfterOperation: _selectedStatus,
          );

      if (!mounted) {
        return;
      }

      await AppAlert.success(
        context,
        title: 'Berhasil',
        message:
            'Akun siswa berhasil dibuat.\nUID: ${result.uid}\nUsername: ${result.username}',
        autoClose: true,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      await AppAlert.error(context, message: 'Gagal menyimpan siswa: $e');
    }
  }

  Future<void> _showEditSiswaFormDialog(BkSiswaItem item) async {
    _showLoadingDialog();
    BkSiswaEditFormData editData;
    try {
      editData = await ref
          .read(manajemenSiswaBkProvider.notifier)
          .getSiswaEditFormData(item.id, forceRefresh: true);
    } catch (e) {
      if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (!mounted) {
        return;
      }
      await AppAlert.error(context, message: 'Gagal memuat data siswa: $e');
      return;
    }

    if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    if (!mounted) {
      return;
    }

    final result = await _showEditSiswaDialog(editData);
    if (result == null) {
      return;
    }

    try {
      await ref
          .read(manajemenSiswaBkProvider.notifier)
          .updateSiswa(
            userDocId: item.id,
            nama: result.nama,
            email: result.email,
            username: result.username,
            nis: result.nis,
            noHp: result.noHp,
            tempatLahir: result.tempatLahir,
            jenisKelamin: result.jenisKelamin,
            tanggalLahir: result.tanggalLahir,
            alamat: result.alamat,
            password: result.password,
            statusAfterOperation: _selectedStatus,
          );

      if (!mounted) {
        return;
      }

      await AppAlert.success(
        context,
        title: 'Berhasil',
        message: result.password.isNotEmpty
            ? 'Data dan password berhasil diperbarui.'
            : 'Data berhasil diperbarui.',
        autoClose: true,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      await AppAlert.error(context, message: 'Gagal menyimpan siswa: $e');
    }
  }

  Future<_SiswaEditFormResult?> _showEditSiswaDialog(
    BkSiswaEditFormData editData,
  ) {
    final user = editData.user;
    final profile = editData.profile;
    final formKey = GlobalKey<FormState>();

    final namaController = TextEditingController(text: user.nama);
    final emailController = TextEditingController(text: user.email);
    final usernameController = TextEditingController(text: user.username ?? '');
    final nisController = TextEditingController(text: profile?.nis ?? '');
    final tempatLahirController = TextEditingController(
      text: profile?.tempatLahir ?? '',
    );
    final noHpController = TextEditingController(text: profile?.noHp ?? '');
    final alamatController = TextEditingController(text: profile?.alamat ?? '');
    final passwordController = TextEditingController();
    String? selectedGender = _normalizeGender(profile?.gender);
    DateTime? selectedTanggalLahir = _normalizeDate(profile?.tanggalLahir);
    var isPasswordVisible = false;

    return showDialog<_SiswaEditFormResult>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final screenSize = MediaQuery.sizeOf(dialogContext);
            final dialogWidth = screenSize.width > 1200
                ? 980.0
                : screenSize.width > 900
                ? 920.0
                : screenSize.width > 640
                ? 760.0
                : screenSize.width * 0.96;

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: dialogWidth,
                  maxHeight: screenSize.height * 0.92,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.primary.withAlpha(26)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x26000000),
                        blurRadius: 30,
                        offset: Offset(0, 18),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary.withAlpha(20),
                                AppColors.accent.withAlpha(14),
                                Colors.white,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppColors.primary.withAlpha(32),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.manage_accounts_rounded,
                                  color: AppColors.primary,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Edit Siswa',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    SizedBox(height: 6),
                                    Text(
                                      'Perbarui data akun dan profil siswa yang tersimpan.',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        height: 1.45,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          height: 1,
                          color: AppColors.divider.withAlpha(120),
                        ),
                        Flexible(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
                            child: Form(
                              key: formKey,
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final isWide = constraints.maxWidth >= 760;

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _buildDialogSectionHeader(
                                        title: 'Informasi Akun',
                                        subtitle:
                                            'Data utama milik tabel user dan pengaturan login siswa.',
                                      ),
                                      const SizedBox(height: 14),
                                      _buildResponsiveFieldPair(
                                        isWide: isWide,
                                        first: _buildModernTextField(
                                          controller: emailController,
                                          label: 'Email',
                                          hint: 'Email akun siswa',
                                          icon: Icons.email_outlined,
                                          keyboardType:
                                              TextInputType.emailAddress,
                                          readOnly: true,
                                          helperText:
                                              'Email tidak dapat diubah',
                                        ),
                                        second: _buildModernTextField(
                                          controller: usernameController,
                                          label: 'Username',
                                          hint: 'Username login',
                                          icon: Icons.alternate_email_rounded,
                                          validator: (value) {
                                            final text = (value ?? '').trim();
                                            if (text.isEmpty) {
                                              return 'Username wajib diisi';
                                            }
                                            if (text.length < 3) {
                                              return 'Username minimal 3 karakter';
                                            }
                                            if (!RegExp(
                                              r'^[a-z0-9._]+$',
                                            ).hasMatch(text)) {
                                              return 'Username hanya boleh huruf kecil, angka, titik, dan underscore';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      _buildModernPasswordField(
                                        controller: passwordController,
                                        label: 'Password Baru',
                                        hint: 'Kosongkan jika tidak diubah',
                                        isVisible: isPasswordVisible,
                                        onToggleVisibility: () {
                                          setStateDialog(() {
                                            isPasswordVisible =
                                                !isPasswordVisible;
                                          });
                                        },
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
                                      const SizedBox(height: 22),
                                      _buildDialogSectionHeader(
                                        title: 'Informasi Pribadi',
                                        subtitle:
                                            'Data profil siswa untuk tabel siswa.',
                                      ),
                                      const SizedBox(height: 14),
                                      _buildResponsiveFieldPair(
                                        isWide: isWide,
                                        first: _buildModernTextField(
                                          controller: namaController,
                                          label: 'Nama Lengkap',
                                          hint: 'Nama siswa',
                                          icon: Icons.person_outline_rounded,
                                          validator: (value) {
                                            final text = (value ?? '').trim();
                                            if (text.isEmpty) {
                                              return 'Nama siswa wajib diisi';
                                            }
                                            return null;
                                          },
                                        ),
                                        second: _buildModernTextField(
                                          controller: nisController,
                                          label: 'NIS',
                                          optional: false,
                                          hint: 'Nomor induk siswa',
                                          icon: Icons
                                              .confirmation_number_outlined,
                                          readOnly: !_allowEditNis,
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [
                                            FilteringTextInputFormatter
                                                .digitsOnly,
                                          ],
                                          validator: (value) {
                                            final text = (value ?? '').trim();
                                            if (text.isEmpty) {
                                              return 'NIS wajib diisi';
                                            }
                                            if (!RegExp(
                                              r'^\d+$',
                                            ).hasMatch(text)) {
                                              return 'NIS harus berupa angka';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      _buildResponsiveFieldPair(
                                        isWide: isWide,
                                        first: _buildModernTextField(
                                          controller: tempatLahirController,
                                          label: 'Tempat Lahir',
                                          optional: true,
                                          hint: 'Tempat lahir siswa',
                                          icon: Icons.location_city_outlined,
                                          keyboardType: TextInputType.name,
                                          inputFormatters: [
                                            FilteringTextInputFormatter.deny(
                                              RegExp(r'\d'),
                                            ),
                                          ],
                                          validator: (value) {
                                            final text = (value ?? '').trim();
                                            if (text.isEmpty) {
                                              return null;
                                            }
                                            if (RegExp(r'\d').hasMatch(text)) {
                                              return 'Tempat lahir harus berupa teks';
                                            }
                                            return null;
                                          },
                                        ),
                                        second: _buildModernDropdownField(
                                          value: selectedGender,
                                          label: 'Jenis Kelamin',
                                          optional: true,
                                          hint: 'Pilih jenis kelamin',
                                          icon: Icons.wc_rounded,
                                          items: const [
                                            DropdownMenuItem(
                                              value: 'Laki-laki',
                                              child: Text('Laki-laki'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'Perempuan',
                                              child: Text('Perempuan'),
                                            ),
                                          ],
                                          onChanged: (value) {
                                            setStateDialog(() {
                                              selectedGender = value;
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      _buildResponsiveFieldPair(
                                        isWide: isWide,
                                        first: _buildModernDateField(
                                          label: 'Tanggal Lahir',
                                          optional: true,
                                          hint: 'Pilih tanggal lahir',
                                          value: selectedTanggalLahir,
                                          icon: Icons.cake_outlined,
                                          onTap: () async {
                                            final picked = await showDatePicker(
                                              context: dialogContext,
                                              initialDate:
                                                  selectedTanggalLahir ??
                                                  DateTime(2010, 1, 1),
                                              firstDate: DateTime(1990),
                                              lastDate: DateTime.now(),
                                              locale: const Locale('id', 'ID'),
                                            );
                                            if (picked == null) {
                                              return;
                                            }
                                            setStateDialog(() {
                                              selectedTanggalLahir = DateTime(
                                                picked.year,
                                                picked.month,
                                                picked.day,
                                              );
                                            });
                                          },
                                          formatDate: _formatDate,
                                        ),
                                        second: _buildModernTextField(
                                          controller: noHpController,
                                          label: 'No HP',
                                          optional: true,
                                          hint: 'Contoh: 08xxxxxxxxxx',
                                          icon: Icons.phone_rounded,
                                          keyboardType: TextInputType.phone,
                                          inputFormatters: [
                                            FilteringTextInputFormatter
                                                .digitsOnly,
                                          ],
                                          validator: (value) {
                                            final text = (value ?? '').trim();
                                            if (text.isEmpty) {
                                              return null;
                                            }
                                            if (!RegExp(
                                              r'^\d+$',
                                            ).hasMatch(text)) {
                                              return 'No HP harus berupa angka';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      _buildModernTextField(
                                        controller: alamatController,
                                        label: 'Alamat',
                                        optional: true,
                                        hint: 'Alamat domisili siswa',
                                        icon: Icons.location_on_outlined,
                                        maxLines: 3,
                                        minLines: 3,
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border(
                              top: BorderSide(
                                color: AppColors.divider.withAlpha(110),
                              ),
                            ),
                          ),
                          padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final isWideActions = constraints.maxWidth >= 520;

                              final cancelButton = OutlinedButton(
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.textSecondary,
                                  side: BorderSide(
                                    color: AppColors.primary.withAlpha(60),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 22,
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text('Batal'),
                              );

                              final saveButton = ElevatedButton.icon(
                                onPressed: () {
                                  FocusScope.of(dialogContext).unfocus();
                                  if (!formKey.currentState!.validate()) {
                                    return;
                                  }
                                  Navigator.of(dialogContext).pop(
                                    _SiswaEditFormResult(
                                      nama: namaController.text.trim(),
                                      email: emailController.text.trim(),
                                      username: usernameController.text.trim(),
                                      nis: nisController.text.trim(),
                                      tempatLahir: tempatLahirController.text
                                          .trim(),
                                      jenisKelamin: selectedGender,
                                      tanggalLahir: selectedTanggalLahir,
                                      noHp: noHpController.text.trim(),
                                      alamat: alamatController.text.trim(),
                                      password: passwordController.text.trim(),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.save_rounded, size: 18),
                                label: const Text('Simpan'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 14,
                                  ),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              );

                              if (!isWideActions) {
                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    saveButton,
                                    const SizedBox(height: 10),
                                    cancelButton,
                                  ],
                                );
                              }

                              return Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  cancelButton,
                                  const SizedBox(width: 12),
                                  saveButton,
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      emailController.dispose();
      usernameController.dispose();
      nisController.dispose();
      namaController.dispose();
      tempatLahirController.dispose();
      noHpController.dispose();
      alamatController.dispose();
      passwordController.dispose();
    });
  }

  void _showLoadingDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return const AlertDialog(
          content: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              SizedBox(width: 16),
              Expanded(child: Text('Memuat data siswa...')),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }

  DateTime? _normalizeDate(DateTime? value) {
    if (value == null) {
      return null;
    }
    return DateTime(value.year, value.month, value.day);
  }

  String? _normalizeGender(String? raw) {
    if (raw == null) {
      return null;
    }
    final value = raw.trim().toLowerCase();
    if (value.isEmpty) {
      return null;
    }
    if (value == 'p' || value == 'perempuan' || value == 'wanita') {
      return 'Perempuan';
    }
    if (value == 'l' ||
        value == 'laki-laki' ||
        value == 'laki laki' ||
        value == 'pria') {
      return 'Laki-laki';
    }
    return null;
  }

  Widget _buildDialogSectionHeader({
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12.8,
            height: 1.45,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildResponsiveFieldPair({
    required bool isWide,
    required Widget first,
    required Widget second,
  }) {
    if (!isWide) {
      return Column(children: [first, const SizedBox(height: 14), second]);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: first),
        const SizedBox(width: 16),
        Expanded(child: second),
      ],
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? helperText,
    bool optional = false,
    IconData? icon,
    TextInputType? keyboardType,
    int? maxLines,
    int? minLines,
    bool readOnly = false,
    ValueChanged<String>? onChanged,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      minLines: minLines,
      readOnly: readOnly,
      onChanged: onChanged,
      inputFormatters: inputFormatters,
      style: const TextStyle(fontSize: 14.5),
      decoration: _buildModernInputDecoration(
        label: label,
        optional: optional,
        hint: hint,
        helperText: helperText,
        icon: icon,
      ),
      validator: validator,
    );
  }

  Widget _buildModernPasswordField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool isVisible,
    required VoidCallback onToggleVisibility,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: !isVisible,
      style: const TextStyle(fontSize: 14.5),
      decoration: _buildModernInputDecoration(
        label: label,
        hint: hint,
        icon: Icons.lock_outline_rounded,
        suffixIcon: IconButton(
          onPressed: onToggleVisibility,
          icon: Icon(
            isVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
          ),
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildModernDropdownField({
    required String? value,
    required String label,
    required String hint,
    required IconData icon,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
    bool optional = false,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: _buildModernInputDecoration(
        label: label,
        optional: optional,
        hint: hint,
        icon: icon,
      ),
      icon: const Icon(Icons.keyboard_arrow_down_rounded),
      items: items,
      onChanged: onChanged,
    );
  }

  Widget _buildModernDateField({
    required String label,
    required String hint,
    required DateTime? value,
    required IconData icon,
    required VoidCallback onTap,
    required String Function(DateTime) formatDate,
    bool optional = false,
  }) {
    final hasValue = value != null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: InputDecorator(
        decoration: _buildModernInputDecoration(
          label: label,
          optional: optional,
          hint: hint,
          icon: icon,
          suffixIcon: const Icon(Icons.date_range_rounded),
          floatingLabelBehavior: FloatingLabelBehavior.always,
        ),
        isEmpty: !hasValue,
        child: Text(
          hasValue ? formatDate(value) : hint,
          style: TextStyle(
            fontSize: 14.5,
            color: hasValue ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  InputDecoration _buildModernInputDecoration({
    required String label,
    String? hint,
    String? helperText,
    bool optional = false,
    IconData? icon,
    Widget? suffixIcon,
    bool showLabel = true,
    FloatingLabelBehavior? floatingLabelBehavior,
  }) {
    return InputDecoration(
      label: showLabel ? _FieldLabel(text: label, optional: optional) : null,
      floatingLabelBehavior: floatingLabelBehavior,
      hintText: hint,
      helperText: helperText,
      prefixIcon: icon == null ? null : Icon(icon),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.primary.withAlpha(26)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.divider.withAlpha(180)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.error, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.error, width: 1.6),
      ),
      hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
      helperStyle: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 12,
      ),
    );
  }

  Future<void> _showStatusDialog(BkSiswaItem item) async {
    String selectedStatus = normalizeBkSiswaStatus(
      item.status,
      activeHint: item.active,
    );
    final catatanController = TextEditingController();

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text('Ubah Status ${item.nama}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedStatus,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: bkSiswaStatusAktif,
                        child: Text('Aktif'),
                      ),
                      DropdownMenuItem(
                        value: bkSiswaStatusNonaktif,
                        child: Text('Nonaktif'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setStateDialog(() {
                        selectedStatus = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: catatanController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Catatan',
                      hintText: 'Opsional',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );

    if (shouldSave != true) {
      catatanController.dispose();
      return;
    }

    if (!mounted) {
      catatanController.dispose();
      return;
    }

    final confirmed = await AppAlert.confirm(
      context,
      message:
          'Yakin menandai siswa sebagai ${bkSiswaStatusLabel(selectedStatus)}?',
      okText: 'Ya, ubah status',
      cancelText: 'Batal',
    );

    if (!confirmed) {
      catatanController.dispose();
      return;
    }

    try {
      await ref
          .read(manajemenSiswaBkProvider.notifier)
          .ubahStatusSiswa(
            userDocId: item.id,
            selectedStatus: selectedStatus,
            catatan: catatanController.text.trim(),
            statusAfterOperation: _selectedStatus,
          );

      catatanController.dispose();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Status siswa berhasil diperbarui.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      debugPrint('Gagal memperbarui status siswa: $e');
      catatanController.dispose();
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal memperbarui status siswa.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _confirmDelete(BkSiswaItem item) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Hapus Siswa'),
          content: Text(
            'Soft delete akun ${item.nama}?\nData histori tetap aman.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      await ref
          .read(manajemenSiswaBkProvider.notifier)
          .softDeleteSiswa(
            userDocId: item.id,
            statusAfterOperation: _selectedStatus,
          );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Siswa berhasil dihapus (soft delete).'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menghapus siswa: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(manajemenSiswaBkProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Akun Siswa'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: state.isLoading
                ? null
                : () => _loadData(forceRefresh: true),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadData(forceRefresh: true),
        child: ListView.builder(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: _buildItemCount(state),
          itemBuilder: (context, index) =>
              _buildListItem(context, state, index),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSiswaFormDialog(),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Tambah Siswa'),
      ),
    );
  }

  int _buildItemCount(ManajemenSiswaBkState state) {
    if (state.isLoading && state.data.isEmpty) {
      return 2;
    }
    if (state.data.isEmpty) {
      return 2;
    }
    return 1 +
        state.data.length +
        (state.isLoadingMore || state.hasMore ? 1 : 0);
  }

  Widget _buildListItem(
    BuildContext context,
    ManajemenSiswaBkState state,
    int index,
  ) {
    if (index == 0) {
      return AppExternalFilterBar(
        isExpanded: _isFilterVisible,
        onToggle: () {
          setState(() {
            _isFilterVisible = !_isFilterVisible;
          });
        },
        onReset: () async {
          _searchDebounce?.cancel();
          _searchController.clear();
          setState(() {
            _selectedStatus = bkSiswaFilterSemua;
          });
          await _loadData();
        },
        onApply: () => _loadData(),
        isBusy: state.isLoading,
        children: [
          AppExternalFilterField(
            label: 'Nama',
            child: TextField(
              controller: _searchController,
              decoration: appExternalFilterDecoration(
                hintText: 'Cari nama, uid, email, username...',
                icon: Icons.search_rounded,
              ),
            ),
          ),
          AppExternalFilterField(
            label: 'Status',
            child: DropdownButtonFormField<String>(
              initialValue: _selectedStatus,
              decoration: appExternalFilterDecoration(
                hintText: 'Pilih status',
                icon: Icons.filter_alt_rounded,
              ),
              items: const [
                DropdownMenuItem(
                  value: bkSiswaFilterSemua,
                  child: Text('Semua'),
                ),
                DropdownMenuItem(
                  value: bkSiswaStatusAktif,
                  child: Text('Aktif'),
                ),
                DropdownMenuItem(
                  value: bkSiswaStatusNonaktif,
                  child: Text('Nonaktif'),
                ),
              ],
              onChanged: (value) async {
                if (value == null) {
                  return;
                }
                setState(() {
                  _selectedStatus = value;
                });
                await _loadData();
              },
            ),
          ),
        ],
      );
    }

    if (state.data.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 96),
        child: Column(
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Text('Tidak ada data siswa', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    final rowIndex = index - 1;
    if (rowIndex >= 0 && rowIndex < state.data.length) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          rowIndex == 0 ? 16 : 0,
          16,
          rowIndex == state.data.length - 1 ? 16 : 10,
        ),
        child: _buildSiswaCard(state.data[rowIndex]),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Center(
        child: state.isLoadingMore
            ? const CircularProgressIndicator()
            : state.hasMore
            ? const SizedBox.shrink()
            : const Text(
                'Semua data siswa sudah dimuat',
                style: TextStyle(color: Colors.grey),
              ),
      ),
    );
  }

  Widget _buildSiswaCard(BkSiswaItem item) {
    final status = normalizeBkSiswaStatus(
      item.status,
      activeHint: item.active,
    );
    final statusStyle = _statusStyle(status);

    return Card(
      key: ValueKey(item.id),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: statusStyle.$2.withAlpha(30),
          child: Icon(statusStyle.$1, color: statusStyle.$2),
        ),
        title: Text(
          item.nama,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('UID: ${item.uid}'),
            if (item.nis != null && item.nis!.trim().isNotEmpty)
              Text('NIS: ${item.nis}'),
            Text(item.email),
            if (item.username != null && item.username!.trim().isNotEmpty)
              Text('Username: ${item.username}'),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusStyle.$2.withAlpha(24),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                bkSiswaStatusLabel(status),
                style: TextStyle(
                  fontSize: 11,
                  color: statusStyle.$2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => _showStatusDialog(item),
                icon: const Icon(Icons.swap_horiz),
                label: const Text('Ubah Status'),
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'edit') {
              await _showSiswaFormDialog(item: item);
              return;
            }
            if (value == 'toggle') {
              await _showStatusDialog(item);
              return;
            }
            if (value == 'delete') {
              await _confirmDelete(item);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit Data')),
            PopupMenuItem(value: 'toggle', child: const Text('Ubah Status')),
            const PopupMenuItem(value: 'delete', child: Text('Soft Delete')),
          ],
        ),
      ),
    );
  }

  (IconData, Color) _statusStyle(String status) {
    switch (normalizeBkSiswaStatus(status)) {
      case bkSiswaStatusAktif:
        return (Icons.person, AppColors.success);
      case bkSiswaStatusNonaktif:
        return (Icons.person_off, AppColors.error);
      default:
        return (Icons.person, AppColors.success);
    }
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  final bool optional;

  const _FieldLabel({required this.text, this.optional = false});

  @override
  Widget build(BuildContext context) {
    if (!optional) {
      return Text(text);
    }

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: text),
          const TextSpan(text: '  '),
          TextSpan(
            text: 'Opsional',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary.withAlpha(200),
            ),
          ),
        ],
      ),
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _SiswaEditFormResult {
  final String nama;
  final String email;
  final String username;
  final String nis;
  final String tempatLahir;
  final String? jenisKelamin;
  final DateTime? tanggalLahir;
  final String noHp;
  final String alamat;
  final String password;

  const _SiswaEditFormResult({
    required this.nama,
    required this.email,
    required this.username,
    required this.nis,
    required this.tempatLahir,
    required this.jenisKelamin,
    required this.tanggalLahir,
    required this.noHp,
    required this.alamat,
    required this.password,
  });
}
