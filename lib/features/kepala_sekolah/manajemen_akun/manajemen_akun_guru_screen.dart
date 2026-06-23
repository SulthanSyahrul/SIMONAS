import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_external_filter_bar.dart';
import '../widgets/app_alert.dart';
import '../providers/manajemen_guru_provider.dart';
import 'edit_guru_screen.dart';
import 'tambah_guru_screen.dart';

class ManajemenAkunGuruScreen extends ConsumerStatefulWidget {
  const ManajemenAkunGuruScreen({super.key});

  @override
  ConsumerState<ManajemenAkunGuruScreen> createState() =>
      _ManajemenAkunGuruScreenState();
}

class _ManajemenAkunGuruScreenState
    extends ConsumerState<ManajemenAkunGuruScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isFilterVisible = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    ref
        .read(manajemenGuruProvider.notifier)
        .setSearchQuery(_searchController.text);
  }

  Future<void> _refresh() async {
    await ref
        .read(manajemenGuruProvider.notifier)
        .loadGuru(forceRefreshData: true);
  }

  String _statusLabel(GuruAccountItem guru) {
    final statusRaw = guru.status.trim().toLowerCase();
    if (statusRaw == 'aktif' || statusRaw == 'nonaktif') {
      return statusRaw;
    }
    return guru.active ? 'aktif' : 'nonaktif';
  }

  Future<void> _toggleStatusGuru(GuruAccountItem guru) async {
    final currentStatus = _statusLabel(guru);
    final isActive = currentStatus == 'aktif';
    final actionText = isActive ? 'menonaktifkan' : 'mengaktifkan';

    final confirmed = await AppAlert.confirm(
      context,
      title: '${isActive ? 'Nonaktifkan' : 'Aktifkan'} Akun',
      message: 'Apakah Anda yakin ingin $actionText akun ${guru.nama}?',
    );

    if (!confirmed) {
      return;
    }

    await ref.read(manajemenGuruProvider.notifier).toggleActive(guru);
    if (!mounted) {
      return;
    }

    final next = ref.read(manajemenGuruProvider);
    if (next.error != null && next.error!.isNotEmpty) {
      await AppAlert.error(context, message: next.error!);
      ref.read(manajemenGuruProvider.notifier).clearError();
      return;
    }

    await AppAlert.success(
      context,
      title: 'Berhasil',
      message: 'Status akun berhasil diubah.',
      autoClose: true,
    );
  }

  Future<void> _navigateToEdit(GuruAccountItem guru) async {
    final payload = {
      'user_id': guru.id,
      'uid': guru.uid,
      'nama': guru.nama,
      'email': guru.email,
      'role': guru.role,
      'roles': guru.roles,
      'username': guru.username ?? '',
      'nip': guru.nip ?? '',
      'nuptk': guru.nuptk ?? '',
      'alamat': guru.alamat ?? '',
      'gender': guru.gender ?? '',
      'golongan': guru.golongan ?? '',
      'tanggal_lahir': guru.tanggalLahir,
      'tempat_lahir': guru.tempatLahir ?? '',
      'status': _statusLabel(guru),
      'active': guru.active,
    };

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (context) => EditGuruScreen(guru: payload)),
    );

    if (result == null) {
      return;
    }

    final passwordChanged = result['password_changed'] == true;

    await ref.read(manajemenGuruProvider.notifier).updateGuru(guru.id, result);

    if (!mounted) {
      return;
    }

    final next = ref.read(manajemenGuruProvider);
    if (next.error != null && next.error!.isNotEmpty) {
      await AppAlert.error(context, message: next.error!);
      ref.read(manajemenGuruProvider.notifier).clearError();
      return;
    }

    await AppAlert.success(
      context,
      title: 'Berhasil',
      message: passwordChanged
          ? 'Data guru berhasil diperbarui.\nPassword berhasil diperbarui.'
          : 'Data guru berhasil diperbarui.',
      autoClose: true,
    );
  }

  Future<void> _navigateToTambah() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (context) => const TambahGuruScreen()),
    );

    if (result == null) {
      return;
    }

    await ref.read(manajemenGuruProvider.notifier).createGuru(result);

    if (!mounted) {
      return;
    }

    final next = ref.read(manajemenGuruProvider);
    if (next.error != null && next.error!.isNotEmpty) {
      await AppAlert.error(context, message: next.error!);
      ref.read(manajemenGuruProvider.notifier).clearError();
      return;
    }

    await AppAlert.success(
      context,
      title: 'Berhasil',
      message: 'Akun guru berhasil ditambahkan.',
      autoClose: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(manajemenGuruProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Akun Guru'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: state.isLoading ? null : _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _buildHeaderFilter(state),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withAlpha(26),
                border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.info, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Menampilkan ${state.filteredGuru.length} dari ${state.allGuru.length} guru',
                      style: const TextStyle(fontSize: 12, color: AppColors.info),
                    ),
                  ),
                ],
              ),
            ),
            if (state.error != null && state.error!.isNotEmpty)
              Container(
                width: double.infinity,
                color: AppColors.error.withAlpha(20),
                padding: const EdgeInsets.all(12),
                child: Text(
                  state.error!,
                  style: const TextStyle(color: AppColors.error, fontSize: 12),
                ),
              ),
            if (state.isLoading && state.allGuru.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 120),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.filteredGuru.isEmpty)
              _buildEmptyState()
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: state.filteredGuru.length,
                itemBuilder: (context, index) {
                  final guru = state.filteredGuru[index];
                  return _buildGuruCard(guru);
                },
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToTambah,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildHeaderFilter(ManajemenGuruState state) {
    return AppExternalFilterBar(
      isExpanded: _isFilterVisible,
      onToggle: () {
        setState(() {
          _isFilterVisible = !_isFilterVisible;
        });
      },
      onReset: () {
        _searchController.clear();
        ref.read(manajemenGuruProvider.notifier).setStatusFilter('semua');
      },
      onApply: _refresh,
      isBusy: state.isLoading,
      children: [
        AppExternalFilterField(
          label: 'Nama',
          child: TextField(
            controller: _searchController,
            decoration: appExternalFilterDecoration(
              hintText: 'Cari nama, username, atau NIP guru...',
              icon: Icons.search_rounded,
            ),
          ),
        ),
        AppExternalFilterField(
          label: 'Status Aktif',
          child: DropdownButtonFormField<String>(
            initialValue: state.selectedStatus,
            decoration: appExternalFilterDecoration(
              hintText: 'Pilih status',
              icon: Icons.toggle_on_rounded,
            ),
            items: const [
              DropdownMenuItem(value: 'semua', child: Text('Semua')),
              DropdownMenuItem(value: 'aktif', child: Text('Aktif')),
              DropdownMenuItem(value: 'nonaktif', child: Text('Nonaktif')),
            ],
            onChanged: (value) {
              if (value == null) {
                return;
              }
              ref.read(manajemenGuruProvider.notifier).setStatusFilter(value);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 96),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_off_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Tidak ada guru ditemukan',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Coba ubah filter atau tambah guru baru',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuruCard(GuruAccountItem guru) {
    final status = _statusLabel(guru);
    final isActive = status == 'aktif';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.success.withAlpha(26)
                    : Colors.grey.withAlpha(26),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.person,
                size: 32,
                color: isActive ? AppColors.success : Colors.grey[600],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    guru.nama,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.badge,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'NIP: ${guru.nip ?? '-'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(
                        Icons.account_circle,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '@${guru.username ?? '-'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.success.withAlpha(26)
                          : Colors.grey.withAlpha(26),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isActive ? Icons.check_circle : Icons.cancel,
                          size: 14,
                          color: isActive
                              ? AppColors.success
                              : Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isActive ? 'Aktif' : 'Nonaktif',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isActive
                                ? AppColors.success
                                : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () => _navigateToEdit(guru),
                  color: AppColors.warning,
                  tooltip: 'Edit',
                ),
                const SizedBox(height: 4),
                IconButton(
                  icon: Icon(
                    isActive ? Icons.block : Icons.check_circle,
                    size: 20,
                  ),
                  onPressed: () => _toggleStatusGuru(guru),
                  color: isActive ? AppColors.error : AppColors.success,
                  tooltip: isActive ? 'Nonaktifkan' : 'Aktifkan',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
