import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/utils/role_display_helper.dart';
import '../models/guru_model.dart';
import '../models/siswa_model.dart';
import '../models/user_model.dart';
import '../models/user_role_model.dart';
import 'guru_service.dart';
import 'siswa_service.dart';
import 'user_role_service.dart';
import 'user_service.dart';

class LoginPrincipal {
  final UserRecord user;
  final List<UserRoleRecord> roles;

  const LoginPrincipal({required this.user, required this.roles});
}

class LoginSession {
  final UserRecord user;
  final UserRoleRecord role;
  final Object? profile;

  const LoginSession({
    required this.user,
    required this.role,
    required this.profile,
  });

  T? profileAs<T>() => profile is T ? profile as T : null;
}

class RestoredLoginSession {
  final LoginPrincipal principal;
  final LoginSession session;

  const RestoredLoginSession({required this.principal, required this.session});
}

class RegisteredUserResult {
  final UserRecord user;
  final List<UserRoleRecord> roles;
  final GuruRecord? guruProfile;
  final SiswaRecord? siswaProfile;

  const RegisteredUserResult({
    required this.user,
    required this.roles,
    this.guruProfile,
    this.siswaProfile,
  });
}

class AuthService {
  static const List<String> supportedRoleOrder = orderedSupportedRoles;

  final SupabaseClient client;
  final UserService userService;
  final UserRoleService roleService;
  final GuruService guruService;
  final SiswaService siswaService;

  AuthService({
    SupabaseClient? client,
    UserService? userService,
    UserRoleService? roleService,
    GuruService? guruService,
    SiswaService? siswaService,
  }) : client = client ?? Supabase.instance.client,
       userService = userService ?? UserService(client: client),
       roleService = roleService ?? UserRoleService(client: client),
       guruService = guruService ?? GuruService(client: client),
       siswaService = siswaService ?? SiswaService(client: client);

  bool isSupportedRole(String role) {
    return supportedRoleOrder.contains(normalizeRole(role));
  }

  String normalizeRole(String role) => roleService.normalizeRole(role);

  User? getCurrentAuthUser() => client.auth.currentUser;

  Future<UserRecord?> getCurrentUser() async {
    final authUser = getCurrentAuthUser();
    if (authUser == null) {
      return null;
    }
    return userService.getById(authUser.id);
  }

  Future<LoginPrincipal> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    final identifier = usernameOrEmail.trim();
    if (identifier.isEmpty) {
      throw Exception('Email wajib diisi.');
    }

    final email = await _resolveLoginEmail(identifier);

    final response = await client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    final authUser = response.user;
    if (authUser == null) {
      throw Exception('Login gagal. User autentikasi tidak ditemukan.');
    }

    final user = await _getActivePublicUserOrThrow(authUser.id);
    final roles = await loadSupportedRoles(user.id, forceRefresh: true);
    if (roles.isEmpty) {
      throw Exception('Akun tidak memiliki role yang didukung.');
    }

