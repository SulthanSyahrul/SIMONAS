import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/siswa_model.dart';
import '../../../models/user_model.dart';
import '../../../providers/supabase_providers.dart';

const String bkSiswaFilterSemua = 'semua';
const String bkSiswaStatusAktif = 'aktif';
const String bkSiswaStatusNonaktif = 'nonaktif';

String normalizeBkSiswaStatus(String? status, {bool? activeHint}) {
  final normalized = (status ?? '').trim().toLowerCase();
  if (activeHint == false) {
    return bkSiswaStatusNonaktif;
  }
  if (activeHint == true) {
    return bkSiswaStatusAktif;
  }
  if (normalized == bkSiswaStatusNonaktif ||
      normalized == 'inactive' ||
      normalized == 'lulus' ||
      normalized == 'pindah' ||
      normalized == 'keluar' ||
      normalized == 'keluar_sekolah' ||
      normalized == 'do') {
    return bkSiswaStatusNonaktif;
  }
  return bkSiswaStatusAktif;
}

String bkSiswaStatusLabel(String status) {
  switch (normalizeBkSiswaStatus(status)) {
    case bkSiswaStatusAktif:
      return 'Aktif';
    case bkSiswaStatusNonaktif:
      return 'Nonaktif';
    default:
      return 'Aktif';
  }
}

class BkSiswaItem {
  final String id;
  final String uid;
  final String nama;
  final String email;
  final String? username;
  final String? nis;
  final String status;
  final bool active;

  const BkSiswaItem({
    required this.id,
    required this.uid,
    required this.nama,
    required this.email,
    required this.username,
    required this.nis,
    required this.status,
    required this.active,
  });
}

class BkSiswaEditFormData {
  final UserRecord user;
  final SiswaRecord? profile;

  const BkSiswaEditFormData({
    required this.user,
    required this.profile,
  });
}

class CreateBkSiswaResult {
  final String uid;
  final String username;

  const CreateBkSiswaResult({
    required this.uid,
    required this.username,
  });
}

class ManajemenSiswaBkState {
  final List<BkSiswaItem> data;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;

  const ManajemenSiswaBkState({
    required this.data,
    required this.isLoading,
    required this.isLoadingMore,
    required this.hasMore,
    required this.error,
  });

  factory ManajemenSiswaBkState.initial() {
    return const ManajemenSiswaBkState(
      data: <BkSiswaItem>[],
      isLoading: false,
      isLoadingMore: false,
      hasMore: false,
      error: null,
    );
  }

  ManajemenSiswaBkState copyWith({
    List<BkSiswaItem>? data,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    Object? error = _sentinel,
  }) {
    return ManajemenSiswaBkState(
      data: data ?? this.data,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: error == _sentinel ? this.error : error as String?,
    );
  }
}

