import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/guru_model.dart';
import '../../../models/kelas_model.dart';
import '../../../models/mapel_model.dart';
import '../../../models/siswa_model.dart';
import '../../../models/tahun_ajaran_model.dart';
import '../../../models/user_model.dart';
import '../../../models/user_role_model.dart';
import '../../../providers/supabase_providers.dart';
import '../../shared/providers/shared_academic_context_provider.dart';

enum SelfProfileType { staff, siswa }

class SelfProfileArgs {
  final String uid;
  final String role;
  final SelfProfileType type;

  const SelfProfileArgs({
    required this.uid,
    required this.role,
    required this.type,
  });

  @override
  bool operator ==(Object other) {
    return other is SelfProfileArgs &&
        other.uid == uid &&
        other.role == role &&
        other.type == type;
  }

  @override
  int get hashCode => Object.hash(uid, role, type);
}

class SelfProfileState {
  final UserRecord? user;
  final GuruRecord? guruProfile;
  final SiswaRecord? siswaProfile;
  final List<UserRoleRecord> roles;
  final TahunAjaranRecord? activeTahunAjaran;
  final List<KelasRecord> waliKelasAssignments;
  final List<MapelRecord> taughtSubjects;
  final List<KelasRecord> taughtClasses;
  final bool isLoading;
  final bool isSaving;
  final String? error;

  const SelfProfileState({
    required this.user,
    required this.guruProfile,
    required this.siswaProfile,
    required this.roles,
    required this.activeTahunAjaran,
    required this.waliKelasAssignments,
    required this.taughtSubjects,
    required this.taughtClasses,
    required this.isLoading,
    required this.isSaving,
    this.error,
  });

  factory SelfProfileState.initial() {
    return const SelfProfileState(
      user: null,
      guruProfile: null,
      siswaProfile: null,
      roles: <UserRoleRecord>[],
      activeTahunAjaran: null,
      waliKelasAssignments: <KelasRecord>[],
      taughtSubjects: <MapelRecord>[],
      taughtClasses: <KelasRecord>[],
      isLoading: false,
      isSaving: false,
    );
  }