    return LoginPrincipal(user: user, roles: roles);
  }

  Future<List<UserRoleRecord>> loadSupportedRoles(
    String userId, {
    bool forceRefresh = false,
  }) async {
    final rows = await roleService.getByUidDirect(userId);
    final dedupByRole = <String, UserRoleRecord>{};

    for (final row in rows) {
      final normalizedRole = normalizeRole(row.role);
      if (!isSupportedRole(normalizedRole)) {
        continue;
      }
      dedupByRole.putIfAbsent(normalizedRole, () => row);
    }

    final roles = dedupByRole.values.toList()
      ..sort((a, b) {
        final aIdx = supportedRoleOrder.indexOf(normalizeRole(a.role));
        final bIdx = supportedRoleOrder.indexOf(normalizeRole(b.role));
        return aIdx.compareTo(bIdx);
      });

    return roles;
  }

  UserRoleRecord resolveRole({
    required List<UserRoleRecord> roles,
    required String? selectedRole,
  }) {
    if (roles.isEmpty) {
      throw Exception('Role tidak ditemukan untuk akun ini.');
    }

    if (selectedRole != null && selectedRole.trim().isNotEmpty) {
      final normalizedRequested = normalizeRole(selectedRole);
      for (final role in roles) {
        if (normalizeRole(role.role) == normalizedRequested) {
          return role;
        }
      }
      throw Exception('Role $selectedRole tidak tersedia untuk akun ini.');
    }

    if (roles.length == 1) {
      return roles.first;
    }

    final labels = roles.map((role) => normalizeRole(role.role)).join(', ');
    throw Exception(
      'Akun memiliki lebih dari satu role: $labels. Pilih role terlebih dahulu.',
    );
  }

  Future<LoginSession> createSession({
    required UserRecord user,
    required UserRoleRecord role,
  }) async {
    final normalizedRole = normalizeRole(role.role);

    switch (normalizedRole) {
      case 'guru':
        var profile = await guruService.getFirstByUid(user.id);
        profile ??= await _ensureGuruProfile(user);
        return LoginSession(user: user, role: role, profile: profile);
      case 'siswa':
        var profile = await siswaService.getFirstByUid(user.id);
        profile ??= await _ensureSiswaProfile(user);
        return LoginSession(user: user, role: role, profile: profile);
      case 'kepala_sekolah':
      case 'kesiswaan':
        return LoginSession(user: user, role: role, profile: null);
      default:
        throw Exception(
          'Role $normalizedRole tidak didukung oleh sistem login.',
        );
    }
  }

  Future<LoginSession> loginWithRole({
    required String usernameOrEmail,
    required String password,
    String? selectedRole,
  }) async {
    final principal = await login(
      usernameOrEmail: usernameOrEmail,
      password: password,
    );
    final matchedRole = resolveRole(
      roles: principal.roles,
      selectedRole: selectedRole,
    );
    return createSession(user: principal.user, role: matchedRole);
  }

  Future<RegisteredUserResult> registerUser({
    required String email,
    required String password,
    required String? username,
    required String nama,
    required List<String> roles,
    bool active = true,
    Map<String, dynamic>? guruProfile,
    Map<String, dynamic>? siswaProfile,
    Map<String, dynamic>? userPayload,
  }) async {
    final normalizedEmail = email.trim();
    final normalizedNama = nama.trim();
    final normalizedUsername = username?.trim();
    final normalizedRoles = roles
        .map(normalizeRole)
        .where((role) => role.isNotEmpty)
        .toSet()
        .toList(growable: false);

    if (normalizedEmail.isEmpty) {
      throw Exception('Email wajib diisi.');
    }
    if (normalizedNama.isEmpty) {
      throw Exception('Nama wajib diisi.');
    }
    if (password.trim().length < 6) {
      throw Exception('Password minimal 6 karakter.');
    }
    if (normalizedRoles.isEmpty) {
      throw Exception('Minimal satu role harus dipilih.');
    }

    final existingByEmail = await userService.getByEmail(normalizedEmail);
    if (existingByEmail.isNotEmpty) {
      throw Exception('Email sudah digunakan oleh akun lain.');
    }

    if (normalizedUsername != null && normalizedUsername.isNotEmpty) {
      final existingByUsername = await userService.getByUsername(
        normalizedUsername,
      );
      if (existingByUsername.isNotEmpty) {
        throw Exception('Username sudah digunakan oleh akun lain.');
      }
    }

    final userPayloadWithoutPassword =
        Map<String, dynamic>.from(userPayload ?? const <String, dynamic>{})
          ..remove('password')
          ..remove('password_changed')
          ..remove('active')
          ..remove('status')
          ..remove('is_deleted');

    final authResponse = await client.auth.signUp(
      email: normalizedEmail,
      password: password,
    );
    final authUser = authResponse.user;
    if (authUser == null) {
      throw Exception('Gagal membuat akun auth Supabase.');
    }

    try {
      final createdUser = await userService.create(<String, dynamic>{
        'id': authUser.id,
        'email': normalizedEmail,
        'username': normalizedUsername,
        'nama': normalizedNama,
        'is_deleted': !active,
        ...userPayloadWithoutPassword,
      });

      final assignedRoles = await roleService.syncRoles(
        uid: authUser.id,
        roles: normalizedRoles,
      );

      GuruRecord? createdGuruProfile;
      if (normalizedRoles.contains('guru') ||
          normalizedRoles.contains('kepala_sekolah') ||
          normalizedRoles.contains('kesiswaan')) {
        createdGuruProfile = await _upsertGuruProfile(
          userId: authUser.id,
          nama: normalizedNama,
          rawData: guruProfile,
        );
      }

      SiswaRecord? createdSiswaProfile;
      if (normalizedRoles.contains('siswa')) {
        createdSiswaProfile = await _upsertSiswaProfile(
          userId: authUser.id,
          nama: normalizedNama,
          rawData: siswaProfile,
        );
      }

      return RegisteredUserResult(
        user: createdUser,
        roles: assignedRoles,
        guruProfile: createdGuruProfile,
        siswaProfile: createdSiswaProfile,
      );
    } catch (error) {
      try {
        await client.from('user_roles').delete().eq('user_id', authUser.id);
      } catch (_) {}
      try {
        await client.from('guru').delete().eq('user_id', authUser.id);
      } catch (_) {}
      try {
        await client.from('siswa').delete().eq('user_id', authUser.id);
      } catch (_) {}
      try {
        await client.from('users').delete().eq('id', authUser.id);
      } catch (_) {}
      rethrow;
    }
  }

  Future<RestoredLoginSession> restoreSession({String? selectedRole}) async {
    final authUser = client.auth.currentUser;
    if (authUser == null) {
      throw Exception('Session auth tidak ditemukan.');
    }

    final user = await _getActivePublicUserOrThrow(authUser.id);
    final roles = await loadSupportedRoles(user.id, forceRefresh: true);
    if (roles.isEmpty) {
      throw Exception('Akun tidak memiliki role aktif yang didukung.');
    }

    final resolvedRole = resolveRole(roles: roles, selectedRole: selectedRole);
    final session = await createSession(user: user, role: resolvedRole);

    return RestoredLoginSession(
      principal: LoginPrincipal(user: user, roles: roles),
      session: session,
    );
  }

  Future<void> logout() async {
    await client.auth.signOut();
  }

  Future<GuruRecord?> _ensureGuruProfile(UserRecord user) async {
    final existing = await guruService.getFirstByUid(user.id);
    if (existing != null) {
      return existing;
    }

    try {
      await guruService.create(<String, dynamic>{
        'user_id': user.id,
        'nama_lengkap': user.nama,
      });
    } catch (_) {}
    return guruService.getFirstByUid(user.id);
  }

  Future<SiswaRecord?> _ensureSiswaProfile(UserRecord user) async {
    final existing = await siswaService.getFirstByUid(user.id);
    if (existing != null) {
      return existing;
    }

    try {
      await siswaService.create(<String, dynamic>{
        'user_id': user.id,
        'nama': user.nama,
      });
    } catch (_) {}
    return siswaService.getFirstByUid(user.id);
  }

  Future<UserRecord> _getActivePublicUserOrThrow(String uid) async {
    final user = await userService.getById(uid);
    if (user == null) {
      throw Exception('Data user untuk UID $uid tidak ditemukan.');
    }
    if (!user.active || user.isDeleted) {
      throw Exception('Akun sudah tidak aktif.');
    }
    return user;
  }

  Future<GuruRecord?> _upsertGuruProfile({
    required String userId,
    required String nama,
    required Map<String, dynamic>? rawData,
  }) async {
    final existing = await guruService.getFirstByUid(userId);
    final payload = <String, dynamic>{
      'user_id': userId,
      'nama_lengkap': nama,
      ...?rawData,
    };

    if (existing == null) {
      return guruService.create(payload);
    }
    return guruService.update(existing.id, payload);
  }

  Future<SiswaRecord?> _upsertSiswaProfile({
    required String userId,
    required String nama,
    required Map<String, dynamic>? rawData,
  }) async {
    final existing = await siswaService.getFirstByUid(userId);
    final payload = <String, dynamic>{
      'user_id': userId,
      'nama': nama,
      ...?rawData,
    };

    if (existing == null) {
      return siswaService.create(payload);
    }
    return siswaService.update(existing.id, payload);
  }

  bool _looksLikeEmail(String value) {
    return value.contains('@');
  }

  Future<String> _resolveLoginEmail(String identifier) async {
    if (_looksLikeEmail(identifier)) {
      return identifier;
    }

    final matchedUsers = await userService.getByUsername(identifier);
    if (matchedUsers.isEmpty) {
      throw Exception(
        'Akun tidak ditemukan. Gunakan email atau username yang terdaftar.',
      );
    }

    final email = matchedUsers.first.email.trim();
    if (email.isEmpty) {
      throw Exception('Akun ditemukan tetapi emailnya kosong.');
    }

    return email;
  }
}
