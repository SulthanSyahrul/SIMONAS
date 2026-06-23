import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../utils/administrasi_file_type.dart';
import '../widgets/platform_pdf_document_view.dart';

class PdfViewerScreen extends StatefulWidget {
  final String fileUrl;
  final String? fileName;
  final String? filePath;

  const PdfViewerScreen({
    super.key,
    required this.fileUrl,
    this.fileName,
    this.filePath,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  bool _errorShown = false;
  late final Future<Uint8List> _pdfBytesFuture;

  @override
  void initState() {
    super.initState();
    _pdfBytesFuture = _loadPdfBytes();
  }

  String? _resolveStoragePath() {
    final explicitPath = (widget.filePath ?? '').trim();
    if (explicitPath.isNotEmpty) {
      return explicitPath;
    }

    final rawUrl = widget.fileUrl.trim();
    if (rawUrl.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(rawUrl);
    if (uri == null) {
      return null;
    }

    final segments = uri.pathSegments;
    final objectIndex = segments.indexOf('object');
    if (objectIndex < 0 || objectIndex >= segments.length - 1) {
      return null;
    }

    var bucketIndex = objectIndex + 1;
    if (segments[bucketIndex] == 'public' ||
        segments[bucketIndex] == 'authenticated' ||
        segments[bucketIndex] == 'sign') {
      bucketIndex++;
    }

    if (bucketIndex >= segments.length) {
      return null;
    }

    final bucketName = segments[bucketIndex];
    if (bucketName != SupabaseConfig.storageBucket) {
      return null;
    }

    final pathStartIndex = bucketIndex + 1;
    if (pathStartIndex >= segments.length) {
      return null;
    }

    return segments.sublist(pathStartIndex).join('/');
  }

  Future<Uint8List> _loadPdfBytes() async {
    final trimmedFilePath = (_resolveStoragePath() ?? '').trim();
    if (trimmedFilePath.isNotEmpty) {
      try {
        debugPrint('Loading PDF from Supabase path: $trimmedFilePath');
        final bytes = await Supabase.instance.client.storage
            .from(SupabaseConfig.storageBucket)
            .download(trimmedFilePath);
        if (AdministrasiFileTypeDetector.hasValidSignature(
          fileType: AdministrasiFileType.pdf,
          bytes: bytes,
        )) {
          debugPrint('Loaded PDF bytes from storage: ${bytes.length}');
          return bytes;
        }
        debugPrint('Storage response is not a valid PDF for: $trimmedFilePath');
      } catch (e) {
        debugPrint('Failed to load PDF from storage path: $e');
      }
    }

    final uri = Uri.parse(widget.fileUrl);
    debugPrint('Loading PDF from URL: $uri');
    final byteData = await NetworkAssetBundle(uri).load(uri.toString());
    final bytes = byteData.buffer.asUint8List(
      byteData.offsetInBytes,
      byteData.lengthInBytes,
    );

    if (!AdministrasiFileTypeDetector.hasValidSignature(
      fileType: AdministrasiFileType.pdf,
      bytes: bytes,
    )) {
      debugPrint('URL response is not a valid PDF: $uri');
      throw const FormatException('invalid_pdf');
    }

    debugPrint('Loaded PDF bytes from URL: ${bytes.length}');
    return bytes;
  }

  void _showInvalidPdfError() {
    if (_errorShown || !mounted) {
      return;
    }

    _errorShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File bukan PDF valid atau rusak')),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = (widget.fileName ?? '').trim().isEmpty
        ? 'Lihat File PDF'
        : widget.fileName!.trim();

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: FutureBuilder<Uint8List>(
        future: _pdfBytesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError ||
              !snapshot.hasData ||
              snapshot.data!.isEmpty) {
            _showInvalidPdfError();
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.picture_as_pdf_outlined,
                      size: 72,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'File bukan PDF valid atau rusak',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            );
          }

          return PlatformPdfDocumentView(
            bytes: snapshot.data!,
            onDocumentLoadFailed: (details) {
              _showInvalidPdfError();
            },
          );
        },
      ),
    );
  }
}
