// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:ui_web' as ui_web;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:html' as html;

class PlatformPdfDocumentView extends StatefulWidget {
  final Uint8List bytes;
  final void Function(dynamic details)? onDocumentLoadFailed;

  const PlatformPdfDocumentView({
    super.key,
    required this.bytes,
    this.onDocumentLoadFailed,
  });

  @override
  State<PlatformPdfDocumentView> createState() =>
      _PlatformPdfDocumentViewState();
}

class _PlatformPdfDocumentViewState extends State<PlatformPdfDocumentView> {
  late final String _viewType;
  late final String _objectUrl;

  @override
  void initState() {
    super.initState();
    _viewType = 'pdf-view-${DateTime.now().microsecondsSinceEpoch}';
    final blob = html.Blob(<dynamic>[widget.bytes], 'application/pdf');
    _objectUrl = html.Url.createObjectUrlFromBlob(blob);
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      return html.IFrameElement()
        ..src = _objectUrl
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..setAttribute('title', 'PDF Viewer')
        ..allowFullscreen = true;
    });
  }

  @override
  void dispose() {
    html.Url.revokeObjectUrl(_objectUrl);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(
      key: ValueKey<String>(_viewType),
      viewType: _viewType,
    );
  }
}
