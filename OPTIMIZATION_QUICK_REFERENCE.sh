#!/usr/bin/env bash
# Quick Reference: Performance Optimization Patterns

# ============================================================================
# OPTIMIZATION QUICK REFERENCE - Copy & Paste Solutions
# ============================================================================

# 🔴 CRITICAL: Implement Pagination
# Before: Load all 500 students at once
# After: Load 50 at a time with offset-based pagination

# FILE: lib/features/kemahasiswaan/providers/manajemen_siswa_kemahasiswaan_firestore_provider.dart

# Step 1: Add pagination state
class ManajemenSiswaKemahasiswaanState {
  final List<KemahasiswaanSiswaItem> data;
  final String? nextPageCursor;  // Add this
  final bool hasMore;             // Add this
  // ... rest of state
}

# Step 2: Use pagination service
Future<void> getSiswaPage({String? pageToken}) async {
  state = state.copyWith(isLoading: true);
  
  try {
    final result = await _ref.read(siswaServiceProvider).getPage(
      pageSize: 50,
      pageToken: pageToken,
      filters: {'status': state.selectedStatus},
    );
    
    state = state.copyWith(
      data: pageToken == null ? result.data : [...state.data, ...result.data],
      nextPageCursor: result.nextPageCursor,
      hasMore: result.hasMore,
      isLoading: false,
    );
  } catch (e) {
    state = state.copyWith(error: e.toString(), isLoading: false);
  }
}

# ============================================================================
# 🔴 CRITICAL: Fix N+1 Query Problem
# Before: 101 reads for student list (roles + users + profiles)
# After: 10 reads (single denormalized query)

# Add these fields to user_roles table:
{
  "uid": "user123",
  "role": "siswa",
  "nama": "Budi Santoso",           # Add - denormalize from users
  "email": "budi@example.com",      # Add - denormalize from users
  "nis": "123456",                  # Add - denormalize from siswa
  "status": "aktif",                # Add - track status here
  "active": true,                   # Add - track active status
  "createdAt": "2024-01-01T...",
  "updatedAt": "2024-01-01T...",
  "isDeleted": false
}

# Update provider to use single query:
Future<void> _fetchSiswaPage({
  required String status,
  required String searchQuery,
  required bool reset,
}) async {
  // ✅ OPTIMIZED: Single query instead of 3 separate queries
  var query = _client
      .from('user_roles')
      .select('id, uid, role, nama, email, nis, status, updatedAt')
      .eq('role', 'siswa')
      .eq('isDeleted', false);
  
  // Apply filters
  if (status != 'semua') {
    query = query.eq('status', normalizeStatus(status));
  }
  
  // Pagination (offset)
  query = query.order('updatedAt', ascending: false);
  final resolvedOffset = nextOffset ?? 0;
  final rows = await query.range(resolvedOffset, resolvedOffset + _pageSize);
  final normalized = _normalizeRows(rows);
  final hasMore = normalized.length > _pageSize;
  final pageRows = hasMore ? normalized.sublist(0, _pageSize) : normalized;
  // Data already has nama, email, nis - no additional queries needed!
}

# ============================================================================
# 🔴 CRITICAL: Remove Duplicate Query from Incremental Fetch

# FILE: lib/services/base_incremental_service.dart
# FIND around line 95: if (rows.isEmpty && cached.isEmpty)

# BEFORE (causes duplicate query):
if (rows.isEmpty && cached.isEmpty) {
  var fullQuery = client.from(collectionPath).select();
  for (final entry in filters.entries) {
    fullQuery = fullQuery.eq(entry.key, entry.value);
  }
  final fallbackRows = await fullQuery;  # ❌ DUPLICATE QUERY
}

# AFTER (just log it):
if (rows.isEmpty && cached.isEmpty) {
  if (kDebugMode) {
    print('ℹ️ Cache miss: No data in $cacheScope');
  }
  // Return empty cache instead of re-querying
}

# ============================================================================
# 🟠 HIGH: Parallelize Startup Queries
# Before: Session → User → Roles → Dashboard (sequential, 3-4s)
# After: All in parallel (1-2s)

# FILE: lib/features/auth/screens/auth_bootstrap_screen.dart

# BEFORE (sequential - slow):
final sessionService = AuthSessionService();
final storedSession = await sessionService.getValidSession();  // Wait
final loginService = ref.read(loginFirestoreServiceProvider);
final restored = await loginService.restoreSession(...);      // Wait
final dashboard = buildDashboard(...);                         // Wait

# AFTER (parallel - fast):
final results = await Future.wait([
  AuthSessionService().getValidSession(),
  _prefetchDashboardData(ref),
]);

final storedSession = results[0] as SessionData?;
final dashboardData = results[1] as DashboardPreload;

Future<DashboardPreload> _prefetchDashboardData(Ref ref) async {
  final data = await Future.wait([
    ref.read(jadwalServiceProvider).getAll(),
    ref.read(kelasServiceProvider).getAll(),
    ref.read(tahunAjaranServiceProvider).getActive(),
  ]);
  return DashboardPreload(
    jadwal: data[0] as List,
    kelas: data[1] as List,
    tahunAjaran: data[2],
  );
}

