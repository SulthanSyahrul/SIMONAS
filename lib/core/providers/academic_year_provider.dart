import 'package:flutter/material.dart';

/// Provider untuk mengelola state tahun ajaran
/// Digunakan di seluruh aplikasi untuk konsistensi data
class AcademicYearProvider extends ChangeNotifier {
  static const String _defaultYear = '2024/2025';

  // Tahun ajaran aktif saat ini
  String _selectedYear = _defaultYear;

  // Getter untuk mendapatkan tahun ajaran aktif
  String get selectedYear => _selectedYear;

  // Daftar tahun ajaran yang tersedia
  final List<String> _availableYears = [
    '2023/2024',
    _defaultYear,
    '2025/2026',
  ];

  List<String> get availableYears => List.unmodifiable(_availableYears);

  /// Set tahun ajaran yang dipilih
  void setYear(String year) {
    final normalizedYear = year.trim();
    if (normalizedYear.isEmpty) {
      return;
    }

    if (!_availableYears.contains(normalizedYear)) {
      _availableYears.add(normalizedYear);
      _availableYears.sort();
    }

    if (_selectedYear != normalizedYear) {
      _selectedYear = normalizedYear;
      notifyListeners();
    }
  }

  void replaceAvailableYears(
    List<String> years, {
    String? preferredYear,
  }) {
    final normalizedYears = years
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    if (normalizedYears.isEmpty) {
      if (_availableYears.length == 1 && _availableYears.first == _defaultYear) {
        return;
      }
      _availableYears
        ..clear()
        ..add(_defaultYear);
      if (_selectedYear != _defaultYear) {
        _selectedYear = _defaultYear;
        notifyListeners();
      }
      return;
    }

    _availableYears
      ..clear()
      ..addAll(normalizedYears);

    final nextSelectedYear = (() {
      final preferred = preferredYear?.trim();
      if (preferred != null && preferred.isNotEmpty) {
        return _availableYears.contains(preferred) ? preferred : null;
      }
      if (_availableYears.contains(_selectedYear)) {
        return _selectedYear;
      }
      return _availableYears.first;
    })();

    if (nextSelectedYear != null && _selectedYear != nextSelectedYear) {
      _selectedYear = nextSelectedYear;
      notifyListeners();
    }
  }

  /// Reset ke tahun default
  void reset() {
    final nextYear = _availableYears.contains(_defaultYear)
        ? _defaultYear
        : (_availableYears.isEmpty ? _defaultYear : _availableYears.first);
    if (_selectedYear != nextYear) {
      _selectedYear = nextYear;
      notifyListeners();
    }
  }
}
