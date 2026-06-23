import 'dart:io';
import 'dart:typed_data';

Future<String?> resolveLocalAdministrasiPath({
  required Uint8List bytes,
  required String fileName,
  String? preferredPath,
}) async {
  final trimmed = (preferredPath ?? '').trim();
  if (trimmed.isNotEmpty) {
    return trimmed;
  }

  final sanitizedName = _sanitizeFileName(fileName);
  final separator = Platform.pathSeparator;
  final directory = Directory(
    '${Directory.systemTemp.path}${separator}pengawasan_kelas_administrasi',
  );
  if (!await directory.exists()) {
    await directory.create(recursive: true);
  }

  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final fileNameWithTimestamp = '${timestamp}_$sanitizedName';
  final targetPath = '${directory.path}$separator$fileNameWithTimestamp';
  final targetFile = File(targetPath);
  await targetFile.writeAsBytes(bytes, flush: true);
  return targetFile.path;
}

Future<void> deleteLocalAdministrasiPath(String path) async {
  final trimmed = path.trim();
  if (trimmed.isEmpty) {
    return;
  }

  final file = File(trimmed);
  if (await file.exists()) {
    await file.delete();
  }
}

String _sanitizeFileName(String fileName) {
  final trimmed = fileName.trim();
  if (trimmed.isEmpty) {
    return 'dokumen.bin';
  }

  final sanitized = trimmed.replaceAll(RegExp(r'[<>:"/\\|?*]+'), '_');
  return sanitized.isEmpty ? 'dokumen.bin' : sanitized;
}
