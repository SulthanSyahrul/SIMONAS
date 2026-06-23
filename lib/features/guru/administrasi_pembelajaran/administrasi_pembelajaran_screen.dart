import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../kepala_sekolah/widgets/app_alert.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/academic_year_provider.dart';
import '../../../core/widgets/app_external_filter_bar.dart';
import '../../../core/utils/administrasi_file_opener.dart';
import '../../../core/utils/administrasi_file_type.dart';
import '../../../providers/supabase_providers.dart';
import '../../../services/administrasi_storage_service.dart';
import '../providers/administrasi_guru_supabase_provider.dart';
import '../providers/jadwal_guru_supabase_provider.dart';

class _DropdownOption {
  final String id;
  final String label;

  const _DropdownOption({required this.id, required this.label});
}

/// Screen utama untuk Administrasi Pembelajaran Guru.
/// Input metadata dokumen dan menampilkan history dokumen guru.
class AdministrasiPembelajaranScreen extends ConsumerStatefulWidget {
  final AcademicYearProvider academicYearProvider;
  final String guruUid;

  const AdministrasiPembelajaranScreen({
    super.key,
    required this.academicYearProvider,
    required this.guruUid,
  });

  @override
  ConsumerState<AdministrasiPembelajaranScreen> createState() =>
      _AdministrasiPembelajaranScreenState();
}

