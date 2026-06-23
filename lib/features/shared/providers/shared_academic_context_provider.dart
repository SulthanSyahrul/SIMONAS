import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/auth_session_service.dart';
import '../../../models/kelas_model.dart';
import '../../../models/kelas_siswa_model.dart';
import '../../../models/mapel_model.dart';
import '../../../models/siswa_model.dart';
import '../../../models/tahun_ajaran_model.dart';
import '../../../models/user_model.dart';
import '../../../providers/supabase_providers.dart';

typedef ProviderReader = T Function<T>(ProviderListenable<T> provider);

class AppMasterCache {
  static const Duration _ttl = Duration(minutes: 15);

  List<TahunAjaranRecord>? _tahunAjaran;
  List<TahunAjaranRecord>? _tahunAjaranLite;
  List<KelasRecord>? _kelas;
  List<MapelRecord>? _mapel;
  List<UserRecord>? _guru;
  UserRecord? _currentUserProfile;

  DateTime? _tahunAjaranFetchedAt;
  DateTime? _tahunAjaranLiteFetchedAt;
  DateTime? _kelasFetchedAt;
  DateTime? _mapelFetchedAt;
  DateTime? _guruFetchedAt;
  DateTime? _currentUserFetchedAt;

  final Map<String, GuruAcademicContextSnapshot> _guruAcademicContexts = {};
  final Map<String, DateTime> _userProfileFetchedAtByUid = {};
  final Map<String, UserRecord?> _userProfileByUid = {};
  final Map<String, DateTime> _kelasRosterFetchedAt = {};
  final Map<String, List<KelasSiswaRecord>> _kelasRosterMembershipByKelasId =
      {};
  final Map<String, List<UserRecord>> _kelasRosterUsersByKelasId = {};
  final Map<String, List<SiswaRecord>> _kelasRosterSiswaByKelasId = {};

  bool _isFresh(DateTime? timestamp) {
    if (timestamp == null) {
      return false;
    }
    return DateTime.now().difference(timestamp) < _ttl;
  }

  Future<List<TahunAjaranRecord>> getTahunAjaran(
    ProviderReader read, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        _tahunAjaran != null &&
        _isFresh(_tahunAjaranFetchedAt)) {
      return _tahunAjaran!;
    }