# ============================================================================
# 🟠 HIGH: Optimize Cache TTL by Data Type

# FILE: lib/features/shared/providers/shared_academic_context_provider.dart

# BEFORE (everything 15 minutes):
static const Duration _ttl = Duration(minutes: 15);

bool _isFresh(DateTime? timestamp) {
  if (timestamp == null) return false;
  return DateTime.now().difference(timestamp) < _ttl;
}

# AFTER (type-specific):
static const Map<String, Duration> _ttlByType = {
  'tahun_ajaran': Duration(hours: 1),    # Rarely changes
  'kelas': Duration(hours: 1),           # Rarely changes
  'mapel': Duration(hours: 1),           # Rarely changes
  'guru': Duration(minutes: 30),         # Changes sometimes
  'jadwal': Duration(minutes: 5),        # Changes frequently
  'nilai': Duration(minutes: 5),         # Changes frequently
  'jurnal': Duration(minutes: 2),        # Real-time (attendance)
  'absensi': Duration(minutes: 2),       # Real-time
};

bool _isFresh(DateTime? timestamp, String dataType) {
  if (timestamp == null) return false;
  final ttl = _ttlByType[dataType] ?? Duration(minutes: 15);
  return DateTime.now().difference(timestamp) < ttl;
}

# Usage:
Future<List<JadwalRecord>> getJadwal() async {
  if (!forceRefresh && _jadwal != null && _isFresh(_jadwalFetchedAt, 'jadwal')) {
    return _jadwal!;
  }
  // Refetch...
}

# ============================================================================
# 🟡 MEDIUM: Implement Parallel Query Execution

# BEFORE (sequential):
final jadwal = await ref.read(jadwalServiceProvider).getByGuruId(guruId);
final kelas = await ref.read(kelasServiceProvider).getAll();
final mapel = await ref.read(mapelServiceProvider).getAll();
// Total time: ~1500ms (sequential)

# AFTER (parallel):
final executor = ParallelQueryExecutor();
final results = await executor.executeAll([
  () => ref.read(jadwalServiceProvider).getByGuruId(guruId),
  () => ref.read(kelasServiceProvider).getAll(),
  () => ref.read(mapelServiceProvider).getAll(),
]);

final [jadwal, kelas, mapel] = results;
// Total time: ~500ms (max of parallel queries)

# ============================================================================
# 🟡 MEDIUM: Move Filtering to Service Layer

# BEFORE (inefficient - loads everything then filters):
final all = await jadwalService.getAll();
final filtered = all.where((item) => 
  item.tahunAjaranId == tahunAjaranId && 
  item.semester == semester
).toList();

# AFTER (efficient - query filter at source):
final filtered = await jadwalService.getByTahunAjaranAndSemester(
  tahunAjaranId: tahunAjaranId,
  semester: semester,
);

# Implement in service:
Future<List<JadwalRecord>> getByTahunAjaranAndSemester({
  required String tahunAjaranId,
  required int semester,
  bool forceFullFetch = false,
}) async {
  return getByFieldsIncremental(
    {
      'tahun_ajaran_id': tahunAjaranId,
      'semester': semester,
      'isDeleted': false,
    },
    forceFullFetch: forceFullFetch,
  );
}

# ============================================================================
# 📊 Performance Monitoring

# Add to any query to track performance:
Future<List<T>> getAll() async {
  final timer = PerfTimer('getAll($collectionPath)');
  try {
    final rows = await client
        .from(collectionPath)
        .select()
        .eq('isDeleted', false);

    final normalized = _normalizeRows(rows);

    // Track the read
    FirestoreMetrics().recordRead(
      collection: collectionPath,
      operation: 'query',
      documentCount: normalized.length,
      fromCache: false,
      latency: timer.elapsed,
    );

    return normalized.map((row) => fromJson(_rowId(row), row)).toList();
  } finally {
    timer.stopIfSlow(thresholdMs: 500);
  }
}

# View metrics:
FirestoreMetrics().printMetrics();
# Output: Prints formatted table with reads, cache hits, latencies

# ============================================================================
# 🧪 Testing Changes

# 1. Add metrics baseline before optimization
dart run test test/performance_test.dart

# 2. Implement one fix at a time
# 3. Re-run tests to measure improvement
# 4. Commit when metrics improve

# ============================================================================
# 📋 CHECKLIST: Week 1 Critical Fixes

# [ ] Denormalize user_roles table
#   - Add: nama, email, nis, status, active
#   - Migrate existing data
#   - Update createSiswa() to write denormalized fields

# [ ] Fix N+1 query in student management
#   - Replace 3-query pattern with single query
#   - Test with 100+ students
#   - Verify reads: 101 → 10

# [ ] Remove incremental fetch fallback
#   - Delete duplicate query logic
#   - Add debug logging
#   - Test cache miss scenarios

# [ ] Implement pagination
#   - Create PaginatedSiswaService
#   - Update UI for infinite scroll
#   - Test smooth loading

# [ ] Test all changes
#   - Load test with 50 concurrent users
#   - Measure query count
#   - Check startup time

# ============================================================================