  SelfProfileState copyWith({
    UserRecord? user,
    GuruRecord? guruProfile,
    SiswaRecord? siswaProfile,
    List<UserRoleRecord>? roles,
    TahunAjaranRecord? activeTahunAjaran,
    List<KelasRecord>? waliKelasAssignments,
    List<MapelRecord>? taughtSubjects,
    List<KelasRecord>? taughtClasses,
    bool? isLoading,
    bool? isSaving,
    String? error,
    bool clearError = false,
  }) {
    return SelfProfileState(
      user: user ?? this.user,
      guruProfile: guruProfile ?? this.guruProfile,
      siswaProfile: siswaProfile ?? this.siswaProfile,
      roles: roles ?? this.roles,
      activeTahunAjaran: activeTahunAjaran ?? this.activeTahunAjaran,
      waliKelasAssignments:
          waliKelasAssignments ?? this.waliKelasAssignments,
      taughtSubjects: taughtSubjects ?? this.taughtSubjects,
      taughtClasses: taughtClasses ?? this.taughtClasses,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class SelfProfileNotifier extends StateNotifier<SelfProfileState> {
  final Ref _ref;
  final SelfProfileArgs _args;

  SelfProfileNotifier(this._ref, this._args)
    : super(SelfProfileState.initial());

  Future<void> loadProfile({bool forceRefresh = false}) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final user = await _ref
          .read(appMasterCacheProvider)
          .getUserProfileByUid(
            _ref.read,
            _args.uid,
            forceRefresh: forceRefresh,
          );
      if (user == null) {
        throw Exception('Data user tidak ditemukan.');
      }

      final roles = await _ref
          .read(userRoleServiceProvider)
          .getByUidDirect(_args.uid);
      final isGuruProfile = _args.type == SelfProfileType.staff && _isGuruRole();

      GuruRecord? guruProfile;
      SiswaRecord? siswaProfile;
      TahunAjaranRecord? activeTahunAjaran;
      List<KelasRecord> waliKelasAssignments = const <KelasRecord>[];
      List<MapelRecord> taughtSubjects = const <MapelRecord>[];
      List<KelasRecord> taughtClasses = const <KelasRecord>[];

      if (_args.type == SelfProfileType.staff) {
        final guruService = _ref.read(guruServiceProvider);
        guruProfile = await guruService.getFirstByUid(_args.uid);
        if (guruProfile == null) {
          await guruService.create(<String, dynamic>{
            'uid': _args.uid,
          }, id: _args.uid);
          guruProfile = await guruService.getFirstByUid(_args.uid);
        }
      } else {
        final siswaService = _ref.read(siswaServiceProvider);
        siswaProfile = await siswaService.getFirstByUid(_args.uid);
        if (siswaProfile == null) {
          await siswaService.create(<String, dynamic>{
            'uid': _args.uid,
          }, id: _args.uid);
          siswaProfile = await siswaService.getFirstByUid(_args.uid);
        }
      }

      if (isGuruProfile) {
        final tahunRows = await _ref
            .read(tahunAjaranServiceProvider)
            .getActiveTahunAjaran();
        if (tahunRows.isNotEmpty) {
          final activeYear = tahunRows.first;
          activeTahunAjaran = activeYear;

          final kelasService = _ref.read(kelasServiceProvider);
          final jadwalService = _ref.read(jadwalServiceProvider);
          final mapelService = _ref.read(mapelServiceProvider);
          final historiWaliKelasService = _ref.read(
            historiWaliKelasServiceProvider,
          );

          final waliRows = await historiWaliKelasService.getByGuruAndTahunAjaran(
            _args.uid,
            activeYear.id,
            onlyAktif: true,
            forceFullFetch: forceRefresh,
          );

          final jadwalRows = await jadwalService.getByGuruAndTahunAjaran(
            _args.uid,
            activeYear.id,
            forceFullFetch: forceRefresh,
          );

          final kelasIds = jadwalRows
              .map((row) => row.kelasId)
              .where((id) => id.trim().isNotEmpty)
              .toSet();
          final mapelIds = jadwalRows
              .map((row) => row.mapelId)
              .where((id) => id.trim().isNotEmpty)
              .toSet();

          final kelasRows = await kelasService.getAllIncremental(
            forceFullFetch: forceRefresh,
          );
          final activeWaliKelasIds = waliRows
              .where((row) => !row.isDeleted && row.isAktif)
              .map((row) => row.kelasId)
              .where((id) => id.trim().isNotEmpty)
              .toSet();

          if (activeWaliKelasIds.isEmpty) {
            // Fallback sementara selama fase migrasi data.
            final legacyRows = await kelasService.getByUserId(
              _args.uid,
              forceFullFetch: forceRefresh,
            );
            activeWaliKelasIds.addAll(
              legacyRows
                  .where((row) => !row.isDeleted)
                  .map((row) => row.id)
                  .where((id) => id.trim().isNotEmpty),
            );
          }

          final kelasMap = {
            for (final row in kelasRows.where((row) => !row.isDeleted)) row.id: row,
          };
          waliKelasAssignments = activeWaliKelasIds
              .map((id) => kelasMap[id])
              .whereType<KelasRecord>()
              .toList()
            ..sort(
              (a, b) => a.namaKelas.toLowerCase().compareTo(
                b.namaKelas.toLowerCase(),
              ),
            );

          taughtClasses = kelasIds
              .map((id) => kelasMap[id])
              .whereType<KelasRecord>()
              .toList()
            ..sort(
              (a, b) => a.namaKelas.toLowerCase().compareTo(
                b.namaKelas.toLowerCase(),
              ),
            );

          final allMapel = await mapelService.getAllIncremental(
            forceFullFetch: forceRefresh,
          );
          final mapelMap = {
            for (final row in allMapel.where((row) => !row.isDeleted)) row.id: row,
          };
          taughtSubjects = mapelIds
              .map((id) => mapelMap[id])
              .whereType<MapelRecord>()
              .toList()
            ..sort(
              (a, b) => a.namaMapel.toLowerCase().compareTo(
                b.namaMapel.toLowerCase(),
              ),
            );
        }
      }

      state = state.copyWith(
        user: user,
        roles: roles,
        guruProfile: guruProfile,
        siswaProfile: siswaProfile,
        activeTahunAjaran: activeTahunAjaran,
        waliKelasAssignments: waliKelasAssignments,
        taughtSubjects: taughtSubjects,
        taughtClasses: taughtClasses,
        isLoading: false,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Gagal memuat profil: $e',
      );
    }
  }

  Future<void> updateStaffProfile({
    required String email,
    required String username,
    required String alamat,
    required String gender,
    required String tempatLahir,
    required DateTime? tanggalLahir,
    required String golongan,
    String? password,
  }) async {
    await _updateUserAccount(
      email: email,
      username: username,
      password: password,
    );

    final service = _ref.read(guruServiceProvider);
    final current = state.guruProfile;
    final payload = <String, dynamic>{
      'alamat': alamat,
      'gender': _emptyToNull(gender),
      'tempat_lahir': tempatLahir,
      'tanggal_lahir': tanggalLahir,
      'golongan': golongan,
    };

    if (current == null) {
      await service.create(<String, dynamic>{
        'uid': _args.uid,
        ...payload,
      }, id: _args.uid);
    } else {
      await service.update(current.id, payload);
    }

    await loadProfile(forceRefresh: true);
  }

  Future<void> updateSiswaProfile({
    required String email,
    required String username,
    required String alamat,
    required String gender,
    required String tempatLahir,
    required DateTime? tanggalLahir,
    String? password,
  }) async {
    await _updateUserAccount(
      email: email,
      username: username,
      password: password,
    );

    final service = _ref.read(siswaServiceProvider);
    final current = state.siswaProfile;
    final payload = <String, dynamic>{
      'alamat': alamat,
      'gender': _emptyToNull(gender),
      'tempat_lahir': tempatLahir,
      'tanggal_lahir': tanggalLahir,
    };

    if (current == null) {
      await service.create(<String, dynamic>{
        'uid': _args.uid,
        ...payload,
      }, id: _args.uid);
    } else {
      await service.update(current.id, payload);
    }

    await loadProfile(forceRefresh: true);
  }

  Future<void> _updateUserAccount({
    required String email,
    required String username,
    String? password,
  }) async {
    final currentUser = state.user;
    if (currentUser == null) {
      throw Exception('Data user belum tersedia.');
    }

    final normalizedEmail = email.trim();
    final normalizedUsername = username.trim();
    final normalizedPassword = (password ?? '').trim();

    _validateEmail(normalizedEmail);
    _validateUsername(normalizedUsername);
    _validatePassword(normalizedPassword);

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final userService = _ref.read(userServiceProvider);

      final emailOwners = await userService.getByEmail(normalizedEmail);
      if (emailOwners.any((row) => row.id != currentUser.id)) {
        throw Exception('Email sudah digunakan oleh akun lain.');
      }

      if (normalizedUsername.isNotEmpty) {
        final usernameOwners = await userService.getByUsername(
          normalizedUsername,
        );
        if (usernameOwners.any((row) => row.id != currentUser.id)) {
          throw Exception('Username sudah digunakan oleh akun lain.');
        }
      }

      final payload = <String, dynamic>{
        'email': normalizedEmail,
        'username': normalizedUsername.isEmpty ? null : normalizedUsername,
      };
      if (normalizedPassword.isNotEmpty) {
        payload['password'] = normalizedPassword;
      }

      await userService.update(currentUser.id, payload);
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        error: 'Gagal menyimpan profil: $e',
      );
      rethrow;
    }
  }

  void finishSaving() {
    state = state.copyWith(isSaving: false);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  void _validateEmail(String value) {
    if (value.isEmpty) {
      throw Exception('Email wajib diisi.');
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
      throw Exception('Format email tidak valid.');
    }
  }

  void _validateUsername(String value) {
    if (value.isEmpty) {
      return;
    }
    if (value.length < 3) {
      throw Exception('Username minimal 3 karakter.');
    }
    if (!RegExp(r'^[A-Za-z0-9._]+$').hasMatch(value)) {
      throw Exception(
        'Username hanya boleh berisi huruf, angka, titik, dan underscore.',
      );
    }
  }

  void _validatePassword(String value) {
    if (value.isEmpty) {
      return;
    }
    if (value.length < 6) {
      throw Exception('Password minimal 6 karakter.');
    }
    if (value.contains(RegExp(r'\s'))) {
      throw Exception('Password tidak boleh mengandung spasi.');
    }
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  bool _isGuruRole() {
    final normalized = _args.role.trim().toLowerCase();
    return normalized == 'guru';
  }
}

final selfProfileProvider = StateNotifierProvider.autoDispose
    .family<SelfProfileNotifier, SelfProfileState, SelfProfileArgs>((
      ref,
      args,
    ) {
      final notifier = SelfProfileNotifier(ref, args);
      Future.microtask(notifier.loadProfile);
      return notifier;
    });
