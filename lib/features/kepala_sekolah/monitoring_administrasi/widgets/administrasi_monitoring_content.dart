import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/administrasi_file_opener.dart';
import '../../../../core/widgets/app_external_filter_bar.dart';
import '../../widgets/app_alert.dart';
import '../../providers/administrasi_monitoring_provider.dart';

class AdministrasiMonitoringContent extends ConsumerStatefulWidget {
  final String jenis;
  final String title;

  const AdministrasiMonitoringContent({
    super.key,
    required this.jenis,
    required this.title,
  });

  @override
  ConsumerState<AdministrasiMonitoringContent> createState() =>
      _AdministrasiMonitoringContentState();
}

class _AdministrasiMonitoringContentState
    extends ConsumerState<AdministrasiMonitoringContent> {
  bool _isFilterVisible = true;
  bool _isBootstrapped = false;

  static const List<DropdownMenuItem<int?>> _semesterItems = [
    DropdownMenuItem<int?>(value: null, child: Text('Semua Semester')),
    DropdownMenuItem<int?>(value: 1, child: Text('Semester 1 (Ganjil)')),
    DropdownMenuItem<int?>(value: 2, child: Text('Semester 2 (Genap)')),
  ];

  static const List<DropdownMenuItem<String>> _statusItems = [
    DropdownMenuItem<String>(value: 'all', child: Text('Semua Status')),
    DropdownMenuItem<String>(value: 'menunggu', child: Text('Menunggu')),
    DropdownMenuItem<String>(value: 'disetujui', child: Text('Disetujui')),
    DropdownMenuItem<String>(value: 'revisi', child: Text('Perlu Revisi')),
  ];

  String _normalizeStatusForDropdown(String rawStatus) {
    final value = rawStatus.trim().toLowerCase();
    switch (value) {
      case 'pending':
      case 'menunggu':
        return 'menunggu';
      case 'approved':
      case 'disetujui':
        return 'disetujui';
      case 'rejected':
      case 'revisi':
        return 'revisi';
      default:
        return 'menunggu';
    }
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (!mounted || _isBootstrapped) {
        return;
      }
      _isBootstrapped = true;
      await ref
          .read(administrasiMonitoringProvider(widget.jenis).notifier)
          .loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(administrasiMonitoringProvider(widget.jenis));

    return RefreshIndicator(
      onRefresh: () => ref
          .read(administrasiMonitoringProvider(widget.jenis).notifier)
          .refresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _buildFilterSection(state),
          const Divider(height: 1),
          if (state.error != null && state.error!.isNotEmpty)
            Container(
              width: double.infinity,
              color: AppColors.error.withAlpha(20),
              padding: const EdgeInsets.all(12),
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
          else
            _buildListSection(state),
        ],
      ),
    );
  }

  Widget _buildFilterSection(AdministrasiMonitoringState state) {
    return AppExternalFilterBar(
      title: 'Filter Data',
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      isExpanded: _isFilterVisible,
      onToggle: () {
        setState(() {
          _isFilterVisible = !_isFilterVisible;
        });
      },
      onReset: () async {
        final notifier = ref.read(
          administrasiMonitoringProvider(widget.jenis).notifier,
        );
        await notifier.setTahunAjaranId(null);
        await notifier.setSemester(null);
        await notifier.setStatusVerifikasi('all');
      },
      onApply: () => setState(() {}),
      isBusy: state.isLoading,
      children: [
        _buildTahunAjaranDropdown(state),
        _buildSemesterDropdown(state),
        _buildStatusDropdown(state),
      ],
    );
  }

  Widget _buildTahunAjaranDropdown(AdministrasiMonitoringState state) {
    final currentValue = state.selectedTahunAjaranId;

    return AppExternalFilterField(
      label: 'Tahun Ajaran',
      child: DropdownButtonFormField<String>(
        initialValue: currentValue,
        decoration: _dropdownDecoration(Icons.calendar_today),
        items: state.tahunAjaranOptions
            .map(
              (item) => DropdownMenuItem<String>(
                value: item.id,
                child: Text(item.name, style: const TextStyle(fontSize: 13)),
              ),
            )
            .toList(),
        onChanged: (value) {
          ref
              .read(administrasiMonitoringProvider(widget.jenis).notifier)
              .setTahunAjaranId(value);
        },
        isDense: true,
      ),
    );
  }

  Widget _buildSemesterDropdown(AdministrasiMonitoringState state) {
    return AppExternalFilterField(
      label: 'Semester',
      child: DropdownButtonFormField<int?>(
        initialValue: state.selectedSemester,
        decoration: _dropdownDecoration(Icons.event_note),
        items: _semesterItems,
        onChanged: (value) {
          ref
              .read(administrasiMonitoringProvider(widget.jenis).notifier)
              .setSemester(value);
        },
        isDense: true,
      ),
    );
  }

  Widget _buildStatusDropdown(AdministrasiMonitoringState state) {
    return AppExternalFilterField(
      label: 'Status Verifikasi',
      child: DropdownButtonFormField<String>(
        initialValue: state.selectedStatusVerifikasi,
        decoration: _dropdownDecoration(Icons.verified_user),
        items: _statusItems,
        onChanged: (value) {
          if (value != null) {
            ref
                .read(administrasiMonitoringProvider(widget.jenis).notifier)
                .setStatusVerifikasi(value);
          }
        },
        isDense: true,
      ),
    );
  }

  InputDecoration _dropdownDecoration(IconData icon) {
    return appExternalFilterDecoration(hintText: 'Pilih filter', icon: icon);
  }

  Widget _buildListSection(AdministrasiMonitoringState state) {
    if (state.data.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: state.data.length,
      itemBuilder: (context, index) {
        final item = state.data[index];
        return _buildAdministrasiCard(item);
      },
    );
  }

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
              'Tidak ada data ${widget.title.toLowerCase()}',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ubah filter untuk menampilkan data lain',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdministrasiCard(AdministrasiMonitoringItem item) {
    final uploadColor = item.sudahUpload ? AppColors.success : AppColors.error;
    final verificationColor = _statusColor(item.statusVerifikasi);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary.withAlpha(26),
                  radius: 24,
                  child: Text(
                    item.guruName.isNotEmpty ? item.guruName[0] : '-',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.guruName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.mapelName} - Kelas ${item.kelasName}',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildBadge(
                  item.sudahUpload ? 'Sudah Upload' : 'Belum Upload',
                  uploadColor,
                ),
                _buildBadge(item.statusVerifikasi, verificationColor),
                _buildBadge('Semester ${item.semester}', AppColors.info),
              ],
            ),
            if (item.sudahUpload) ...[
              const SizedBox(height: 10),
              Text(
                item.fileName ?? '-',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            if (item.catatanVerifikasi != null &&
                item.catatanVerifikasi!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Catatan: ${item.catatanVerifikasi!}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: item.sudahUpload ? () => _openFile(item) : null,
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('Lihat File'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.info,
                      side: const BorderSide(color: AppColors.info),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: item.sudahUpload
                        ? () => _downloadFile(item)
                        : null,
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('Download'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.warning,
                      side: const BorderSide(color: AppColors.warning),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: item.sudahUpload
                        ? () => _showVerifikasiDialog(item)
                        : null,
                    icon: const Icon(Icons.verified, size: 16),
                    label: const Text('Verifikasi'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openFile(AdministrasiMonitoringItem item) async {
    await AdministrasiFileOpener.openForView(
      context: context,
      fileUrl: item.fileUrl,
      fileName: item.fileName,
      filePath: item.filePath,
    );
  }

  Future<void> _downloadFile(AdministrasiMonitoringItem item) async {
    await AdministrasiFileOpener.openForDownload(
      context: context,
      fileUrl: item.fileUrl,
      fileName: item.fileName,
      filePath: item.filePath,
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(77)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    final value = status.trim().toLowerCase();
    if (value == 'disetujui') {
      return AppColors.success;
    }
    if (value == 'revisi') {
      return AppColors.warning;
    }
    return AppColors.info;
  }

  Future<void> _showVerifikasiDialog(AdministrasiMonitoringItem item) async {
    final formKey = GlobalKey<FormState>();
    String selectedStatus = _normalizeStatusForDropdown(item.statusVerifikasi);
    bool isSubmitting = false;
    final catatanController = TextEditingController(
      text: item.catatanVerifikasi ?? '',
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('Verifikasi ${widget.title}'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.guruName} - ${item.kelasName}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedStatus,
                  decoration: const InputDecoration(
                    labelText: 'Status Verifikasi',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'menunggu',
                      child: Text('Menunggu'),
                    ),
                    DropdownMenuItem(
                      value: 'disetujui',
                      child: Text('Disetujui'),
                    ),
                    DropdownMenuItem(
                      value: 'revisi',
                      child: Text('Perlu Revisi'),
                    ),
                  ],
                  onChanged: isSubmitting
                      ? null
                      : (value) {
                          selectedStatus = value ?? 'menunggu';
                        },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: catatanController,
                  maxLines: 3,
                  enabled: !isSubmitting,
                  decoration: const InputDecoration(
                    labelText: 'Catatan Verifikasi',
                    hintText: 'Tambahkan catatan untuk guru',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting
                  ? null
                  : () => Navigator.of(dialogContext).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) {
                        return;
                      }

                      setDialogState(() {
                        isSubmitting = true;
                      });

                      final notifier = ref.read(
                        administrasiMonitoringProvider(widget.jenis).notifier,
                      );

                      await notifier.updateVerifikasi(
                        administrasiId: item.id,
                        statusVerifikasi: selectedStatus,
                        catatanVerifikasi: catatanController.text.trim().isEmpty
                            ? null
                            : catatanController.text.trim(),
                      );

                      final latestState = ref.read(
                        administrasiMonitoringProvider(widget.jenis),
                      );
                      final hasError =
                          latestState.error != null &&
                          latestState.error!.trim().isNotEmpty;

                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }

                      if (!mounted) {
                        return;
                      }

                      if (hasError) {
                        await AppAlert.error(
                          context,
                          title: 'Gagal',
                          message: 'Status verifikasi gagal diperbarui',
                        );
                        return;
                      }

                      await AppAlert.success(
                        context,
                        title: 'Berhasil',
                        message: 'Status verifikasi berhasil diperbarui',
                      );
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Simpan'),
            ),
          ],
        ),
      ),
    );

    catatanController.dispose();
  }
}