class ManajemenSiswaBkNotifier
    extends StateNotifier<ManajemenSiswaBkState> {
  ManajemenSiswaBkNotifier(this._ref)
    : super(ManajemenSiswaBkState.initial());

  static const int _pageSize = 25;

  final Ref _ref;
  List<BkSiswaItem> _allData = const <BkSiswaItem>[];
  List<BkSiswaItem> _filteredData = const <BkSiswaItem>[];
  String _lastSearchQuery = '';
  int _visibleCount = _pageSize;

  Future<void> getSiswa({
    required String status,
    required String searchQuery,
    bool forceRefresh = false,
  }) async {
    _lastSearchQuery = searchQuery;
    _visibleCount = _pageSize;
    state = state.copyWith(
      isLoading: true,
      isLoadingMore: false,
      hasMore: false,
      error: null,
    );

    try {
      if (forceRefresh || _allData.isEmpty) {
        _allData = await _fetchItems(forceRefresh: forceRefresh);
      }
      _filteredData = _applyFilters(
        _allData,
        status: status,
        searchQuery: searchQuery,
      );
      _publishPage();
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        hasMore: false,
        error: 'Gagal memuat siswa: $error',
      );
    }
  }

  Future<void> loadMoreSiswa() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) {
      return;
    }
    state = state.copyWith(isLoadingMore: true, error: null);
    _visibleCount += _pageSize;
    _publishPage();
  }

  Future<CreateBkSiswaResult> createSiswa({
    required String nama,
    required String email,
    required String password,
    required String? username,
    required String? nis,
    required String? noHp,
    required String? tempatLahir,
    required String? alamat,
    required String? jenisKelamin,
    required DateTime? tanggalLahir,
    required String statusAfterOperation,
  }) async {
    final normalizedUsername = _buildUsername(nama, username: username);
    final authResult = await _ref
        .read(authServiceProvider)
        .registerUser(
          email: email.trim(),
          password: password,
          username: normalizedUsername,
          nama: nama.trim(),
          roles: <String>['siswa'],
          active: true,
          siswaProfile: <String, dynamic>{
            'nis': _nullIfBlank(nis),
            'nama': nama.trim(),
            'jenis_kelamin': _nullIfBlank(jenisKelamin),
            'tempat_lahir': _nullIfBlank(tempatLahir),
            'tanggal_lahir': tanggalLahir,
            'alamat': _nullIfBlank(alamat),
            'no_hp': _nullIfBlank(noHp),
          },
        );

    final createdUser = authResult.user;

    await getSiswa(
      status: statusAfterOperation,
      searchQuery: _lastSearchQuery,
      forceRefresh: true,
    );
    return CreateBkSiswaResult(
      uid: createdUser.id,
      username: createdUser.username ?? normalizedUsername,
    );
  }

  Future<BkSiswaEditFormData> getSiswaEditFormData(
    String userDocId, {
    bool forceRefresh = false,
  }) async {
    final users = await _ref
        .read(userServiceProvider)
        .getByUserIdLite(userDocId);
    if (users.isEmpty) {
      throw Exception('User siswa tidak ditemukan.');
    }
    final user = users.first;
    final profile = await _ref
        .read(siswaServiceProvider)
        .getFirstByUid(user.uid);
    return BkSiswaEditFormData(user: user, profile: profile);
  }

  Future<void> updateSiswa({
    required String userDocId,
    required String nama,
    required String email,
    required String username,
    required String nis,
    required String noHp,
    required String tempatLahir,
    required String? jenisKelamin,
    required DateTime? tanggalLahir,
    required String alamat,
    required String password,
    required String statusAfterOperation,
  }) async {
    final users = await _ref
        .read(userServiceProvider)
        .getByUserIdLite(userDocId);
    if (users.isEmpty) {
      throw Exception('User siswa tidak ditemukan.');
    }
    final user = users.first;

    await _ref.read(userServiceProvider).update(userDocId, <String, dynamic>{
      'email': email.trim(),
      'username': _buildUsername(nama, username: username),
    });

    final profile = await _ref
        .read(siswaServiceProvider)
        .getFirstByUid(user.uid);
    if (profile == null) {
      await _ref.read(siswaServiceProvider).create(<String, dynamic>{
        'uid': user.uid,
        'nama': nama.trim(),
        'nis': _nullIfBlank(nis),
        'tempat_lahir': _nullIfBlank(tempatLahir),
        'jenis_kelamin': _nullIfBlank(jenisKelamin),
        'tanggal_lahir': tanggalLahir,
        'alamat': _nullIfBlank(alamat),
        'no_hp': _nullIfBlank(noHp),
      });
    } else {
      await _ref
          .read(siswaServiceProvider)
          .update(profile.id, <String, dynamic>{
            'nama': nama.trim(),
            'nis': _nullIfBlank(nis),
            'tempat_lahir': _nullIfBlank(tempatLahir),
            'jenis_kelamin': _nullIfBlank(jenisKelamin),
            'tanggal_lahir': tanggalLahir,
            'alamat': _nullIfBlank(alamat),
            'no_hp': _nullIfBlank(noHp),
          });
    }

    await getSiswa(
      status: statusAfterOperation,
      searchQuery: _lastSearchQuery,
      forceRefresh: true,
    );

    if (password.isNotEmpty || email.trim() != user.email) {
      await _updateSiswaCredentialsInAuth(
        targetUserId: user.uid,
        newEmail: email.trim() != user.email ? email.trim() : null,
        newPassword: password.isNotEmpty ? password : null,
      );
    }
  }

  Future<void> ubahStatusSiswa({
    required String userDocId,
    required String selectedStatus,
    required String catatan,
    required String statusAfterOperation,
  }) async {
    final normalizedStatus = normalizeBkSiswaStatus(selectedStatus);
    final isActive = normalizedStatus == bkSiswaStatusAktif;
    if (catatan.trim().isNotEmpty) {
      // Catatan status log logic can be implemented here if needed.
    }
    await _ref.read(userServiceProvider).update(userDocId, <String, dynamic>{
      'is_deleted': !isActive,
    });
    await getSiswa(
      status: statusAfterOperation,
      searchQuery: _lastSearchQuery,
      forceRefresh: true,
    );
  }

  Future<void> softDeleteSiswa({
    required String userDocId,
    required String statusAfterOperation,
  }) async {
    await _ref.read(userServiceProvider).delete(userDocId);
    await getSiswa(
      status: statusAfterOperation,
      searchQuery: _lastSearchQuery,
      forceRefresh: true,
    );
  }

  Future<List<BkSiswaItem>> _fetchItems({
    required bool forceRefresh,
  }) async {
    final siswaService = _ref.read(siswaServiceProvider);
    final rows = await siswaService.client
        .from('siswa')
        .select(
          'id, user_id, nama, nis, is_deleted, users!siswa_user_id_fkey(id, email, username, is_deleted)',
        )
        .eq('is_deleted', false);

    final items =
        (rows as List<dynamic>)
            .map((raw) {
              final row = Map<String, dynamic>.from(raw as Map);
              final uid = (row['user_id'] ?? '').toString().trim();
              final nestedUser = row['users'];
              final userMap = nestedUser is Map
                  ? Map<String, dynamic>.from(nestedUser)
                  : nestedUser is List && nestedUser.isNotEmpty
                  ? Map<String, dynamic>.from(nestedUser.first as Map)
                  : null;
              final userId = (userMap?['id'] ?? uid).toString();
              final userDeleted = userMap?['is_deleted'] == true;
              final isActive = userMap != null && !userDeleted;
              final siswaNama = (row['nama'] ?? '').toString().trim();
              final fallbackNama = (userMap?['username'] ?? uid)
                  .toString()
                  .trim();

              return BkSiswaItem(
                id: userId,
                uid: uid,
                nama: siswaNama.isNotEmpty ? siswaNama : fallbackNama,
                email: (userMap?['email'] ?? '').toString(),
                username: userMap?['username']?.toString(),
                nis: row['nis']?.toString(),
                status: isActive
                    ? bkSiswaStatusAktif
                    : bkSiswaStatusNonaktif,
                active: isActive,
              );
            })
            .toList(growable: false)
          ..sort(
            (a, b) => a.nama.toLowerCase().compareTo(b.nama.toLowerCase()),
          );
    return items;
  }

  List<BkSiswaItem> _applyFilters(
    List<BkSiswaItem> rows, {
    required String status,
    required String searchQuery,
  }) {
    final normalizedStatus = status.trim().toLowerCase();
    final normalizedQuery = searchQuery.trim().toLowerCase();

    return rows
        .where((row) {
          final rowStatus = normalizeBkSiswaStatus(
            row.status,
            activeHint: row.active,
          );
          final matchesStatus = switch (normalizedStatus) {
            bkSiswaFilterSemua => true,
            _ => rowStatus == normalizedStatus,
          };
          if (!matchesStatus) {
            return false;
          }
          if (normalizedQuery.isEmpty) {
            return true;
          }
          return row.nama.toLowerCase().contains(normalizedQuery) ||
              row.uid.toLowerCase().contains(normalizedQuery) ||
              row.email.toLowerCase().contains(normalizedQuery) ||
              (row.username?.toLowerCase().contains(normalizedQuery) ??
                  false) ||
              (row.nis?.toLowerCase().contains(normalizedQuery) ?? false);
        })
        .toList(growable: false);
  }

  void _publishPage() {
    final takeCount = _visibleCount > _filteredData.length
        ? _filteredData.length
        : _visibleCount;
    state = state.copyWith(
      data: _filteredData.take(takeCount).toList(growable: false),
      isLoading: false,
      isLoadingMore: false,
      hasMore: takeCount < _filteredData.length,
      error: null,
    );
  }

  String _buildUsername(String nama, {String? username}) {
    final explicit = _nullIfBlank(username);
    if (explicit != null) {
      return explicit;
    }
    final base = nama
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '.')
        .replaceAll(RegExp(r'\.+'), '.')
        .replaceAll(RegExp(r'^\.|\.$'), '');
    if (base.isNotEmpty) {
      return base;
    }
    return 'siswa.${DateTime.now().millisecondsSinceEpoch}';
  }

  String? _nullIfBlank(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  Future<void> _updateSiswaCredentialsInAuth({
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
}

final manajemenSiswaBkProvider =
    StateNotifierProvider.autoDispose<
      ManajemenSiswaBkNotifier,
      ManajemenSiswaBkState
    >((ref) {
      return ManajemenSiswaBkNotifier(ref);
    });

const Object _sentinel = Object();