class _AdministrasiPembelajaranScreenState
    extends ConsumerState<AdministrasiPembelajaranScreen> {
  static const String _allFilterValue = 'all';

  List<_DropdownOption> _kelasOptions = const [];
  List<_DropdownOption> _mapelOptions = const [];

  String _selectedJenis = 'silabus';
  String? _selectedKelasId;
  String? _selectedMapelId;
  int _selectedSemester = 1;

  String? _selectedFileName;
  String? _selectedFileUrl;
  String? _selectedFilePath;
  Uint8List? _selectedFileBytes;
  String? _selectedFileContentType;
  bool _isUploadingFile = false;
  double _uploadProgress = 0;

  bool _isHistoryFilterVisible = true;
  String _historyTahunAjaranFilter = _allFilterValue;
  String _historyKelasFilter = _allFilterValue;
  String _historyMapelFilter = _allFilterValue;
  String _historySemesterFilter = _allFilterValue;
  String _historyJenisFilter = _allFilterValue;
  String _historyStatusFilter = _allFilterValue;

  static const int _maxFileSizeBytes = 20 * 1024 * 1024;

  String _debugPlatformLabel() {
    if (kIsWeb) {
      return 'web';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  String? get _selectedTahunAjaranId {
    return ref.read(tahunAjaranProvider).selectedTahunAjaranId;
  }

  Future<void> _showErrorAlert(String message) {
    return AppAlert.error(context, message: message);
  }

  Future<void> _showSuccessAlert(String message) {
    return AppAlert.success(context, title: 'Berhasil', message: message);
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await _loadReferenceData();
    });
  }

  Future<void> _syncDropdownFromJadwal({bool preserveSelection = true}) async {
    final notifier = ref.read(jadwalGuruProvider(widget.guruUid).notifier);
    final kelasOptions = notifier
        .getAvailableKelas()
        .map((item) => _DropdownOption(id: item.id, label: item.label))
        .toList();

    String? selectedKelasId = preserveSelection ? _selectedKelasId : null;
    if (selectedKelasId == null ||
        !kelasOptions.any((item) => item.id == selectedKelasId)) {
      selectedKelasId = kelasOptions.isNotEmpty ? kelasOptions.first.id : null;
    }

    final mapelOptions = selectedKelasId == null
        ? <_DropdownOption>[]
        : notifier
              .getMapelByKelas(selectedKelasId)
              .map((item) => _DropdownOption(id: item.id, label: item.label))
              .toList();

    String? selectedMapelId = preserveSelection ? _selectedMapelId : null;
    if (selectedMapelId == null ||
        !mapelOptions.any((item) => item.id == selectedMapelId)) {
      selectedMapelId = mapelOptions.isNotEmpty ? mapelOptions.first.id : null;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _kelasOptions = kelasOptions;
      _mapelOptions = mapelOptions;
      _selectedKelasId = selectedKelasId;
      _selectedMapelId = selectedMapelId;
    });
  }

  Future<void> _loadReferenceData({bool forceRefreshData = false}) async {
    await ref
        .read(tahunAjaranProvider.notifier)
        .loadTahunAjaran(forceRefreshData: forceRefreshData);

    final selectedTahunAjaranId = _selectedTahunAjaranId;
    if (selectedTahunAjaranId == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _kelasOptions = const <_DropdownOption>[];
        _mapelOptions = const <_DropdownOption>[];
        _selectedKelasId = null;
        _selectedMapelId = null;
      });
      return;
    }

    final tahunAjaranOptions = ref.read(tahunAjaranProvider).options;
    final shouldUseActiveAsDefaultHistoryFilter =
        _historyTahunAjaranFilter == _allFilterValue ||
        !tahunAjaranOptions.any((item) => item.id == _historyTahunAjaranFilter);

    if (mounted && shouldUseActiveAsDefaultHistoryFilter) {
      setState(() {
        _historyTahunAjaranFilter = selectedTahunAjaranId;
      });
    }

    await ref
        .read(jadwalGuruProvider(widget.guruUid).notifier)
        .loadJadwalGuruByTahunAjaran(
          selectedTahunAjaranId,
          forceRefreshData: forceRefreshData,
          forceRefreshCache: forceRefreshData,
        );

    await _syncDropdownFromJadwal();
    await _reloadAdministrasi(forceRefreshData: forceRefreshData);
  }

  Future<void> _onTahunAjaranChanged(String? tahunAjaranId) async {
    if (tahunAjaranId == null) {
      return;
    }

    ref
        .read(tahunAjaranProvider.notifier)
        .setSelectedTahunAjaran(tahunAjaranId);

    await ref
        .read(jadwalGuruProvider(widget.guruUid).notifier)
        .loadJadwalGuruByTahunAjaran(tahunAjaranId);

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedKelasId = null;
      _selectedMapelId = null;
      _kelasOptions = const <_DropdownOption>[];
      _mapelOptions = const <_DropdownOption>[];
    });

    await _syncDropdownFromJadwal(preserveSelection: false);
    await _reloadAdministrasi();
  }

  void _onKelasChanged(String? kelasId) {
    final notifier = ref.read(jadwalGuruProvider(widget.guruUid).notifier);
    final mapelOptions = kelasId == null
        ? <_DropdownOption>[]
        : notifier
              .getMapelByKelas(kelasId)
              .map((item) => _DropdownOption(id: item.id, label: item.label))
              .toList();

    setState(() {
      _selectedKelasId = kelasId;
      _mapelOptions = mapelOptions;
      if (_selectedMapelId == null ||
          !mapelOptions.any((item) => item.id == _selectedMapelId)) {
        _selectedMapelId = mapelOptions.isNotEmpty
            ? mapelOptions.first.id
            : null;
      }
    });
  }

  bool _isSelectedPairValid() {
    final kelasId = _selectedKelasId;
    final mapelId = _selectedMapelId;
    if (kelasId == null || mapelId == null) {
      return false;
    }

    return ref
        .read(jadwalGuruProvider(widget.guruUid).notifier)
        .isPairValid(kelasId: kelasId, mapelId: mapelId);
  }

  Future<void> _reloadAdministrasi({bool forceRefreshData = false}) async {
    try {
      final tahunAjaranId = _selectedTahunAjaranId;
      if (tahunAjaranId == null) {
        return;
      }

      await ref
          .read(administrasiGuruSupabaseProvider(widget.guruUid).notifier)
          .getAdministrasiByGuru(
            forceRefreshData: forceRefreshData,
            forceRefreshCache: forceRefreshData,
          );
    } catch (e) {
      if (!mounted) {
        return;
      }
      await _showErrorAlert('Gagal memuat administrasi: $e');
    }
  }

  Future<void> _saveAdministrasi() async {
    if (_selectedKelasId == null || _selectedMapelId == null) {
      await _showErrorAlert('Pilih kelas dan mata pelajaran terlebih dahulu.');
      return;
    }

    if (_selectedFileName == null ||
        _selectedFilePath == null ||
        _selectedFileBytes == null ||
        _selectedFileContentType == null) {
      await _showErrorAlert(
        'Silakan upload file PDF, DOCX, atau XLSX terlebih dahulu.',
      );
      return;
    }

    if (!_isSelectedPairValid()) {
      await _showErrorAlert(
        'Kelas dan mata pelajaran tidak sesuai jadwal mengajar Anda.',
      );
      return;
    }

    final tahunAjaranId = _selectedTahunAjaranId;
    if (tahunAjaranId == null) {
      await _showErrorAlert('Tahun ajaran belum tersedia.');
      return;
    }

    try {
      setState(() {
        _isUploadingFile = true;
        _uploadProgress = 0;
      });

      final uploadResult = await ref
          .read(administrasiGuruSupabaseProvider(widget.guruUid).notifier)
          .uploadAdministrasiFile(
            bytes: _selectedFileBytes!,
            fileName: _selectedFileName!,
            localFilePath: _selectedFilePath,
            contentType: _selectedFileContentType,
            onProgress: (progress) {
              if (!mounted) {
                return;
              }
              setState(() {
                _uploadProgress = progress;
              });
            },
          );

      await ref
          .read(administrasiGuruSupabaseProvider(widget.guruUid).notifier)
          .createAdministrasi(
            jenis: _selectedJenis,
            kelasId: _selectedKelasId!,
            mapelId: _selectedMapelId!,
            tahunAjaranId: tahunAjaranId,
            semester: _selectedSemester,
            fileUrl: uploadResult.fileUrl,
            filePath: uploadResult.filePath,
            fileName: uploadResult.fileName,
          );

      if (!mounted) {
        return;
      }

      final stagedPath = _selectedFilePath;
      setState(() {
        _selectedFileName = null;
        _selectedFileUrl = null;
        _selectedFilePath = null;
        _selectedFileBytes = null;
        _selectedFileContentType = null;
        _uploadProgress = 0;
      });

      if (stagedPath != null && stagedPath.isNotEmpty) {
        try {
          await ref
              .read(administrasiStorageServiceProvider)
              .deleteStagedFile(stagedPath);
        } catch (_) {
          // Cleanup file sementara bersifat best-effort.
        }
      }

      await _showSuccessAlert('Dokumen berhasil diunggah.');
    } catch (e) {
      if (!mounted) {
        return;
      }
      await _showErrorAlert('Gagal menyimpan dokumen: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingFile = false;
        });
      }
    }
  }

  Future<Uint8List?> _readPickedFileBytes(PlatformFile file) async {
    if (file.bytes != null && file.bytes!.isNotEmpty) {
      return file.bytes;
    }

    final stream = file.readStream;
    if (stream == null) {
      return null;
    }

    final builder = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  String _invalidFileMessage(AdministrasiFileType fileType) {
    switch (fileType) {
      case AdministrasiFileType.pdf:
        return 'File bukan PDF valid atau rusak.';
      case AdministrasiFileType.docx:
        return 'File DOCX tidak valid atau rusak.';
      case AdministrasiFileType.xlsx:
        return 'File XLSX tidak valid atau rusak.';
      case AdministrasiFileType.unknown:
        return 'Format file tidak dikenali atau tidak didukung.';
    }
  }

  Future<AdministrasiStorageUploadResult?> _pickAndUploadFile() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: AdministrasiFileTypeDetector.allowedExtensions,
      withData: true,
      withReadStream: true,
      allowMultiple: false,
    );

    if (picked == null || picked.files.isEmpty) {
      return null;
    }

    final file = picked.files.single;
    final fileName = file.name.trim();
    final extension = AdministrasiFileTypeDetector.extensionFromName(fileName);
    final fileType = AdministrasiFileTypeDetector.detect(fileName: fileName);

    if (fileName.isEmpty ||
        !AdministrasiFileTypeDetector.isAllowedExtension(extension) ||
        fileType == AdministrasiFileType.unknown) {
      if (!mounted) {
        return null;
      }
      await _showErrorAlert('File tidak didukung. Hanya PDF, DOCX, atau XLSX.');
      return null;
    }

    if (file.size <= 0) {
      if (!mounted) {
        return null;
      }
      await _showErrorAlert(
        'File kosong atau tidak valid. Silakan pilih file lain.',
      );
      return null;
    }

    if (file.size > _maxFileSizeBytes) {
      if (!mounted) {
        return null;
      }
      await _showErrorAlert('Ukuran file maksimal 20 MB.');
      return null;
    }

    setState(() {
      _isUploadingFile = true;
      _uploadProgress = 0;
    });

    final bytes = await _readPickedFileBytes(file);

    if (bytes == null || bytes.isEmpty) {
      if (mounted) {
        await _showErrorAlert('Gagal upload file. Silakan coba lagi.');
        setState(() {
          _isUploadingFile = false;
        });
      }
      return null;
    }

    if (!AdministrasiFileTypeDetector.hasValidSignature(
      fileType: fileType,
      bytes: bytes,
    )) {
      if (mounted) {
        await _showErrorAlert(_invalidFileMessage(fileType));
        setState(() {
          _isUploadingFile = false;
        });
      }
      return null;
    }

    try {
      final uploadResult = await ref
          .read(administrasiGuruSupabaseProvider(widget.guruUid).notifier)
          .uploadAdministrasiFile(
            bytes: bytes,
            fileName: fileName,
            localFilePath: file.path,
            contentType: fileType.mimeType,
            onProgress: (progress) {
              if (!mounted) {
                return;
              }
              if ((progress - _uploadProgress).abs() < 0.02 && progress < 1) {
                return;
              }
              setState(() {
                _uploadProgress = progress;
              });
            },
          );

      return uploadResult;
    } catch (e, stackTrace) {
      debugPrint(
        'Administrasi upload failed for "$fileName" '
        '(size=${file.size}, path=${file.path}): $e',
      );
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        await _showErrorAlert('Gagal menyiapkan file: $e');
      }
      return null;
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingFile = false;
        });
      }
    }
  }

  Future<void> _handleUploadForCreate() async {
    if (!_isSelectedPairValid()) {
      await _showErrorAlert(
        'Kelas dan mata pelajaran tidak sesuai jadwal mengajar Anda.',
      );
      return;
    }

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: AdministrasiFileTypeDetector.allowedExtensions,
      withData: true,
      withReadStream: true,
      allowMultiple: false,
    );

    if (picked == null || picked.files.isEmpty) {
      return;
    }

    final file = picked.files.single;
    final fileName = file.name.trim();
    final extension = AdministrasiFileTypeDetector.extensionFromName(fileName);
    final fileType = AdministrasiFileTypeDetector.detect(fileName: fileName);

    if (fileName.isEmpty ||
        !AdministrasiFileTypeDetector.isAllowedExtension(extension) ||
        fileType == AdministrasiFileType.unknown) {
      await _showErrorAlert('File tidak didukung. Hanya PDF, DOCX, atau XLSX.');
      return;
    }

    if (file.size <= 0) {
      await _showErrorAlert(
        'File kosong atau tidak valid. Silakan pilih file lain.',
      );
      return;
    }

    if (file.size > _maxFileSizeBytes) {
      await _showErrorAlert('Ukuran file maksimal 20 MB.');
      return;
    }

    setState(() {
      _isUploadingFile = true;
      _uploadProgress = 0;
    });

    final bytes = await _readPickedFileBytes(file);
    if (bytes == null || bytes.isEmpty) {
      if (mounted) {
        await _showErrorAlert('Gagal membaca file. Silakan coba lagi.');
        setState(() {
          _isUploadingFile = false;
        });
      }
      return;
    }

    if (!AdministrasiFileTypeDetector.hasValidSignature(
      fileType: fileType,
      bytes: bytes,
    )) {
      if (mounted) {
        await _showErrorAlert(_invalidFileMessage(fileType));
        setState(() {
          _isUploadingFile = false;
        });
      }
      return;
    }

    final uploadResult = await (() async {
      try {
        final stagedResult = await ref
            .read(administrasiGuruSupabaseProvider(widget.guruUid).notifier)
            .stageAdministrasiFile(
              bytes: bytes,
              fileName: fileName,
              localFilePath: file.path,
            );

        if (mounted) {
          setState(() {
            _uploadProgress = 1;
          });
        }

        return stagedResult;
      } catch (e, stackTrace) {
        debugPrint(
          'Administrasi staging failed for "$fileName" '
          '(size=${file.size}, path=${file.path}, bytes=${bytes.length}, '
          'platform=${_debugPlatformLabel()}, hasReadStream=${file.readStream != null}): $e',
        );
        debugPrintStack(stackTrace: stackTrace);
        if (mounted) {
          await _showErrorAlert('Gagal menyiapkan file: $e');
        }
        return null;
      } finally {
        if (mounted) {
          setState(() {
            _isUploadingFile = false;
          });
        }
      }
    })();

    if (uploadResult == null || !mounted) {
      return;
    }

    final previousPath = _selectedFilePath;

    setState(() {
      _selectedFileName = uploadResult.fileName;
      _selectedFileUrl = uploadResult.fileUrl;
      _selectedFilePath = uploadResult.filePath;
      _selectedFileBytes = bytes;
      _selectedFileContentType = fileType.mimeType;
      _uploadProgress = 1;
    });

    if (previousPath != null &&
        previousPath.isNotEmpty &&
        previousPath != uploadResult.filePath) {
      try {
        await ref
            .read(administrasiStorageServiceProvider)
            .deleteStagedFile(previousPath);
      } catch (_) {
        // Cleanup file sementara bersifat best-effort.
      }
    }

    if (!mounted) {
      return;
    }

    await _showSuccessAlert(
      'File berhasil disimpan sementara. Tekan Simpan Dokumen untuk upload ke storage lalu simpan data.',
    );
  }

  Future<void> _replaceAdministrasiFile(AdministrasiGuruItem item) async {
    final uploadResult = await _pickAndUploadFile();
    if (uploadResult == null) {
      return;
    }

    try {
      await ref
          .read(administrasiGuruSupabaseProvider(widget.guruUid).notifier)
          .updateAdministrasi(
            administrasiId: item.id,
            fileName: uploadResult.fileName,
            fileUrl: uploadResult.fileUrl,
            filePath: uploadResult.filePath,
            statusVerifikasi: 'pending',
          );

      if (item.filePath != null &&
          item.filePath!.isNotEmpty &&
          item.filePath != uploadResult.filePath) {
        try {
          await ref
              .read(administrasiStorageServiceProvider)
              .deleteByPath(item.filePath!);
        } catch (_) {
          // File lama gagal dihapus tidak boleh membatalkan update dokumen.
        }
      }

      await _reloadAdministrasi();

      if (!mounted) {
        return;
      }
      await _showSuccessAlert('Dokumen berhasil diperbarui.');
    } catch (e) {
      try {
        await ref
            .read(administrasiStorageServiceProvider)
            .deleteByPath(uploadResult.filePath);
      } catch (_) {
        // Cleanup best-effort jika update Firestore gagal.
      }

      if (!mounted) {
        return;
      }
      await _showErrorAlert('Gagal memperbarui dokumen: $e');
    }
  }

  Future<void> _deleteAdministrasi(AdministrasiGuruItem item) async {
    final shouldDelete = await AppAlert.confirm(
      context,
      title: 'Hapus dokumen ini?',
      message: 'Data yang dihapus tidak dapat dikembalikan.',
      okText: 'Ya, hapus',
      cancelText: 'Batal',
    );

    if (!shouldDelete) {
      return;
    }

    try {
      await ref
          .read(administrasiGuruSupabaseProvider(widget.guruUid).notifier)
          .deleteAdministrasi(item: item);

      if (!mounted) {
        return;
      }
      await _showSuccessAlert('Dokumen berhasil dihapus.');
    } catch (e) {
      if (!mounted) {
        return;
      }
      await _showErrorAlert('Gagal menghapus dokumen: $e');
    }
  }

  Future<void> _openAdministrasiFile(AdministrasiGuruItem item) async {
    await AdministrasiFileOpener.openForView(
      context: context,
      fileUrl: item.fileUrl,
      fileName: item.fileName,
      filePath: item.filePath,
    );
  }

  Future<void> _downloadAdministrasiFile(AdministrasiGuruItem item) async {
    await AdministrasiFileOpener.openForDownload(
      context: context,
      fileUrl: item.fileUrl,
      fileName: item.fileName,
      filePath: item.filePath,
    );
  }

  String _jenisLabel(String jenis) {
    switch (jenis) {
      case 'silabus':
        return 'Silabus';
      case 'program_tahunan':
        return 'Program Tahunan';
      case 'program_semester':
        return 'Program Semester';
      case 'rencana_pembelajaran':
        return 'Rencana Pembelajaran';
      default:
        return jenis;
    }
  }

  String _statusLabel(String? status) {
    switch ((status ?? 'pending').toLowerCase()) {
      case 'verified':
      case 'approved':
      case 'accepted':
      case 'diterima':
      case 'disetujui':
      case 'terverifikasi':
        return 'Diterima';
      case 'rejected':
      case 'ditolak':
        return 'Ditolak';
      case 'revisi':
        return 'Perlu Revisi';
      case 'pending':
      default:
        return 'Menunggu Verifikasi';
    }
  }

  Color _statusBackgroundColor(String? status) {
    switch ((status ?? 'pending').toLowerCase()) {
      case 'verified':
      case 'approved':
      case 'accepted':
      case 'diterima':
      case 'disetujui':
      case 'terverifikasi':
        return const Color(0xFFE8F5E9);
      case 'revisi':
        return const Color(0xFFFFF3E0);
      case 'rejected':
      case 'ditolak':
        return const Color(0xFFFFEBEE);
      case 'pending':
      default:
        return const Color(0xFFFFF8E1);
    }
  }

  Color _statusForegroundColor(String? status) {
    switch ((status ?? 'pending').toLowerCase()) {
      case 'verified':
      case 'approved':
      case 'accepted':
      case 'diterima':
      case 'disetujui':
      case 'terverifikasi':
        return const Color(0xFF2E7D32);
      case 'revisi':
        return const Color(0xFFEF6C00);
      case 'rejected':
      case 'ditolak':
        return const Color(0xFFC62828);
      case 'pending':
      default:
        return const Color(0xFFF9A825);
    }
  }

  Widget _buildStatusBadge(String? status) {
    final label = _statusLabel(status);
    final bg = _statusBackgroundColor(status);
    final fg = _statusForegroundColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withAlpha(70)),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }

  String _formatUploadDate(BuildContext context, DateTime? value) {
    if (value == null) {
      return '-';
    }
    final local = value.toLocal();
    final dateText = MaterialLocalizations.of(context).formatMediumDate(local);
    final timeText = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(local));
    return '$dateText $timeText';
  }

  List<AdministrasiGuruItem> _applyHistoryFilters(
    List<AdministrasiGuruItem> all,
  ) {
    return all.where((item) {
      if (_historyTahunAjaranFilter != _allFilterValue &&
          item.tahunAjaranId != _historyTahunAjaranFilter) {
        return false;
      }
      if (_historyKelasFilter != _allFilterValue &&
          item.kelasId != _historyKelasFilter) {
        return false;
      }
      if (_historyMapelFilter != _allFilterValue &&
          item.mapelId != _historyMapelFilter) {
        return false;
      }
      if (_historySemesterFilter != _allFilterValue &&
          item.semester.toString() != _historySemesterFilter) {
        return false;
      }
      if (_historyJenisFilter != _allFilterValue &&
          item.jenis != _historyJenisFilter) {
        return false;
      }
      final effectiveStatus = (item.statusVerifikasi ?? 'pending')
          .toLowerCase();
      if (_historyStatusFilter != _allFilterValue &&
          effectiveStatus != _historyStatusFilter) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<void> _editAdministrasiMetadata(AdministrasiGuruItem item) async {
    String selectedJenis = item.jenis;
    int selectedSemester = item.semester;

    final isSaved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) {
          return AlertDialog(
            title: const Text('Edit Metadata Dokumen'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedJenis,
                  decoration: const InputDecoration(
                    labelText: 'Jenis Dokumen',
                    border: OutlineInputBorder(),
                  ),
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem<String>(
                      value: 'silabus',
                      child: Text('Silabus'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'program_tahunan',
                      child: Text('Program Tahunan'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'program_semester',
                      child: Text('Program Semester'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'rencana_pembelajaran',
                      child: Text('Rencana Pembelajaran'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setLocalState(() {
                      selectedJenis = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: selectedSemester,
                  decoration: const InputDecoration(
                    labelText: 'Semester',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('Semester 1')),
                    DropdownMenuItem(value: 2, child: Text('Semester 2')),
                  ],
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setLocalState(() {
                      selectedSemester = value;
                    });
                  },
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
      ),
    );

    if (isSaved != true) {
      return;
    }

    try {
      await ref
          .read(administrasiGuruSupabaseProvider(widget.guruUid).notifier)
          .updateAdministrasi(
            administrasiId: item.id,
            jenis: selectedJenis,
            semester: selectedSemester,
            statusVerifikasi: 'pending',
          );
      if (!mounted) {
        return;
      }
      await _showSuccessAlert('Dokumen berhasil diperbarui.');
    } catch (e) {
      if (!mounted) {
        return;
      }
      await _showErrorAlert('Gagal memperbarui metadata: $e');
    }
  }

  Widget _buildInputTab(
    AdministrasiGuruState state,
    TahunAjaranGuruState tahunAjaranState,
    JadwalGuruFilterState jadwalState,
  ) {
    final List<DropdownMenuItem<String>> tahunAjaranItems =
        tahunAjaranState.options.isEmpty
        ? const <DropdownMenuItem<String>>[]
        : List<DropdownMenuItem<String>>.from(
            tahunAjaranState.options.map<DropdownMenuItem<String>>(
              (item) => DropdownMenuItem<String>(
                value: item.id,
                child: Text(item.nama),
              ),
            ),
            growable: false,
          );

    final List<DropdownMenuItem<String>> kelasItems = _kelasOptions.isEmpty
        ? const <DropdownMenuItem<String>>[]
        : List<DropdownMenuItem<String>>.from(
            _kelasOptions.map<DropdownMenuItem<String>>(
              (item) => DropdownMenuItem<String>(
                value: item.id,
                child: Text(item.label),
              ),
            ),
            growable: false,
          );

    final List<DropdownMenuItem<String>> mapelItems = _mapelOptions.isEmpty
        ? const <DropdownMenuItem<String>>[]
        : List<DropdownMenuItem<String>>.from(
            _mapelOptions.map<DropdownMenuItem<String>>(
              (item) => DropdownMenuItem<String>(
                value: item.id,
                child: Text(item.label),
              ),
            ),
            growable: false,
          );

    final String? selectedTahunAjaranValue =
        tahunAjaranItems.any(
          (item) => item.value == tahunAjaranState.selectedTahunAjaranId,
        )
        ? tahunAjaranState.selectedTahunAjaranId
        : null;

    final String? selectedKelasValue =
        kelasItems.any((item) => item.value == _selectedKelasId)
        ? _selectedKelasId
        : null;

    final String? selectedMapelValue =
        mapelItems.any((item) => item.value == _selectedMapelId)
        ? _selectedMapelId
        : null;

    final bool isInputDropdownLoading =
        tahunAjaranState.isLoading || jadwalState.isLoading;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (tahunAjaranState.isLoading)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
                if (tahunAjaranState.error != null &&
                    tahunAjaranState.error!.isNotEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.error.withAlpha(70)),
                    ),
                    child: Text(
                      tahunAjaranState.error!,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
                if (jadwalState.isLoading)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
                if (!jadwalState.isLoading && jadwalState.data.isEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.error.withAlpha(70)),
                    ),
                    child: const Text(
                      'Tidak ada jadwal mengajar pada tahun ajaran ini',
                      style: TextStyle(color: AppColors.error),
                    ),
                  ),
                const Text(
                  'Input Dokumen',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (tahunAjaranState.lockSelection)
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Tahun Ajaran',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.school),
                    ),
                    child: Text(tahunAjaranState.selectedOption?.nama ?? '-'),
                  )
                else
                  DropdownButtonFormField<String>(
                    initialValue: selectedTahunAjaranValue,
                    decoration: const InputDecoration(
                      labelText: 'Tahun Ajaran',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.school),
                    ),
                    items: tahunAjaranItems,
                    onChanged:
                        isInputDropdownLoading || tahunAjaranItems.isEmpty
                        ? null
                        : _onTahunAjaranChanged,
                  ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedKelasValue,
                  decoration: const InputDecoration(
                    labelText: 'Kelas',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.class_),
                  ),
                  items: kelasItems,
                  onChanged: isInputDropdownLoading || kelasItems.isEmpty
                      ? null
                      : _onKelasChanged,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedMapelValue,
                  decoration: const InputDecoration(
                    labelText: 'Mata Pelajaran',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.book),
                  ),
                  items: mapelItems,
                  onChanged: isInputDropdownLoading || mapelItems.isEmpty
                      ? null
                      : (value) {
                          setState(() {
                            _selectedMapelId = value;
                          });
                        },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _selectedSemester,
                  decoration: const InputDecoration(
                    labelText: 'Semester',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_month),
                  ),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('Semester 1')),
                    DropdownMenuItem(value: 2, child: Text('Semester 2')),
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
                DropdownButtonFormField<String>(
                  initialValue: _selectedJenis,
                  decoration: const InputDecoration(
                    labelText: 'Jenis Dokumen',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem<String>(
                      value: 'silabus',
                      child: Text('Silabus'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'program_tahunan',
                      child: Text('Program Tahunan'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'program_semester',
                      child: Text('Program Semester'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'rencana_pembelajaran',
                      child: Text('Rencana Pembelajaran'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _selectedJenis = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _isUploadingFile || !_isSelectedPairValid()
                      ? null
                      : _handleUploadForCreate,
                  icon: _isUploadingFile
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file),
                  label: Text(
                    _isUploadingFile
                        ? 'Uploading...'
                        : 'Upload File (PDF/DOCX/XLSX)',
                  ),
                ),
                if (_isUploadingFile) ...[
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: _uploadProgress),
                ],
                if (_selectedFileName != null) ...[
                  const SizedBox(height: 12),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'File Terpilih',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.insert_drive_file),
                    ),
                    child: Text(_selectedFileName!),
                  ),
                ],
                if (_selectedFileUrl != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'File sudah disimpan sementara di sistem dan akan di-upload saat Anda menekan Simpan Dokumen.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _saveAdministrasi,
                  icon: const Icon(Icons.save),
                  label: const Text('Simpan Dokumen'),
                ),
              ],
            ),
          ),
        ),
        if (state.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              state.error!,
              style: const TextStyle(color: Colors.red),
            ),
          ),
      ],
    );
  }

  Widget _buildHistoryTab(
    AdministrasiGuruState state,
    TahunAjaranGuruState tahunAjaranState,
    JadwalGuruFilterState jadwalState,
  ) {
    final tahunAjaranMap = {
      for (final item in tahunAjaranState.options) item.id: item.nama,
    };

    final filteredData = _applyHistoryFilters(state.data);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _buildExternalHistoryFilterBar(
            state,
            tahunAjaranState,
            jadwalState,
          ),
        ),
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withAlpha(26),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Text(
                  'Riwayat Dokumen (${filteredData.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: Divider(height: 1)),
        if (state.isLoading && state.data.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (state.data.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Belum ada dokumen diunggah',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                SizedBox(height: 64),
              ],
            ),
          )
        else if (filteredData.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                
                Text(
                  'Belum ada dokumen pada filter ini.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                SizedBox(height: 32),
              ],
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList.builder(
              itemCount: filteredData.length,
              itemBuilder: (context, index) {
                final item = filteredData[index];
                final tahunAjaranNama =
                    tahunAjaranMap[item.tahunAjaranId] ?? item.tahunAjaranId;

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.fileName ?? item.jenis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('Mata Pelajaran: ${item.mapelNama}'),
                        Text('Kelas: ${item.kelasNama}'),
                        Text('Tahun Ajaran: $tahunAjaranNama'),
                        Text('Semester: ${item.semester}'),
                        Text('Jenis Dokumen: ${_jenisLabel(item.jenis)}'),
                        Row(
                          children: [
                            const Text('Status Verifikasi: '),
                            _buildStatusBadge(item.statusVerifikasi),
                          ],
                        ),
                        if (item.catatanVerifikasi != null &&
                            item.catatanVerifikasi!.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 4),
                            child: Text(
                              'Catatan: ${item.catatanVerifikasi}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[700],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                        Text(
                          'Tanggal Upload: ${_formatUploadDate(context, item.createdAt)}',
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: () => _openAdministrasiFile(item),
                              icon: const Icon(Icons.visibility),
                              label: const Text('Lihat File'),
                            ),
                            PopupMenuButton<String>(
                              tooltip: 'Aksi',
                              onSelected: (value) async {
                                if (value == 'edit') {
                                  await _editAdministrasiMetadata(item);
                                  return;
                                }
                                if (value == 'replace') {
                                  await _replaceAdministrasiFile(item);
                                  return;
                                }
                                if (value == 'download') {
                                  await _downloadAdministrasiFile(item);
                                  return;
                                }
                                if (value == 'delete') {
                                  await _deleteAdministrasi(item);
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem<String>(
                                  value: 'edit',
                                  child: Text('Edit Metadata'),
                                ),
                                PopupMenuItem<String>(
                                  value: 'replace',
                                  child: Text('Ganti File'),
                                ),
                                PopupMenuItem<String>(
                                  value: 'download',
                                  child: Text('Download'),
                                ),
                                PopupMenuItem<String>(
                                  value: 'delete',
                                  child: Text('Hapus'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  List<_DropdownOption> _buildHistoryMapelOptions(
    JadwalGuruFilterState jadwalState,
  ) {
    final filteredRows = _historyKelasFilter == _allFilterValue
        ? jadwalState.data
        : jadwalState.data
              .where((row) => row.kelasId == _historyKelasFilter)
              .toList();

    final mapelMap = <String, String>{
      for (final row in filteredRows) row.mapelId: row.mapelNama,
    };

    final options =
        mapelMap.entries
            .map((item) => _DropdownOption(id: item.key, label: item.value))
            .toList()
          ..sort((a, b) => a.label.compareTo(b.label));

    return <_DropdownOption>[
      const _DropdownOption(id: _allFilterValue, label: 'Semua Mata Pelajaran'),
      ...options,
    ];
  }

  Widget _buildExternalHistoryFilterBar(
    AdministrasiGuruState state,
    TahunAjaranGuruState tahunAjaranState,
    JadwalGuruFilterState jadwalState,
  ) {
    final kelasFilterOptions = <_DropdownOption>[
      const _DropdownOption(id: _allFilterValue, label: 'Semua Kelas'),
      ..._kelasOptions,
    ];

    final mapelFilterOptions = _buildHistoryMapelOptions(jadwalState);

    final statusSet =
        state.data
            .map((item) => (item.statusVerifikasi ?? 'pending').toLowerCase())
            .toSet()
          ..add('pending');

    final statusOptions = <_DropdownOption>[
      const _DropdownOption(id: _allFilterValue, label: 'Semua Status'),
      ...statusSet.map(
        (item) => _DropdownOption(id: item, label: _statusLabel(item)),
      ),
    ];

    final tahunAjaranValue =
        (tahunAjaranState.options.any(
              (item) => item.id == _historyTahunAjaranFilter,
            ) ||
            _historyTahunAjaranFilter == _allFilterValue)
        ? _historyTahunAjaranFilter
        : _allFilterValue;

    final kelasValue =
        kelasFilterOptions.any((item) => item.id == _historyKelasFilter)
        ? _historyKelasFilter
        : _allFilterValue;

    final mapelValue =
        mapelFilterOptions.any((item) => item.id == _historyMapelFilter)
        ? _historyMapelFilter
        : _allFilterValue;

    final jenisValue =
        const {
          _allFilterValue,
          'silabus',
          'program_tahunan',
          'program_semester',
          'rencana_pembelajaran',
        }.contains(_historyJenisFilter)
        ? _historyJenisFilter
        : _allFilterValue;

    final statusValue =
        statusOptions.any((item) => item.id == _historyStatusFilter)
        ? _historyStatusFilter
        : _allFilterValue;

    return AppExternalFilterBar(
      title: 'Filter Riwayat Dokumen',
      margin: const EdgeInsets.fromLTRB(11, 12, 11, 8),
      isExpanded: _isHistoryFilterVisible,
      onToggle: () {
        setState(() {
          _isHistoryFilterVisible = !_isHistoryFilterVisible;
        });
      },
      onReset: () {
        setState(() {
          _historyTahunAjaranFilter = _allFilterValue;
          _historyKelasFilter = _allFilterValue;
          _historyMapelFilter = _allFilterValue;
          _historySemesterFilter = _allFilterValue;
          _historyJenisFilter = _allFilterValue;
          _historyStatusFilter = _allFilterValue;
        });
      },
      onApply: () {
        setState(() {});
      },
      showApplyButton: true,
      isBusy: state.isLoading,
      children: [
        AppExternalFilterField(
          label: 'Tahun Ajaran',
          child: DropdownButtonFormField<String>(
            initialValue: tahunAjaranValue,
            decoration: appExternalFilterDecoration(
              hintText: 'Semua tahun ajaran',
              icon: Icons.school_rounded,
            ),
            items: [
              const DropdownMenuItem<String>(
                value: _allFilterValue,
                child: Text('Semua Tahun Ajaran'),
              ),
              ...tahunAjaranState.options.map(
                (item) => DropdownMenuItem<String>(
                  value: item.id,
                  child: Text(item.nama),
                ),
              ),
            ],
            onChanged: (value) {
              setState(() {
                _historyTahunAjaranFilter = value ?? _allFilterValue;
              });
            },
          ),
        ),
        AppExternalFilterField(
          label: 'Semester',
          child: DropdownButtonFormField<String>(
            initialValue: _historySemesterFilter,
            decoration: appExternalFilterDecoration(
              hintText: 'Semua semester',
              icon: Icons.calendar_month_rounded,
            ),
            items: const [
              DropdownMenuItem<String>(
                value: _allFilterValue,
                child: Text('Semua Semester'),
              ),
              DropdownMenuItem<String>(value: '1', child: Text('Semester 1')),
              DropdownMenuItem<String>(value: '2', child: Text('Semester 2')),
            ],
            onChanged: (value) {
              setState(() {
                _historySemesterFilter = value ?? _allFilterValue;
              });
            },
          ),
        ),
        AppExternalFilterField(
          label: 'Kelas',
          child: DropdownButtonFormField<String>(
            initialValue: kelasValue,
            decoration: appExternalFilterDecoration(
              hintText: 'Semua kelas',
              icon: Icons.class_rounded,
            ),
            items: kelasFilterOptions
                .map(
                  (item) => DropdownMenuItem<String>(
                    value: item.id,
                    child: Text(item.label),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() {
                _historyKelasFilter = value ?? _allFilterValue;
                final nextMapelOptions = _buildHistoryMapelOptions(jadwalState);
                if (!nextMapelOptions.any(
                  (item) => item.id == _historyMapelFilter,
                )) {
                  _historyMapelFilter = _allFilterValue;
                }
              });
            },
          ),
        ),
        AppExternalFilterField(
          label: 'Mata Pelajaran',
          child: DropdownButtonFormField<String>(
            initialValue: mapelValue,
            decoration: appExternalFilterDecoration(
              hintText: 'Semua mata pelajaran',
              icon: Icons.menu_book_rounded,
            ),
            items: mapelFilterOptions
                .map(
                  (item) => DropdownMenuItem<String>(
                    value: item.id,
                    child: Text(item.label),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() {
                _historyMapelFilter = value ?? _allFilterValue;
              });
            },
          ),
        ),
        AppExternalFilterField(
          label: 'Jenis Dokumen',
          child: DropdownButtonFormField<String>(
            initialValue: jenisValue,
            decoration: appExternalFilterDecoration(
              hintText: 'Semua jenis dokumen',
              icon: Icons.description_rounded,
            ),
            items: const [
              DropdownMenuItem<String>(
                value: _allFilterValue,
                child: Text('Semua Jenis'),
              ),
              DropdownMenuItem<String>(
                value: 'silabus',
                child: Text('Silabus'),
              ),
              DropdownMenuItem<String>(
                value: 'program_tahunan',
                child: Text('Program Tahunan'),
              ),
              DropdownMenuItem<String>(
                value: 'program_semester',
                child: Text('Program Semester'),
              ),
              DropdownMenuItem<String>(
                value: 'rencana_pembelajaran',
                child: Text('Rencana Pembelajaran'),
              ),
            ],
            onChanged: (value) {
              setState(() {
                _historyJenisFilter = value ?? _allFilterValue;
              });
            },
          ),
        ),
        AppExternalFilterField(
          label: 'Status Verifikasi',
          child: DropdownButtonFormField<String>(
            initialValue: statusValue,
            decoration: appExternalFilterDecoration(
              hintText: 'Semua status',
              icon: Icons.verified_user_rounded,
            ),
            items: statusOptions
                .map(
                  (item) => DropdownMenuItem<String>(
                    value: item.id,
                    child: Text(item.label),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() {
                _historyStatusFilter = value ?? _allFilterValue;
              });
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(administrasiGuruSupabaseProvider(widget.guruUid));
    final tahunAjaranState = ref.watch(tahunAjaranProvider);
    final jadwalState = ref.watch(jadwalGuruProvider(widget.guruUid));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Administrasi Pembelajaran'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'Input Dokumen'),
              Tab(text: 'Riwayat Dokumen'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => _loadReferenceData(forceRefreshData: true),
              child: const Text(
                'Refresh',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Builder(
          builder: (context) {
            return Column(
              children: [
                if (state.isLoading) const LinearProgressIndicator(),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildInputTab(state, tahunAjaranState, jadwalState),
                      _buildHistoryTab(state, tahunAjaranState, jadwalState),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
