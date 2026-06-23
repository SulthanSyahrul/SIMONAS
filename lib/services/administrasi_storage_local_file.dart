import 'dart:typed_data';

import 'administrasi_storage_local_file_stub.dart'
    if (dart.library.io) 'administrasi_storage_local_file_io.dart' as impl;

Future<String?> resolveLocalAdministrasiPath({
  required Uint8List bytes,
  required String fileName,
  String? preferredPath,
}) {
  return impl.resolveLocalAdministrasiPath(
    bytes: bytes,
    fileName: fileName,
    preferredPath: preferredPath,
  );
}

Future<void> deleteLocalAdministrasiPath(String path) {
  return impl.deleteLocalAdministrasiPath(path);
}
