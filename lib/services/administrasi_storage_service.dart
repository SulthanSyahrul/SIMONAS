import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/supabase_config.dart';
import 'administrasi_storage_local_file.dart' as local_file;

class AdministrasiStorageUploadResult {
  final String fileName;
  final String fileUrl;
  final String filePath;

  const AdministrasiStorageUploadResult({
    required this.fileName,
    required this.fileUrl,
    required this.filePath,
  });
}

class AdministrasiStorageService {
  Future<AdministrasiStorageUploadResult> stageFile({
    required Uint8List bytes,
    required String fileName,
    String? localFilePath,
  }) async {
    final normalizedName = fileName.trim();
    if (bytes.isEmpty) {
      throw Exception('File kosong.');
    }
    if (normalizedName.isEmpty) {
      throw Exception('Nama file tidak valid.');
    }

    try {
      debugPrint(
        'Administrasi stage start: '
        'fileName="$normalizedName", '
        'bytes=${bytes.length}, '
        'platform=${_platformLabel()}, '
        'preferredPath=${(localFilePath ?? '').trim().isEmpty ? '<empty>' : localFilePath}',
      );

      final stagedPath = (await local_file.resolveLocalAdministrasiPath(
        bytes: bytes,
        fileName: normalizedName,
        preferredPath: localFilePath,
      ))?.trim();
      if (stagedPath == null || stagedPath.isEmpty) {
        throw Exception(
          'File sementara gagal disimpan ke sistem. '
          'platform=${_platformLabel()}, '
          'preferredPath=${(localFilePath ?? '').trim().isEmpty ? '<empty>' : localFilePath}',
        );
      }

      debugPrint(
        'Administrasi stage success: '
        'fileName="$normalizedName", stagedPath="$stagedPath"',
      );

      return AdministrasiStorageUploadResult(
        fileName: normalizedName,
        fileUrl: stagedPath.startsWith('memory://')
            ? stagedPath
            : Uri.file(stagedPath).toString(),
        filePath: stagedPath,
      );
    } catch (error, stackTrace) {
      debugPrint(
        'Administrasi stage failed: '
        'fileName="$normalizedName", '
        'bytes=${bytes.length}, '
        'platform=${_platformLabel()}, '
        'preferredPath=${(localFilePath ?? '').trim().isEmpty ? '<empty>' : localFilePath}, '
        'error=$error',
      );
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<AdministrasiStorageUploadResult> uploadBytes({
    required Uint8List bytes,
    required String fileName,
    String? localFilePath,
    String? contentType,
    void Function(double progress)? onProgress,
  }) async {
    final normalizedName = fileName.trim();
    if (bytes.isEmpty) {
      throw Exception('File kosong.');
    }
    if (normalizedName.isEmpty) {
      throw Exception('Nama file tidak valid.');
    }

    final authUser = Supabase.instance.client.auth.currentUser;
    if (authUser == null) {
      throw Exception('Session auth tidak ditemukan untuk upload storage.');
    }

    final storagePath = _buildStoragePath(
      authUserId: authUser.id,
      fileName: normalizedName,
    );
    final bucket = Supabase.instance.client.storage.from(
      SupabaseConfig.storageBucket,
    );

    try {
      onProgress?.call(0.1);
      await bucket.uploadBinary(
        storagePath,
        bytes,
        fileOptions: FileOptions(
          contentType: contentType ?? 'application/octet-stream',
          upsert: true,
        ),
      );
      onProgress?.call(1);

      return AdministrasiStorageUploadResult(
        fileName: normalizedName,
        fileUrl: bucket.getPublicUrl(storagePath),
        filePath: storagePath,
      );
    } on StorageException catch (error) {
      throw Exception(
        'Upload ke storage gagal: ${error.message.isEmpty ? error.toString() : error.message}',
      );
    } catch (error) {
      throw Exception('Upload file gagal: $error');
    }
  }

  Future<void> deleteByPath(String path) async {
    final normalizedPath = path.trim();
    if (normalizedPath.isEmpty) {
      return;
    }

    if (_looksLikeLocalPath(normalizedPath)) {
      await deleteStagedFile(normalizedPath);
      return;
    }

    try {
      await Supabase.instance.client.storage
          .from(SupabaseConfig.storageBucket)
          .remove([normalizedPath]);
    } catch (_) {
      // Penghapusan file bersifat best-effort.
    }
  }

  String _buildStoragePath({
    required String authUserId,
    required String fileName,
  }) {
    final now = DateTime.now().toUtc();
    final sanitizedName = _sanitizeStorageFileName(fileName);
    final timestamp = now.millisecondsSinceEpoch;
    final safeAuthUserId = authUserId.replaceAll(
      RegExp(r'[^A-Za-z0-9-]+'),
      '',
    );
    return '$safeAuthUserId/guru_administrasi/${now.year}/${now.month.toString().padLeft(2, '0')}/${timestamp}_$sanitizedName';
  }

  String _sanitizeStorageFileName(String fileName) {
    final trimmed = fileName.trim();
    if (trimmed.isEmpty) {
      return 'dokumen.bin';
    }

    final dotIndex = trimmed.lastIndexOf('.');
    final hasExtension = dotIndex > 0 && dotIndex < trimmed.length - 1;
    final baseName = hasExtension ? trimmed.substring(0, dotIndex) : trimmed;
    final extension = hasExtension ? trimmed.substring(dotIndex + 1) : 'bin';

    final safeBase = baseName
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^[_\.]+|[_\.]+$'), '');
    final safeExtension = extension
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '')
        .toLowerCase();

    final normalizedBase = safeBase.isEmpty ? 'dokumen' : safeBase;
    final normalizedExtension = safeExtension.isEmpty ? 'bin' : safeExtension;
    return '$normalizedBase.$normalizedExtension';
  }

  bool _looksLikeLocalPath(String path) {
    final trimmed = path.trim();
    return trimmed.startsWith('file:') ||
        trimmed.startsWith('/') ||
        trimmed.startsWith('\\') ||
        RegExp(r'^[A-Za-z]:[\\/]').hasMatch(trimmed);
  }

  Future<void> deleteStagedFile(String path) async {
    final normalizedPath = path.trim();
    if (normalizedPath.isEmpty || !_looksLikeLocalPath(normalizedPath)) {
      return;
    }

    final localPath = normalizedPath.startsWith('file:')
        ? (Uri.tryParse(normalizedPath)?.toFilePath() ?? '')
        : normalizedPath;
    if (localPath.isEmpty) {
      return;
    }

    await local_file.deleteLocalAdministrasiPath(localPath);
  }

  String? extractLocalFilePath(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty || !_looksLikeLocalPath(trimmed)) {
      return null;
    }
    if (trimmed.startsWith('file:')) {
      return Uri.tryParse(trimmed)?.toFilePath();
    }
    return trimmed;
  }

  String _platformLabel() {
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
}

final administrasiStorageServiceProvider = Provider<AdministrasiStorageService>(
  (ref) => AdministrasiStorageService(),
);