    final result = await read(
      tahunAjaranServiceProvider,
    ).getAllIncremental(forceFullFetch: forceRefresh);
    _tahunAjaran = result;
    _tahunAjaranFetchedAt = DateTime.now();
    return result;
  }

  Future<List<TahunAjaranRecord>> getTahunAjaranLite(
    ProviderReader read, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        _tahunAjaranLite != null &&
        _isFresh(_tahunAjaranLiteFetchedAt)) {
      return _tahunAjaranLite!;
    }

    final result = await read(
      tahunAjaranServiceProvider,
    ).getAllLite(includeDeleted: forceRefresh);
    _tahunAjaranLite = result;
    _tahunAjaranLiteFetchedAt = DateTime.now();
    return result;
  }

  Future<List<KelasRecord>> getKelas(
    ProviderReader read, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _kelas != null && _isFresh(_kelasFetchedAt)) {
      return _kelas!;
    }

    final result = await read(
      kelasServiceProvider,
    ).getAllIncremental(forceFullFetch: forceRefresh);
    _kelas = result;
    _kelasFetchedAt = DateTime.now();
    return result;
  }

  Future<List<MapelRecord>> getMapel(
    ProviderReader read, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _mapel != null && _isFresh(_mapelFetchedAt)) {
      return _mapel!;
    }

    final result = await read(
      mapelServiceProvider,
    ).getAllIncremental(forceFullFetch: forceRefresh);
    _mapel = result;
    _mapelFetchedAt = DateTime.now();
    return result;
  }

  Future<List<UserRecord>> getGuru(
    ProviderReader read, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _guru != null && _isFresh(_guruFetchedAt)) {
      return _guru!;
    }

    final guruRecords = await read(
      guruServiceProvider,
    ).getAllLite(includeDeleted: forceRefresh);
    final result = guruRecords
        .map(
          (guru) => UserRecord(
            id: guru.id,
            uid: guru.uid,
            nama: guru.nama,
            email: '',
            status: 'aktif',
            active: !guru.isDeleted,
            username: guru.nama,
            role: 'guru',
            createdAt: guru.createdAt,
            updatedAt: guru.updatedAt,
            deletedAt: guru.deletedAt,
            isDeleted: guru.isDeleted,
          ),
        )
        .toList(growable: false);
    _guru = result;
    _guruFetchedAt = DateTime.now();
    return result;
  }

  Future<UserRecord?> getCurrentUserProfile(
    ProviderReader read, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        _currentUserProfile != null &&
        _isFresh(_currentUserFetchedAt)) {
      return _currentUserProfile;
    }

    final session = await AuthSessionService().getValidSession();
    final userId = session?.userId.trim() ?? '';
    if (userId.isEmpty) {
      _currentUserProfile = null;
      _currentUserFetchedAt = DateTime.now();
      return null;
    }

    final user = await getUserProfileByUid(
      read,
      userId,
      forceRefresh: forceRefresh,
    );
    _currentUserProfile = user;
    _currentUserFetchedAt = DateTime.now();
    return user;
  }

  Future<UserRecord?> getUserProfileByUid(
    ProviderReader read,
    String uid, {
    bool forceRefresh = false,
  }) async {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) {
      return null;
    }

    final cached = _userProfileByUid[normalizedUid];
    final fetchedAt = _userProfileFetchedAtByUid[normalizedUid];
    if (!forceRefresh && cached != null && _isFresh(fetchedAt)) {
      return cached;
    }

    final rows = await read(userServiceProvider).getByUserId(normalizedUid);
    final result = rows.isEmpty ? null : rows.first;
    _userProfileByUid[normalizedUid] = result;
    _userProfileFetchedAtByUid[normalizedUid] = DateTime.now();
    return result;
  }

  Future<Map<String, UserRecord>> getUserMapByUids(
    ProviderReader read,
    Iterable<String> uids, {
    bool forceRefresh = false,
    bool enrichInBackground = true,
  }) async {
    final uniqueUids = uids
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (uniqueUids.isEmpty) {
      return <String, UserRecord>{};
    }

    final fresh = <String, UserRecord>{};
    final missing = <String>[];
    for (final uid in uniqueUids) {
      final cached = _userProfileByUid[uid];
      final fetchedAt = _userProfileFetchedAtByUid[uid];
      if (!forceRefresh && cached != null && _isFresh(fetchedAt)) {
        fresh[uid] = cached;
      } else {
        missing.add(uid);
      }
    }

    if (missing.isNotEmpty) {
      // Fast path: fetch lightweight user data first to reduce UI latency,
      // then trigger a background enriched fetch to update cache with full profile.
      try {
        final lite = await read(userServiceProvider).getByUidsLite(missing);
        for (final user in lite) {
          _userProfileByUid[user.uid] = user;
          _userProfileFetchedAtByUid[user.uid] = DateTime.now();
          fresh[user.uid] = user;
        }
      } catch (_) {
        // ignore fast-path failures and fall back to full fetch
      }

      // Background enriched fetch to update cache with names/roles/etc.
      // Use Future.microtask so we don't need an external `unawaited` helper.
      if (enrichInBackground) {
        Future.microtask(() async {
          try {
            final enriched = await read(userServiceProvider).getByUids(missing);
            for (final user in enriched) {
              _userProfileByUid[user.uid] = user;
              _userProfileFetchedAtByUid[user.uid] = DateTime.now();
              // also update fresh map if present
              fresh[user.uid] = user;
            }
          } catch (_) {
            // ignore background enrichment errors
          }
        });
      }
    }

    return fresh;
  }

  Future<List<UserRecord>> getActiveKelasRoster(
    ProviderReader read,
    String kelasId, {
    bool forceRefresh = false,
    bool enrichWithFullProfiles = true,
  }) async {
    final normalizedKelasId = kelasId.trim();
    if (normalizedKelasId.isEmpty) {
      return <UserRecord>[];
    }

    final fetchedAt = _kelasRosterFetchedAt[normalizedKelasId];
    if (!forceRefresh &&
        _kelasRosterUsersByKelasId.containsKey(normalizedKelasId) &&
        _isFresh(fetchedAt)) {
      return _kelasRosterUsersByKelasId[normalizedKelasId]!;
    }

    final memberships = await read(
      kelasSiswaServiceProvider,
    ).getByKelasIdIncremental(normalizedKelasId, forceFullFetch: forceRefresh);
    final activeMemberships = memberships
        .where((item) => item.status.toLowerCase() == 'aktif')
        .toList(growable: false);
    final usersByUid = await getUserMapByUids(
      read,
      activeMemberships.map((item) => item.siswaId),
      forceRefresh: forceRefresh,
      enrichInBackground: enrichWithFullProfiles,
    );

    final roster = <UserRecord>[];
    for (final membership in activeMemberships) {
      final user = usersByUid[membership.siswaId];
      if (user != null) {
        roster.add(user);
      }
    }
    roster.sort((a, b) => a.nama.toLowerCase().compareTo(b.nama.toLowerCase()));

    _kelasRosterMembershipByKelasId[normalizedKelasId] = activeMemberships;
    _kelasRosterUsersByKelasId[normalizedKelasId] = roster;
    _kelasRosterFetchedAt[normalizedKelasId] = DateTime.now();
    return roster;
  }

  Future<List<SiswaRecord>> getActiveKelasSiswaRoster(
    ProviderReader read,
    String kelasId, {
    bool forceRefresh = false,
  }) async {
    final normalizedKelasId = kelasId.trim();
    if (normalizedKelasId.isEmpty) {
      return <SiswaRecord>[];
    }

    final fetchedAt = _kelasRosterFetchedAt[normalizedKelasId];
    if (!forceRefresh &&
        _kelasRosterSiswaByKelasId.containsKey(normalizedKelasId) &&
        _isFresh(fetchedAt)) {
      return _kelasRosterSiswaByKelasId[normalizedKelasId]!;
    }

    final memberships = await read(
      kelasSiswaServiceProvider,
    ).getByKelasIdIncremental(normalizedKelasId, forceFullFetch: forceRefresh);
    final activeMemberships = memberships
        .where((item) => item.status.toLowerCase() == 'aktif')
        .toList(growable: false);
    final roster = <SiswaRecord>[];
    for (final membership in activeMemberships) {
      roster.add(
        SiswaRecord(
          id: membership.siswaRecordId ?? membership.siswaId,
          uid: membership.siswaId,
          nama: membership.siswaNama,
          email: null,
          noHp: null,
          nis: membership.siswaNis,
          gender: null,
          tempatLahir: null,
          tanggalLahir: null,
          alamat: null,
          isDeleted: false,
        ),
      );
    }
    roster.sort(
      (a, b) => (a.nama ?? a.uid).toLowerCase().compareTo(
        (b.nama ?? b.uid).toLowerCase(),
      ),
    );

    _kelasRosterMembershipByKelasId[normalizedKelasId] = activeMemberships;
    _kelasRosterSiswaByKelasId[normalizedKelasId] = roster;
    _kelasRosterFetchedAt[normalizedKelasId] = DateTime.now();
    return roster;
  }

  List<KelasSiswaRecord> getCachedKelasMembership(String kelasId) {
    return _kelasRosterMembershipByKelasId[kelasId.trim()] ??
        const <KelasSiswaRecord>[];
  }

  Future<GuruAcademicContextSnapshot> getGuruAcademicContext(
    ProviderReader read,
    String selectedYear, {
    int fallbackSemester = 1,
    bool forceRefresh = false,
  }) async {
    final cacheKey = '$selectedYear|$fallbackSemester';
    if (!forceRefresh && _guruAcademicContexts.containsKey(cacheKey)) {
      return _guruAcademicContexts[cacheKey]!;
    }

    final records = await getTahunAjaran(read, forceRefresh: forceRefresh);
    if (records.isEmpty) {
      throw Exception('Data tahun ajaran belum tersedia.');
    }

    TahunAjaranRecord? exactMatch;
    for (final record in records) {
      if (record.nama == selectedYear) {
        exactMatch = record;
        break;
      }
    }

    TahunAjaranRecord? activeRecord;
    for (final record in records) {
      if (record.aktif) {
        activeRecord = record;
        break;
      }
    }

    final target = exactMatch ?? activeRecord ?? records.first;
    final result = GuruAcademicContextSnapshot(
      tahunAjaranId: target.id,
      semester: target.semesterAktif ?? fallbackSemester,
    );
    _guruAcademicContexts[cacheKey] = result;
    return result;
  }

  void clear() {
    _tahunAjaran = null;
    _tahunAjaranLite = null;
    _kelas = null;
    _mapel = null;
    _guru = null;
    _currentUserProfile = null;
    _tahunAjaranFetchedAt = null;
    _tahunAjaranLiteFetchedAt = null;
    _kelasFetchedAt = null;
    _mapelFetchedAt = null;
    _guruFetchedAt = null;
    _currentUserFetchedAt = null;
    _guruAcademicContexts.clear();
    _userProfileFetchedAtByUid.clear();
    _userProfileByUid.clear();
    _kelasRosterFetchedAt.clear();
    _kelasRosterMembershipByKelasId.clear();
    _kelasRosterUsersByKelasId.clear();
    _kelasRosterSiswaByKelasId.clear();
  }
}

class GuruAcademicContextSnapshot {
  final String tahunAjaranId;
  final int semester;

  const GuruAcademicContextSnapshot({
    required this.tahunAjaranId,
    required this.semester,
  });
}

final appMasterCacheProvider = Provider<AppMasterCache>((ref) {
  return AppMasterCache();
});

final sharedAcademicContextCacheProvider = appMasterCacheProvider;
