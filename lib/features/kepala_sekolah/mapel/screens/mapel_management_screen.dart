import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_external_filter_bar.dart';
import '../../../../models/mapel_model.dart';
import '../../widgets/app_alert.dart';
import '../providers/mapel_provider.dart';

class MapelManagementScreen extends ConsumerStatefulWidget {
  const MapelManagementScreen({super.key});

  @override
  ConsumerState<MapelManagementScreen> createState() =>
      _MapelManagementScreenState();
}

class _MapelManagementScreenState extends ConsumerState<MapelManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isFilterVisible = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    Future.microtask(_loadInitialData);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await ref.read(mapelProvider.notifier).loadMapel();
  }

  Future<void> _refreshMapel() async {
    await ref.read(mapelProvider.notifier).loadMapel(forceRefreshData: true);
  }

  void _onSearchChanged() {
    if (!mounted) {
      return;
    }
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
    });
  }

  List<MapelRecord> _buildFilteredData(List<MapelRecord> source) {
    if (_searchQuery.isEmpty) {
      return source;
    }

    return source
        .where((item) => item.namaMapel.toLowerCase().contains(_searchQuery))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mapelProvider);
    final filteredData = _buildFilteredData(state.data);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Mata Pelajaran'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: state.isLoading ? null : _refreshMapel,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshMapel,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _buildSearchBar(),
            if (state.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            if (state.error != null && state.error!.isNotEmpty)
              _buildErrorBanner(state.error!),
            _buildBodyContent(
              context: context,
              state: state,
              filteredData: filteredData,
              hasSearchQuery: _searchQuery.isNotEmpty,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _handleAddMapel,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildSearchBar() {
    return AppExternalFilterBar(
      isExpanded: _isFilterVisible,
      onToggle: () {
        setState(() {
          _isFilterVisible = !_isFilterVisible;
        });
      },
      onReset: () {
        _searchController.clear();
        setState(() {
          _searchQuery = '';
        });
      },
      onApply: _refreshMapel,
      children: [
        AppExternalFilterField(
          label: 'Nama Mapel',
          child: TextField(
            controller: _searchController,
            decoration: appExternalFilterDecoration(
              hintText: 'Cari mata pelajaran...',
              icon: Icons.search_rounded,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: const TextStyle(color: AppColors.error, fontSize: 12),
      ),
    );
  }

  Widget _buildBodyContent({
    required BuildContext context,
    required MapelState state,
    required List<MapelRecord> filteredData,
    required bool hasSearchQuery,
  }) {
    if (state.isLoading && state.data.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!state.isLoading && state.data.isEmpty) {
      return _buildEmptyState(
        icon: Icons.menu_book_outlined,
        title: 'Belum ada mata pelajaran',
        subtitle: 'Tekan tombol + untuk menambahkan mapel baru.',
      );
    }

    if (filteredData.isEmpty) {
      return _buildEmptyState(
        icon: Icons.search_off,
        title: 'Mapel tidak ditemukan',
        subtitle: hasSearchQuery
            ? 'Coba kata kunci pencarian lain.'
            : 'Belum ada data yang bisa ditampilkan.',
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: filteredData.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final mapel = filteredData[index];
        return _buildMapelCard(context, mapel);
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapelCard(BuildContext context, MapelRecord mapel) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withAlpha(20),
          child: const Icon(Icons.menu_book, color: AppColors.primary),
        ),
        title: Text(
          mapel.namaMapel,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text('ID: ${mapel.id}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: AppColors.warning),
              tooltip: 'Edit',
              onPressed: () => _handleEditMapel(mapel),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
              tooltip: 'Hapus',
              onPressed: () => _handleDeleteMapel(mapel),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAddMapel() async {
    final namaMapel = await _showMapelFormDialog(
      context: context,
      title: 'Tambah Mata Pelajaran',
      submitLabel: 'Simpan',
    );

    if (namaMapel == null) {
      return;
    }

    if (!mounted) {
      return;
    }

    try {
      await ref.read(mapelProvider.notifier).addMapel(namaMapel);
      if (!mounted) {
        return;
      }
      await AppAlert.success(
        context,
        title: 'Berhasil',
        message: 'Mata pelajaran berhasil ditambahkan.',
        autoClose: true,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      await AppAlert.error(
        context,
        message: 'Gagal menambah mata pelajaran: $e',
      );
    }
  }

  Future<void> _handleEditMapel(MapelRecord mapel) async {
    final namaMapel = await _showMapelFormDialog(
      context: context,
      title: 'Edit Mata Pelajaran',
      submitLabel: 'Update',
      initialNamaMapel: mapel.namaMapel,
    );

    if (namaMapel == null) {
      return;
    }

    if (!mounted) {
      return;
    }

    try {
      await ref
          .read(mapelProvider.notifier)
          .updateMapel(id: mapel.id, namaMapel: namaMapel);
      if (!mounted) {
        return;
      }
      await AppAlert.success(
        context,
        title: 'Berhasil',
        message: 'Mata pelajaran berhasil diperbarui.',
        autoClose: true,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      await AppAlert.error(
        context,
        message: 'Gagal mengubah mata pelajaran: $e',
      );
    }
  }

  Future<void> _handleDeleteMapel(MapelRecord mapel) async {
    final confirmed = await AppAlert.confirm(
      context,
      title: 'Hapus Mata Pelajaran',
      message: 'Yakin ingin menghapus ${mapel.namaMapel}?',
    );

    if (confirmed != true) {
      return;
    }

    if (!mounted) {
      return;
    }

    try {
      await ref.read(mapelProvider.notifier).deleteMapel(mapel.id);
      if (!mounted) {
        return;
      }
      await AppAlert.success(
        context,
        title: 'Berhasil',
        message: 'Mata pelajaran berhasil dihapus.',
        autoClose: true,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      await AppAlert.error(
        context,
        message: 'Gagal menghapus mata pelajaran: $e',
      );
    }
  }

  Future<String?> _showMapelFormDialog({
    required BuildContext context,
    required String title,
    required String submitLabel,
    String? initialNamaMapel,
  }) async {
    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController(text: initialNamaMapel ?? '');

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Nama Mata Pelajaran',
              hintText: 'Contoh: Matematika',
            ),
            textInputAction: TextInputAction.done,
            validator: (value) {
              final normalized = value?.trim() ?? '';
              if (normalized.isEmpty) {
                return 'Nama mata pelajaran tidak boleh kosong.';
              }
              return null;
            },
            onFieldSubmitted: (_) {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(dialogContext).pop(controller.text.trim());
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(dialogContext).pop(controller.text.trim());
              }
            },
            child: Text(submitLabel),
          ),
        ],
      ),
    );

    controller.dispose();
    return result;
  }
}
