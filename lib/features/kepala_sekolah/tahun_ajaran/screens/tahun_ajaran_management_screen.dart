import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_external_filter_bar.dart';
import '../../../../models/tahun_ajaran_model.dart';
import '../../widgets/app_alert.dart';
import '../../providers/tahun_ajaran_management_provider.dart';

class TahunAjaranManagementScreen extends ConsumerStatefulWidget {
  const TahunAjaranManagementScreen({super.key});

  @override
  ConsumerState<TahunAjaranManagementScreen> createState() =>
      _TahunAjaranManagementScreenState();
}

class _TahunAjaranManagementScreenState
    extends ConsumerState<TahunAjaranManagementScreen> {
  String _statusFilter = 'semua';
  bool _isFilterVisible = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadInitialData);
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await ref.read(tahunAjaranManagementProvider.notifier).loadTahunAjaran();
  }

  Future<void> _handleAdd() async {
    final formData = await _showFormDialog();
    if (formData == null) {
      return;
    }

    try {
      await ref
          .read(tahunAjaranManagementProvider.notifier)
          .addTahunAjaran(
            nama: formData.nama,
            semesterAktif: formData.semesterAktif,
            aktif: formData.aktif,
          );

      if (!mounted) {
        return;
      }
      await AppAlert.success(
        context,
        title: 'Berhasil',
        message: 'Tahun ajaran berhasil ditambahkan.',
        autoClose: true,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      await _showErrorAlert(_toUserMessage(e));
    }
  }

  Future<void> _handleEdit(TahunAjaranRecord record) async {
    final formData = await _showFormDialog(initial: record);
    if (formData == null) {
      return;
    }

    try {
      await ref
          .read(tahunAjaranManagementProvider.notifier)
          .updateTahunAjaran(
            id: record.id,
            nama: formData.nama,
            semesterAktif: formData.semesterAktif,
            aktif: formData.aktif,
          );

      if (!mounted) {
        return;
      }
      await AppAlert.success(
        context,
        title: 'Berhasil',
        message: 'Tahun ajaran berhasil diperbarui.',
        autoClose: true,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      await _showErrorAlert(_toUserMessage(e));
    }
  }

  Future<void> _handleSetActive(TahunAjaranRecord record) async {
    final confirmed = await AppAlert.confirm(
      context,
      title: 'Ubah Tahun Ajaran Aktif',
      message:
          '${record.nama} akan dijadikan tahun ajaran aktif dan menggantikan tahun ajaran aktif saat ini. Lanjutkan?',
    );

    if (!confirmed) {
      return;
    }

    try {
      await ref
          .read(tahunAjaranManagementProvider.notifier)
          .setActiveTahunAjaran(record.id);

      if (!mounted) {
        return;
      }
      await AppAlert.success(
        context,
        title: 'Berhasil',
        message: '${record.nama} sekarang menjadi tahun ajaran aktif.',
        autoClose: true,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      await _showErrorAlert(_toUserMessage(e));
    }
  }

  Future<void> _handleDelete(TahunAjaranRecord record) async {
    final confirmed = await AppAlert.confirm(
      context,
      title: 'Hapus Tahun Ajaran',
      message: record.aktif
          ? 'Tahun ajaran ini sedang aktif. Jika dihapus, sistem akan otomatis memilih tahun ajaran aktif pengganti. Lanjutkan?'
          : 'Yakin ingin menghapus ${record.nama}?',
    );

    if (!confirmed) {
      return;
    }

    try {
      await ref
          .read(tahunAjaranManagementProvider.notifier)
          .deleteTahunAjaran(record.id);

      if (!mounted) {
        return;
      }
      await AppAlert.success(
        context,
        title: 'Berhasil',
        message: 'Tahun ajaran berhasil dihapus.',
        autoClose: true,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      await _showErrorAlert(_toUserMessage(e));
    }
  }

  Future<_TahunAjaranFormData?> _showFormDialog({
    TahunAjaranRecord? initial,
  }) async {
    return showDialog<_TahunAjaranFormData>(
      context: context,
      builder: (_) => _TahunAjaranFormDialog(initial: initial),
    );
  }

  Future<void> _showErrorAlert(String message) {
    return AppAlert.error(context, message: message);
  }

  String _toUserMessage(dynamic error) {
    final raw = error.toString();
    const exceptionPrefix = 'Exception: ';
    if (raw.startsWith(exceptionPrefix)) {
      return raw.substring(exceptionPrefix.length).trim();
    }
    return raw;
  }

  List<TahunAjaranRecord> _sortedForMainList(List<TahunAjaranRecord> source) {
    final rows = <TahunAjaranRecord>[...source]
      ..sort((a, b) {
        final left = a.nama.toLowerCase();
        final right = b.nama.toLowerCase();
        return right.compareTo(left);
      });
    return rows;
  }

  List<TahunAjaranRecord> _applyStatusFilter(List<TahunAjaranRecord> source) {
    if (_statusFilter == 'aktif') {
      return source.where((item) => item.aktif).toList(growable: false);
    }
    if (_statusFilter == 'nonaktif') {
      return source.where((item) => !item.aktif).toList(growable: false);
    }
    return source;
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) {
      return '-';
    }

    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tahunAjaranManagementProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Tahun Ajaran'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: state.isLoading
                ? null
                : () => ref
                      .read(tahunAjaranManagementProvider.notifier)
                      .loadTahunAjaran(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(tahunAjaranManagementProvider.notifier).loadTahunAjaran(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (state.isLoading)
              const LinearProgressIndicator(minHeight: 2)
            else
              const SizedBox(height: 2),
            if (state.error != null && state.error!.isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  state.error!,
                  style: const TextStyle(color: AppColors.error, fontSize: 12),
                ),
              ),
            _buildStatusFilter(),
            _buildAllDataTab(state),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: state.isLoading ? null : _handleAdd,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
    );
  }

  Widget _buildAllDataTab(TahunAjaranManagementState state) {
    final rows = _applyStatusFilter(_sortedForMainList(state.items));

    if (state.isLoading && rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 120),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (rows.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Belum ada data tahun ajaran untuk filter ini.\nTekan tombol Tambah untuk membuat data baru.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final record = rows[index];
        return _buildTahunAjaranCard(record, state.isLoading);
      },
    );
  }

  Widget _buildTahunAjaranCard(TahunAjaranRecord record, bool isBusy) {
    final statusColor = record.aktif ? AppColors.success : Colors.grey[700]!;
    final statusText = record.aktif ? 'Aktif' : 'Nonaktif';

    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.nama,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Semester aktif: ${record.semesterAktif ?? '-'}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Update: ${_formatDateTime(record.updatedAt ?? record.createdAt)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(24),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withAlpha(100)),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (!record.aktif)
                  OutlinedButton.icon(
                    onPressed: isBusy ? null : () => _handleSetActive(record),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Set Aktif'),
                  ),
                OutlinedButton.icon(
                  onPressed: isBusy ? null : () => _handleEdit(record),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                  onPressed: isBusy ? null : () => _handleDelete(record),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Hapus'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusFilter() {
    return AppExternalFilterBar(
      isExpanded: _isFilterVisible,
      onToggle: () {
        setState(() {
          _isFilterVisible = !_isFilterVisible;
        });
      },
      onReset: () {
        setState(() {
          _statusFilter = 'semua';
        });
      },
      onApply: () => setState(() {}),
      isBusy: ref.watch(tahunAjaranManagementProvider).isLoading,
      children: [
        AppExternalFilterField(
          label: 'Status Aktif',
          child: DropdownButtonFormField<String>(
            initialValue: _statusFilter,
            decoration: appExternalFilterDecoration(
              hintText: 'Pilih status',
              icon: Icons.filter_list_rounded,
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
              setState(() {
                _statusFilter = value;
              });
            },
          ),
        ),
      ],
    );
  }
}

class _TahunAjaranFormDialog extends StatefulWidget {
  final TahunAjaranRecord? initial;

  const _TahunAjaranFormDialog({this.initial});

  @override
  State<_TahunAjaranFormDialog> createState() => _TahunAjaranFormDialogState();
}

class _TahunAjaranFormDialogState extends State<_TahunAjaranFormDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _namaController;
  late int _selectedSemester;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _namaController = TextEditingController(text: widget.initial?.nama ?? '');
    final initialSemester = widget.initial?.semesterAktif ?? 1;
    _selectedSemester = initialSemester == 2 ? 2 : 1;
    _isActive = widget.initial?.aktif ?? false;
  }

  @override
  void dispose() {
    _namaController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(
      _TahunAjaranFormData(
        nama: _namaController.text.trim(),
        semesterAktif: _selectedSemester,
        aktif: _isActive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.initial == null ? 'Tambah Tahun Ajaran' : 'Edit Tahun Ajaran',
      ),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _namaController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nama Tahun Ajaran',
                  hintText: 'Contoh: 2025/2026',
                  prefixIcon: Icon(Icons.calendar_month),
                ),
                validator: (value) {
                  final text = (value ?? '').trim();
                  if (text.isEmpty) {
                    return 'Nama tahun ajaran wajib diisi.';
                  }

                  final regex = RegExp(r'^\d{4}/\d{4}$');
                  if (!regex.hasMatch(text)) {
                    return 'Format harus YYYY/YYYY.';
                  }

                  final parts = text.split('/');
                  final first = int.tryParse(parts[0]);
                  final second = int.tryParse(parts[1]);
                  if (first == null || second == null || second != first + 1) {
                    return 'Tahun kedua harus satu tingkat di atas tahun pertama.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _selectedSemester,
                decoration: const InputDecoration(
                  labelText: 'Semester Aktif',
                  prefixIcon: Icon(Icons.school),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 1,
                    child: Text('Semester 1 (Ganjil)'),
                  ),
                  DropdownMenuItem(value: 2, child: Text('Semester 2 (Genap)')),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _selectedSemester = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _isActive,
                onChanged: (value) {
                  setState(() {
                    _isActive = value;
                  });
                },
                title: const Text('Jadikan Aktif'),
                subtitle: const Text(
                  'Jika aktif, semua tahun ajaran lain akan nonaktif.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(widget.initial == null ? 'Simpan' : 'Update'),
        ),
      ],
    );
  }
}

class _TahunAjaranFormData {
  final String nama;
  final int semesterAktif;
  final bool aktif;

  const _TahunAjaranFormData({
    required this.nama,
    required this.semesterAktif,
    required this.aktif,
  });
}
