import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../screens/pdf_viewer_screen.dart';
import 'administrasi_file_type.dart';

class AdministrasiFileOpener {
  const AdministrasiFileOpener._();

  static Future<void> openForView({
    required BuildContext context,
    required String? fileUrl,
    required String? fileName,
    String? filePath,
  }) async {
    await _openInternal(
      context: context,
      fileUrl: fileUrl,
      fileName: fileName,
      filePath: filePath,
      forceExternal: false,
    );
  }

  static Future<void> openForDownload({
    required BuildContext context,
    required String? fileUrl,
    required String? fileName,
    String? filePath,
  }) async {
    await _openInternal(
      context: context,
      fileUrl: fileUrl,
      fileName: fileName,
      filePath: filePath,
      forceExternal: true,
    );
  }

  static Future<void> _openInternal({
    required BuildContext context,
    required String? fileUrl,
    required String? fileName,
    required String? filePath,
    required bool forceExternal,
  }) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final navigator = Navigator.of(context);
    final rawUrl = (fileUrl ?? '').trim();
    if (rawUrl.isEmpty) {
      _showError(messenger, 'File belum tersedia. URL file kosong.');
      return;
    }

    final uri = Uri.tryParse(rawUrl);
    if (uri == null || (!uri.hasScheme && !uri.hasAuthority)) {
      _showError(messenger, 'URL file tidak valid.');
      return;
    }

    final fileType = AdministrasiFileTypeDetector.detect(
      fileName: fileName,
      fileUrl: rawUrl,
    );

    if (!forceExternal &&
        _shouldOpenInPdfViewer(
          fileType: fileType,
          fileName: fileName,
          fileUrl: rawUrl,
          filePath: filePath,
        )) {
      await navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => PdfViewerScreen(
            fileUrl: rawUrl,
            fileName: fileName,
            filePath: filePath,
          ),
        ),
      );
      return;
    }

    try {
      final openedExternal = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (openedExternal) {
        return;
      }

      final openedFallback = await launchUrl(
        uri,
        mode: LaunchMode.platformDefault,
      );
      if (!openedFallback) {
        _showError(messenger, 'Gagal membuka file. Coba lagi beberapa saat.');
      }
    } catch (e) {
      _showError(messenger, 'Gagal membuka file: $e');
    }
  }

  static void _showError(ScaffoldMessengerState? messenger, String message) {
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }

  static bool _shouldOpenInPdfViewer({
    required AdministrasiFileType fileType,
    required String? fileName,
    required String? fileUrl,
    required String? filePath,
  }) {
    if (fileType.opensInApp) {
      return true;
    }

    if (_containsPdfMarker(fileName) ||
        _containsPdfMarker(fileUrl) ||
        _containsPdfMarker(filePath)) {
      return true;
    }

    return fileType == AdministrasiFileType.unknown &&
        (filePath ?? '').trim().isNotEmpty;
  }

  static bool _containsPdfMarker(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) {
      return false;
    }

    final uri = Uri.tryParse(raw);
    final candidate =
        ((uri != null && uri.pathSegments.isNotEmpty)
                ? uri.pathSegments.last
                : raw.split('/').last)
            .trim()
            .toLowerCase();

    return candidate.endsWith('.pdf') || candidate.contains('.pdf?');
  }
}
