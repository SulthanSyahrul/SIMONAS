import 'package:flutter/material.dart';

const List<String> orderedSupportedRoles = <String>[
  'kepala_sekolah',
  'kesiswaan',
  'guru',
  'siswa',
];

String normalizeRoleValue(String role) {
  final value = role.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');
  switch (value) {
    case 'kepsek':
    case 'kepala_sekolah':
    case 'kepala-sekolah':
      return 'kepala_sekolah';
    case 'bk':
    case 'kemahasiswaan':
    case 'kesiswaan':
      return 'kesiswaan';
    case 'guru':
      return 'guru';
    case 'siswa':
      return 'siswa';
    default:
      return value;
  }
}

bool isSupportedRoleValue(String role) {
  return orderedSupportedRoles.contains(normalizeRoleValue(role));
}

String roleLabelValue(String role) {
  switch (normalizeRoleValue(role)) {
    case 'kepala_sekolah':
      return 'Kepala Sekolah';
    case 'kesiswaan':
      return 'BK';
    case 'guru':
      return 'Guru';
    case 'siswa':
      return 'Siswa';
    default:
      return role;
  }
}

IconData roleIconValue(String role) {
  switch (normalizeRoleValue(role)) {
    case 'kepala_sekolah':
      return Icons.admin_panel_settings;
    case 'kesiswaan':
      return Icons.groups;
    case 'guru':
      return Icons.menu_book;
    case 'siswa':
      return Icons.school;
    default:
      return Icons.person;
  }
}

List<String> sortRoleValues(Iterable<String> roles) {
  final unique = roles
      .map(normalizeRoleValue)
      .where((role) => role.isNotEmpty)
      .toSet()
      .toList(growable: false);
  unique.sort((a, b) {
    final aIdx = orderedSupportedRoles.indexOf(a);
    final bIdx = orderedSupportedRoles.indexOf(b);
    return aIdx.compareTo(bIdx);
  });
  return unique;
}

String joinRoleLabels(Iterable<String> roles) {
  final sorted = sortRoleValues(roles);
  return sorted.map(roleLabelValue).join(', ');
}

String primaryRoleValue(Iterable<String> roles, {String fallback = 'guru'}) {
  final sorted = sortRoleValues(roles);
  if (sorted.isNotEmpty) {
    return sorted.first;
  }
  return normalizeRoleValue(fallback);
}
