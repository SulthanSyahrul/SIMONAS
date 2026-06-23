import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_external_filter_bar.dart';
import '../../../models/tahun_ajaran_model.dart';
import '../widgets/app_alert.dart';
import '../providers/manajemen_akademik_provider.dart';

class WaliKelasTab extends ConsumerStatefulWidget {
  final String selectedTahunAjaran;
  final String tahunAjaranId;
  final List<TahunAjaranRecord> tahunAjaranOptions;
  final ValueChanged<String> onTahunAjaranChanged;

  const WaliKelasTab({
    super.key,
    required this.selectedTahunAjaran,
    required this.tahunAjaranId,
    required this.tahunAjaranOptions,
    required this.onTahunAjaranChanged,
  });

  @override
  ConsumerState<WaliKelasTab> createState() => _WaliKelasTabState();
}

class _WaliKelasTabState extends ConsumerState<WaliKelasTab> {
  bool _isFilterVisible = true;

  Future<void> _refresh() async {
    await ref
        .read(waliKelasManagementProvider(widget.tahunAjaranId).notifier)
        .loadData(forceRefreshData: true);
  }

  Future<void> _onTambahWaliKelas() async {
    final payload = await _showWaliKelasDialog();
    if (payload == null) {
      return;
    }

    try {
      await ref
          .read(waliKelasManagementProvider(widget.tahunAjaranId).notifier)
          .assignWaliKelas(
            kelasId: payload['kelas_id'] as String,
            guruUid: payload['guru_uid'] as String,
          );
      if (!mounted) {
        return;
      }
      _showSuccess('Penugasan wali kelas berhasil disimpan.');
    } catch (e) {
      if (!mounted) {
        return;
      }
      _showError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _onEditWaliKelas(WaliKelasManajemenItem item) async {
    final payload = await _showWaliKelasDialog(initial: item);
    if (payload == null) {
      return;
    }

    try {
      await ref
          .read(waliKelasManagementProvider(widget.tahunAjaranId).notifier)
          .assignWaliKelas(
            kelasId: payload['kelas_id'] as String,
            guruUid: payload['guru_uid'] as String,
          );
      if (!mounted) {
        return;
      }
      _showSuccess('Wali kelas berhasil diupdate.');
    } catch (e) {
      if (!mounted) {
        return;
      }
      _showError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _onDeleteWaliKelas(WaliKelasManajemenItem item) async {
    final confirmed = await AppAlert.confirm(
      context,
      title: 'Hapus Wali Kelas',
      message: 'Hapus penugasan wali kelas untuk ${item.kelasName}?',
    );

    if (!confirmed) {
      return;
    }

    try {
      await ref
          .read(waliKelasManagementProvider(widget.tahunAjaranId).notifier)
          .deleteWaliKelas(item.kelasId);
      if (!mounted) {
        return;
      }
      _showSuccess('Penugasan wali kelas berhasil dihapus.');
    } catch (e) {
      if (!mounted) {
        return;
      }
      _showError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<Map<String, dynamic>?> _showWaliKelasDialog({
    WaliKelasManajemenItem? initial,
  }) async {
    final state = ref.read(waliKelasManagementProvider(widget.tahunAjaranId));

    if (state.kelasOptions.isEmpty || state.guruOptions.isEmpty) {
      _showError('Data kelas atau data guru belum tersedia.');
      return null;
    }

    String? selectedKelasId =
        initial?.kelasId ??
        (state.kelasOptions.isNotEmpty ? state.kelasOptions.first.id : null);
    String? selectedGuruUid = initial?.waliKelasUid;
    selectedGuruUid ??= state.guruOptions.isNotEmpty
        ? state.guruOptions.first.uid
        : null;
    String? localError;

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(
              initial == null ? 'Tambah Wali Kelas' : 'Edit Wali Kelas',
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (initial == null)
                    _buildDropdownField<String>(
                      label: 'Kelas',
                      value: selectedKelasId,
                      items: state.kelasOptions
                          .map(
                            (kelas) => DropdownMenuItem<String>(
                              value: kelas.id,
                              child: Text(kelas.namaKelas),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedKelasId = value;
                          localError = null;
                        });
                      },
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Kelas',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Text(initial.kelasName),
                        ),
                      ],
                    ),
                  const SizedBox(height: 10),
                  _buildDropdownField<String>(
                    label: 'Guru',
                    value: selectedGuruUid,
                    items: state.guruOptions
                        .map(
                          (guru) => DropdownMenuItem<String>(
                            value: guru.uid,
                            child: Text(guru.nama),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedGuruUid = value;
                        localError = null;
                      });
                    },
                  ),
                  if (localError != null && localError!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      localError!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (selectedKelasId == null || selectedGuruUid == null) {
                    setDialogState(() {
                      localError = 'Kelas dan guru wajib dipilih.';
                    });
                    return;
                  }

                  Navigator.of(context).pop({
                    'kelas_id': selectedKelasId!,
                    'guru_uid': selectedGuruUid!,
                  });
                },
                child: Text(initial == null ? 'Simpan' : 'Update'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<T>(
          initialValue: value,
          items: items,
          onChanged: onChanged,
          isExpanded: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
        ),
      ],
    );
  }

  void _showSuccess(String message) {
    AppAlert.success(
      context,
      title: 'Berhasil',
      message: message,
      autoClose: true,
    );
  }

  void _showError(String message) {
    AppAlert.error(context, message: message);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(waliKelasManagementProvider(widget.tahunAjaranId));

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            AppExternalFilterBar(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            isExpanded: _isFilterVisible,
            onToggle: () {
              setState(() {
                _isFilterVisible = !_isFilterVisible;
              });
            },
            onReset: _refresh,
            onApply: _refresh,
            isBusy: state.isLoading,
            children: [
              AppExternalFilterField(
                label: 'Tahun Ajaran',
                child: DropdownButtonFormField<String>(
                  initialValue: widget.tahunAjaranId,
                  decoration: appExternalFilterDecoration(
                    hintText: 'Pilih tahun ajaran',
                    icon: Icons.school_rounded,
                  ),
                  items: widget.tahunAjaranOptions
                      .map(
                        (year) => DropdownMenuItem<String>(
                          value: year.id,
                          child: Text(
                            year.aktif ? '${year.nama} (Aktif)' : year.nama,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    widget.onTahunAjaranChanged(value);
                  },
                ),
              ),
            ],
          ),
            if (state.error != null && state.error!.isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.error.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  state.error!,
                  style: const TextStyle(fontSize: 12, color: AppColors.error),
                ),
              ),
            if (state.isLoading && state.data.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 120),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.data.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 120),
                child: Center(
                  child: Text(
                    'Belum ada data kelas pada tahun ajaran ini.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: state.data.length,
                itemBuilder: (context, index) {
                  final item = state.data[index];
                  return _buildWaliKelasCard(item);
                },
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _onTambahWaliKelas,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildWaliKelasCard(WaliKelasManajemenItem item) {
    final hasWali = item.hasWaliKelas;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.class_, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kelas ${item.kelasName}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Lantai ${item.lantai}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasWali
                        ? 'Wali kelas: ${item.waliKelasName ?? item.waliKelasUid}'
                        : 'Belum ada wali kelas',
                    style: TextStyle(
                      fontSize: 13,
                      color: hasWali
                          ? AppColors.textPrimary
                          : AppColors.warning,
                      fontWeight: hasWali ? FontWeight.w500 : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => _onEditWaliKelas(item),
              icon: Icon(hasWali ? Icons.edit : Icons.person_add),
              tooltip: hasWali ? 'Edit Wali' : 'Pilih Wali',
              color: AppColors.primary,
            ),
            IconButton(
              onPressed: hasWali ? () => _onDeleteWaliKelas(item) : null,
              icon: const Icon(Icons.delete),
              tooltip: 'Hapus Wali',
              color: AppColors.error,
            ),
          ],
        ),
      ),
    );
  }
}
