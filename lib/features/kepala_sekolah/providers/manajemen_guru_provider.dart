import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/role_display_helper.dart';
import '../../../providers/supabase_providers.dart';

class GuruAccountItem {
  final String id;
  final String uid;
  final String nama;
  final String email;
  final String role;
  final List<String> roles;
  final String? username;
  final String? nip;
  final String? nuptk;
  final String? alamat;
  final String? gender;
  final String? golongan;
  final DateTime? tanggalLahir;
  final String? tempatLahir;
  final String status;
  final bool active;

  const GuruAccountItem({
    required this.id,
    required this.uid,
    required this.nama,
    required this.email,
    required this.role,
    required this.roles,
    required this.username,
    required this.nip,
    required this.nuptk,
    required this.alamat,
    required this.gender,
    required this.golongan,
    required this.tanggalLahir,
    required this.tempatLahir,
    required this.status,
    required this.active,
  });
}

class ManajemenGuruState {
  final List<GuruAccountItem> allGuru;
  final List<GuruAccountItem> filteredGuru;
  final String searchQuery;
  final String selectedStatus;
  final bool isLoading;
  final String? error;

  const ManajemenGuruState({
    required this.allGuru,
    required this.filteredGuru,
    required this.searchQuery,
    required this.selectedStatus,
    required this.isLoading,
    this.error,
  });

  factory ManajemenGuruState.initial() {
    return const ManajemenGuruState(
      allGuru: [],
      filteredGuru: [],
      searchQuery: '',
      selectedStatus: 'semua',
      isLoading: false,
    );
  }

