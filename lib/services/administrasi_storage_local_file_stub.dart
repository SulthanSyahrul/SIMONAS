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
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  return 'memory://pengawasan_kelas_administrasi/${timestamp}_$sanitizedName';
}

Future<void> deleteLocalAdministrasiPath(String path) async {}

String _sanitizeFileName(String fileName) {
  final trimmed = fileName.trim();
  if (trimmed.isEmpty) {
    return 'dokumen.bin';
  }

  final sanitized = trimmed.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
  return sanitized.isEmpty ? 'dokumen.bin' : sanitized;
}
