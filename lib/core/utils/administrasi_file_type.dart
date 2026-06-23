import 'dart:typed_data';

enum AdministrasiFileType { pdf, docx, xlsx, unknown }

extension AdministrasiFileTypeX on AdministrasiFileType {
  String get extension {
    switch (this) {
      case AdministrasiFileType.pdf:
        return 'pdf';
      case AdministrasiFileType.docx:
        return 'docx';
      case AdministrasiFileType.xlsx:
        return 'xlsx';
      case AdministrasiFileType.unknown:
        return '';
    }
  }

  String get mimeType {
    switch (this) {
      case AdministrasiFileType.pdf:
        return 'application/pdf';
      case AdministrasiFileType.docx:
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case AdministrasiFileType.xlsx:
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case AdministrasiFileType.unknown:
        return 'application/octet-stream';
    }
  }

  bool get opensInApp => this == AdministrasiFileType.pdf;
}

class AdministrasiFileTypeDetector {
  const AdministrasiFileTypeDetector._();

  static const List<String> allowedExtensions = ['pdf', 'docx', 'xlsx'];
  static const String allowedExtensionsLabel = 'PDF, DOCX, atau XLSX';

  static AdministrasiFileType detect({String? fileName, String? fileUrl}) {
    final legacyType =
        _detectLegacyWrappedType(fileName) ?? _detectLegacyWrappedType(fileUrl);
    if (legacyType != null) {
      return legacyType;
    }

    final extension =
        extensionFromName(fileName) ?? extensionFromUrl(fileUrl) ?? '';
    return fromExtension(extension);
  }

  static AdministrasiFileType fromExtension(String? extension) {
    switch ((extension ?? '').trim().toLowerCase()) {
      case 'pdf':
        return AdministrasiFileType.pdf;
      case 'docx':
        return AdministrasiFileType.docx;
      case 'xlsx':
        return AdministrasiFileType.xlsx;
      default:
        return AdministrasiFileType.unknown;
    }
  }

  static String? extensionFromName(String? fileName) {
    return _extractExtension(fileName);
  }

  static String? extensionFromUrl(String? fileUrl) {
    final rawUrl = (fileUrl ?? '').trim();
    if (rawUrl.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(rawUrl);
    if (uri == null) {
      return _extractExtension(rawUrl);
    }

    if (uri.pathSegments.isEmpty) {
      return null;
    }

    return _extractExtension(uri.pathSegments.last);
  }

  static bool isAllowedExtension(String? extension) {
    return allowedExtensions.contains((extension ?? '').trim().toLowerCase());
  }

  static bool hasValidSignature({
    required AdministrasiFileType fileType,
    required Uint8List bytes,
  }) {
    if (bytes.isEmpty) {
      return false;
    }

    switch (fileType) {
      case AdministrasiFileType.pdf:
        return _containsWithinFirstBytes(bytes, const [
          0x25,
          0x50,
          0x44,
          0x46,
          0x2D,
        ], 1024);
      case AdministrasiFileType.docx:
      case AdministrasiFileType.xlsx:
        return _startsWith(bytes, const [0x50, 0x4B]);
      case AdministrasiFileType.unknown:
        return false;
    }
  }

  static String? _extractExtension(String? source) {
    final value = (source ?? '').trim();
    if (value.isEmpty) {
      return null;
    }

    final normalized = value.split('/').last;
    final dotIndex = normalized.lastIndexOf('.');
    if (dotIndex <= 0 || dotIndex >= normalized.length - 1) {
      return null;
    }

    return normalized.substring(dotIndex + 1).toLowerCase();
  }

  static AdministrasiFileType? _detectLegacyWrappedType(String? source) {
    final rawValue = (source ?? '').trim();
    if (rawValue.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(rawValue);
    final value =
        ((uri != null && uri.pathSegments.isNotEmpty)
                ? uri.pathSegments.last
                : rawValue.split('/').last)
            .trim()
            .toLowerCase();

    if (value.endsWith('.docx.pdf')) {
      return AdministrasiFileType.docx;
    }

    if (value.endsWith('.xlsx.pdf')) {
      return AdministrasiFileType.xlsx;
    }

    return null;
  }

  static bool _startsWith(Uint8List bytes, List<int> prefix) {
    if (bytes.length < prefix.length) {
      return false;
    }

    for (var index = 0; index < prefix.length; index++) {
      if (bytes[index] != prefix[index]) {
        return false;
      }
    }

    return true;
  }

  static bool _containsWithinFirstBytes(
    Uint8List bytes,
    List<int> pattern,
    int limit,
  ) {
    if (bytes.isEmpty || pattern.isEmpty || bytes.length < pattern.length) {
      return false;
    }

    final maxStart = bytes.length - pattern.length;
    final searchLimit = limit - pattern.length;
    final upperBound = searchLimit < maxStart ? searchLimit : maxStart;

    for (var start = 0; start <= upperBound; start++) {
      var matches = true;
      for (var offset = 0; offset < pattern.length; offset++) {
        if (bytes[start + offset] != pattern[offset]) {
          matches = false;
          break;
        }
      }
      if (matches) {
        return true;
      }
    }

    return false;
  }
}
