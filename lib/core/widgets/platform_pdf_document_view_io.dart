import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class PlatformPdfDocumentView extends StatelessWidget {
  final Uint8List bytes;
  final String? networkUrl;
  final String? localFilePath;
  final void Function(dynamic details)? onDocumentLoadFailed;

  const PlatformPdfDocumentView({
    super.key,
    required this.bytes,
    this.networkUrl,
    this.localFilePath,
    this.onDocumentLoadFailed,
  });

  @override
  Widget build(BuildContext context) {
    final trimmedLocalPath = (localFilePath ?? '').trim();
    if (trimmedLocalPath.isNotEmpty) {
      return SfPdfViewer.file(
        File(trimmedLocalPath),
        onDocumentLoadFailed: onDocumentLoadFailed,
      );
    }

    final trimmedUrl = (networkUrl ?? '').trim();
    if (trimmedUrl.isNotEmpty) {
      return SfPdfViewer.network(
        trimmedUrl,
        onDocumentLoadFailed: onDocumentLoadFailed,
      );
    }

    return SfPdfViewer.memory(
      bytes,
      onDocumentLoadFailed: onDocumentLoadFailed,
    );
  }
}