  ManajemenGuruState copyWith({
    List<GuruAccountItem>? allGuru,
    List<GuruAccountItem>? filteredGuru,
    String? searchQuery,
    String? selectedStatus,
    bool? isLoading,
    String? error,
  }) {
    return ManajemenGuruState(
      allGuru: allGuru ?? this.allGuru,
      filteredGuru: filteredGuru ?? this.filteredGuru,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedStatus: selectedStatus ?? this.selectedStatus,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ManajemenGuruNotifier extends StateNotifier<ManajemenGuruState> {
  final Ref _ref;

  ManajemenGuruNotifier(this._ref) : super(ManajemenGuruState.initial());

  Future<void> loadGuru({bool forceRefreshData = false}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final guruService = _ref.read(guruServiceProvider);
      final profiles = await guruService.getAllLite();

      final uids = profiles
          .map((p) => p.uid)
          .where((u) => u.isNotEmpty)
          .toSet()
          .toList(growable: false);

      final users = uids.isEmpty
          ? const <dynamic>[]
          : await _ref.read(userServiceProvider).getByUidsLite(uids);
      final rolesByUid = uids.isEmpty
          ? const <String, List<String>>{}
          : await _ref.read(userRoleServiceProvider).getRolesByUids(uids);

      final usersByUid = <String, dynamic>{
        for (final user in users) user.uid: user,
      };

      final guruList = profiles.map((profile) {
        final user = usersByUid[profile.uid];
        final roles = rolesByUid[profile.uid] ?? const <String>['guru'];
        final profileName = profile.nama.trim();
        final displayName = profileName.isNotEmpty
            ? profileName
            : (user != null ? user.nama : profile.uid);

        return GuruAccountItem(
          id: user?.id ?? profile.uid,
          uid: profile.uid,
          nama: displayName,
          email: user?.email ?? '',
          role: _displayRoleValue(roles, 'guru'),
          roles: roles,
          username: user?.username,
          nip: profile.nip,
          nuptk: profile.nuptk,
          alamat: profile.alamat,
          gender: profile.gender,
          golongan: profile.golongan,
          tanggalLahir: profile.tanggalLahir,
          tempatLahir: profile.tempatLahir,
          status: (user?.active ?? true) ? 'aktif' : 'nonaktif',
          active: user?.active ?? true,
        );
      }).toList(growable: false);

      final sorted = [...guruList]
        ..sort((a, b) => a.nama.toLowerCase().compareTo(b.nama.toLowerCase()));

      state = state.copyWith(allGuru: sorted, isLoading: false);
      _applyFilter();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Gagal memuat data guru: $e',
      );
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    _applyFilter();
  }

  void setStatusFilter(String status) {
    state = state.copyWith(selectedStatus: status);
    _applyFilter();
  }

  Future<void> toggleActive(GuruAccountItem guru) async {
    final nextActive = !guru.active;
    final nextStatus = nextActive ? 'aktif' : 'nonaktif';

    try {
      await _ref.read(userServiceProvider).update(guru.id, {
        'active': nextActive,
        'status': nextStatus,
      });
      await loadGuru();
    } catch (e) {
      state = state.copyWith(error: 'Gagal mengubah status guru: $e');
    }
  }

  Future<void> createGuru(Map<String, dynamic> rawData) async {
    final nama = _readString(rawData['nama']);
    final email = _readString(rawData['email']);
    final roles = _readRoleList(rawData['roles'], fallback: rawData['role']);
    final password = _readString(rawData['password']);
    final active = _readBool(rawData['active'], fallback: true);
    final status = active ? 'aktif' : 'nonaktif';
    final username = _readString(rawData['username']);

    try {
      if (nama.isEmpty) {
        throw Exception('Nama guru tidak boleh kosong.');
      }
      if (email.isEmpty) {
        throw Exception('Email guru tidak boleh kosong.');
      }
      if (password.isEmpty) {
        throw Exception('Password guru tidak boleh kosong.');
      }

      await _ref.read(authServiceProvider).registerUser(
        email: email,
        password: password,
        username: username.isEmpty ? null : username,
        nama: nama,
        roles: roles,
        active: active,
        guruProfile: _guruProfilePayload(rawData),
        userPayload: <String, dynamic>{
          'status': status,
          'active': active,
        },
      );

      await loadGuru();
    } catch (e) {
      state = state.copyWith(error: 'Gagal menambah guru: $e');
    }
  }

  Future<void> updateGuru(String id, Map<String, dynamic> rawData) async {
    final nama = _readString(rawData['nama']);
    final email = _readString(rawData['email']);
    final roles = _readRoleList(rawData['roles'], fallback: rawData['role']);
    final username = _readString(rawData['username']);
    final active = _readBool(rawData['active'], fallback: true);
    final status = active ? 'aktif' : 'nonaktif';
    final userService = _ref.read(userServiceProvider);

    try {
      if (nama.isEmpty) {
        throw Exception('Nama guru tidak boleh kosong.');
      }
      if (email.isEmpty) {
        throw Exception('Email guru tidak boleh kosong.');
      }

      final emailOwner = await userService.getByEmail(email);
      if (emailOwner.any((row) => row.id != id)) {
        throw Exception('Email sudah digunakan oleh akun lain.');
      }

      final userPayload = <String, dynamic>{
        'nama': nama,
        'email': email,
        'username': username,
        'roles': roles,
        'status': status,
        'active': active,
      };

      await userService.update(id, userPayload);

      final user = await userService.getById(id);
      if (user != null) {
        await _ref.read(userRoleServiceProvider).syncRoles(uid: user.uid, roles: roles);
        await _upsertGuruProfile(uid: user.uid, rawData: rawData);

        // Update credentials in Supabase Auth via Edge Function
        final password = _readString(rawData['password']);
        await _updateGuruCredentialsInAuth(
          targetUserId: user.uid,
          newEmail: email,
          newPassword: password.isNotEmpty ? password : null,
        );
      }

      await loadGuru();
    } catch (e) {
      state = state.copyWith(error: 'Gagal mengupdate guru: $e');
    }
  }

  List<String> _readRoleList(dynamic value, {dynamic fallback}) {
    final rawValues = <String>[];

    if (value is Iterable) {
      for (final item in value) {
        final text = item.toString().trim();
        if (text.isNotEmpty) {
          rawValues.add(text);
        }
      }
    } else if (value != null) {
      final text = value.toString().trim();
      if (text.isNotEmpty) {
        rawValues.add(text);
      }
    }

    if (rawValues.isEmpty) {
      final fallbackText = (fallback ?? '').toString().trim();
      if (fallbackText.isNotEmpty) {
        rawValues.add(fallbackText);
      }
    }

    final normalized = sortRoleValues(rawValues);
    return normalized.isEmpty ? <String>['guru'] : normalized;
  }

  String _displayRoleValue(dynamic roles, dynamic fallbackRole) {
    final parsed = _readRoleList(roles, fallback: fallbackRole);
    return joinRoleLabels(parsed);
  }

  Future<void> deactivateGuru(String id) async {
    try {
      await _ref.read(userServiceProvider).update(id, {
        'status': 'nonaktif',
        'active': false,
      });
      await loadGuru();
    } catch (e) {
      state = state.copyWith(error: 'Gagal menonaktifkan guru: $e');
    }
  }

  Future<void> _updateGuruCredentialsInAuth({
    required String targetUserId,
    String? newEmail,
    String? newPassword,
  }) async {
    final supabase = Supabase.instance.client;
    try {
      final response = await supabase.functions.invoke(
        'update-user-credentials',
        body: {
          'targetUserId': targetUserId,
          if (newEmail != null && newEmail.isNotEmpty) 'email': newEmail,
          if (newPassword != null && newPassword.isNotEmpty) 'password': newPassword,
        },
      );

      if (response.status != 200) {
        final errorMsg = response.data is Map ? response.data['error'] : response.data;
        throw Exception(errorMsg ?? 'Gagal memperbarui autentikasi.');
      }
    } catch (e) {
      throw Exception('Gagal sinkronisasi data autentikasi: $e');
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  Future<void> _upsertGuruProfile({
    required String uid,
    required Map<String, dynamic> rawData,
  }) async {
    final service = _ref.read(guruServiceProvider);
    final existing = await service.getByUid(uid);
    final payload = _guruProfilePayload(rawData);

    if (existing.isEmpty) {
      await service.create(<String, dynamic>{
        'uid': uid,
        ...payload,
      }, id: uid);
      return;
    }

    await service.update(existing.first.id, payload);
  }

  Map<String, dynamic> _guruProfilePayload(Map<String, dynamic> rawData) {
    return <String, dynamic>{
      'nama_lengkap': _readString(rawData['nama']),
      'nip': _readString(rawData['nip']),
      'nuptk': _readString(rawData['nuptk']),
      'alamat': _readString(rawData['alamat']),
      'gender': _readString(rawData['gender']),
      'golongan': _readString(rawData['golongan']),
      'tanggal_lahir': _readDate(rawData['tanggal_lahir']),
      'tempat_lahir': _readString(rawData['tempat_lahir']),
    };
  }

  String _readString(dynamic value) {
    return (value ?? '').toString().trim();
  }

  bool _readBool(dynamic value, {required bool fallback}) {
    if (value is bool) {
      return value;
    }
    final normalized = (value ?? '').toString().trim().toLowerCase();
    if (normalized == 'true' || normalized == '1' || normalized == 'aktif') {
      return true;
    }
    if (normalized == 'false' ||
        normalized == '0' ||
        normalized == 'nonaktif') {
      return false;
    }
    return fallback;
  }

  DateTime? _readDate(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is DateTime) {
      return DateTime(value.year, value.month, value.day);
    }
    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) {
      return null;
    }
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  void _applyFilter() {
    final query = state.searchQuery.trim().toLowerCase();
    final status = state.selectedStatus;

    final filtered = state.allGuru.where((guru) {
      final guruStatus = guru.active ? 'aktif' : 'nonaktif';
      final matchesStatus = status == 'semua' || guruStatus == status;

      final name = guru.nama.toLowerCase();
      final nip = (guru.nip ?? '').toLowerCase();
      final username = (guru.username ?? '').toLowerCase();
      final matchesQuery =
          query.isEmpty ||
          name.contains(query) ||
          nip.contains(query) ||
          username.contains(query);

      return matchesStatus && matchesQuery;
    }).toList();

    state = state.copyWith(filteredGuru: filtered);
  }
}

final manajemenGuruProvider =
    StateNotifierProvider.autoDispose<
      ManajemenGuruNotifier,
      ManajemenGuruState
    >((ref) {
      final notifier = ManajemenGuruNotifier(ref);
      Future.microtask(notifier.loadGuru);
      return notifier;
    });
