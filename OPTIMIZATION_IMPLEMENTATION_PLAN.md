# Performance Optimization Implementation Plan

**School**: SMP Negeri 1 Jenar  
**Target Scale**: 500+ Students, 30+ Teachers  
**Start Date**: Week 1 of Optimization Sprint  
**Expected Duration**: 4 weeks

---

## PHASE 1: Critical Fixes (Week 1-2) 🔴

### Task 1.1: Fix N+1 Query in Student Management
**Impact**: 101 reads/page → 10 reads/page (90% reduction)  
**Effort**: 4 hours  
**Owner**: [Assign team member]

#### Steps:
1. **Decide denormalization strategy**
  - [ ] Option A: Add nama, email, nis to user_roles table
  - [ ] Option B: Create student_roster view/table via SQL or Edge Function
  - [ ] Option C: Use parallel batch fetching

2. **For Option A (Recommended)**:
   - [ ] Add fields to user_roles table
   - [ ] Create migration script to populate existing data (SQL or ETL)
   - [ ] Update [manajemen_siswa_kemahasiswaan_firestore_provider.dart](lib/features/kemahasiswaan/providers/manajemen_siswa_kemahasiswaan_firestore_provider.dart):
     ```dart
     // Replace L258-273 with single optimized query
     var query = _client
         .from('user_roles')
         .select('id, uid, role, nama, email, nis, status, updatedAt')
         .eq('role', 'siswa')
         .eq('isDeleted', false)
         .order('nama');
     final resolvedOffset = offset ?? 0;
     final rows = await query.range(resolvedOffset, resolvedOffset + pageSize);
     ```
   - [ ] Update createSiswa() to write denormalized data
   - [ ] Test with 100+ students

3. **For Option B (Cloud Function)**:
   - [ ] Deploy Supabase Edge Function (optional)
   - [ ] Set up database trigger or scheduled job on users table
   - [ ] Query from student_roster view/table instead
   - [ ] Monitor function and database costs

**Success Criteria**:
- [ ] Student list loads in <500ms
- [ ] Page load shows 10 reads in metrics
- [ ] No N+1 warnings in logs

---

### Task 1.2: Fix Incremental Fetch Duplicate Query
**Impact**: Eliminate wasted queries from fallback logic  
**Effort**: 1 hour  
**Owner**: [Assign team member]

#### Steps:
1. [ ] Open [base_incremental_service.dart](lib/services/base_incremental_service.dart)
2. [ ] Find the `if (rows.isEmpty && cached.isEmpty)` block (line ~95)
3. [ ] Replace with logging instead of re-querying:
   ```dart
  if (rows.isEmpty && cached.isEmpty) {
     if (kDebugMode) {
       print('ℹ️ Incremental fetch empty for cache scope: $cacheScope');
     }
     // Don't re-query, just return empty
     return IncrementalFetchResult<T>(
       data: cached,
       lastFetchTime: lastFetch,
       loadedFromCache: true,
     );
   }
   ```
4. [ ] Test with fresh cache scenarios
5. [ ] Verify no duplicate queries in debug logs

**Success Criteria**:
- [ ] No duplicate queries seen in metrics
- [ ] Cache miss logged instead of silently re-queried
- [ ] Fallback behavior documented

---

### Task 1.3: Implement Server-side Pagination
**Impact**: Support efficient loading of 500+ records  
**Effort**: 8 hours  
**Owner**: [Assign team member]

#### Steps:
1. [ ] Use provided [paginated_firestore_service.dart](lib/services/paginated_firestore_service.dart)
2. [ ] Create paginated versions of key services:
   - [ ] PaginatedSiswaService extends PaginatedFirestoreService
   - [ ] PaginatedJadwalService
   - [ ] PaginatedNilaiService
   - [ ] PaginatedJurnalService

3. [ ] Update providers to use pagination:
   ```dart
   class ManajemenSiswaKemahasiswaanNotifier extends StateNotifier<...> {
     Future<void> getSiswaPage({String? pageToken}) async {
       final result = await _ref.read(siswaServiceProvider).getPage(
         pageSize: 50,
         pageToken: pageToken,
         filters: {'status': selectedStatus},
       );
       
       state = state.copyWith(
         data: [...state.data, ...result.data],
         nextPageToken: result.nextPageCursor,
         hasMore: result.hasMore,
       );
     }
   }
   ```

4. [ ] Update UI to support infinite scroll:
   - [ ] Add scroll listener
   - [ ] Trigger `loadMoreSiswa()` at bottom
   - [ ] Show loading indicator

5. [ ] Test with 500 students:
   - [ ] First page loads <500ms
   - [ ] Infinite scroll works smoothly
   - [ ] Memory usage stays constant

**Success Criteria**:
- [ ] Each page loads 50 students efficiently
- [ ] Infinite scroll works smoothly
- [ ] First page: <500ms load time
- [ ] Next pages: <300ms load time

---

## PHASE 2: High Priority (Week 3) 🟠

### Task 2.1: Parallelize Startup Sequence
**Impact**: Auth startup 3s → 1s  
**Effort**: 3 hours  
**Owner**: [Assign team member]

#### Steps:
1. [ ] Create parallel query utilities (provided in [parallel_query_executor.dart](lib/services/parallel_query_executor.dart))

2. [ ] Update [auth_bootstrap_screen.dart](lib/features/auth/screens/auth_bootstrap_screen.dart):
   ```dart
   Future<Widget> _resolveInitialScreen() async {
     // BEFORE: Sequential awaits
     // final stored = await sessionService.getValidSession();
     // final restored = await loginService.restoreSession(...);
     
     // AFTER: Parallel queries
     final results = await Future.wait([
       sessionService.getValidSession(),
       loginService.getMetadata(), // Pre-cache metadata
     ]);
     
     final stored = results[0] as ...;
     // ...
   }
   ```

3. [ ] Update dashboard initialization:
   ```dart
   // Load dashboard data in parallel
   final dashboardData = await Future.wait([
     jadwalService.getByGuruId(guruId),
     kelasService.getAll(),
     mapelService.getAll(),
     tahunAjaranService.getActive(),
   ]);
   ```

4. [ ] Measure startup time improvement

**Success Criteria**:
- [ ] Startup waterfall reduced by 50%
- [ ] Auth time: 1-2 seconds
- [ ] Dashboard ready in parallel

---

### Task 2.2: Optimize Cache TTL
**Impact**: Real-time data freshness, less stale data  
**Effort**: 2 hours  
**Owner**: [Assign team member]

#### Steps:
1. [ ] Update [shared_academic_context_provider.dart](lib/features/shared/providers/shared_academic_context_provider.dart):
   ```dart
   // OLD: static const Duration _ttl = Duration(minutes: 15);
   
   // NEW: Type-specific TTLs
   static const Map<String, Duration> _ttlByType = {
     'tahun_ajaran': Duration(hours: 1),
     'kelas': Duration(hours: 1),
     'mapel': Duration(hours: 1),
     'guru': Duration(minutes: 30),
     'jadwal': Duration(minutes: 5),
     'jurnal': Duration(minutes: 2),
     'nilai': Duration(minutes: 5),
     'absensi': Duration(minutes: 2),
   };
   
   bool _isFresh(DateTime? timestamp, String dataType) {
     if (timestamp == null) return false;
     final ttl = _ttlByType[dataType] ?? Duration(minutes: 15);
     return DateTime.now().difference(timestamp) < ttl;
   }
   ```

2. [ ] Add manual cache invalidation on mutations:
   ```dart
   // When a grade is updated
   await nilaiService.update(id, data);
   await academicCache.invalidate('nilai'); // Force refresh next access
   ```

3. [ ] Test data freshness:
   - [ ] Update jadwal, verify UI updates <5 minutes
   - [ ] Update grade, verify UI updates <5 minutes

**Success Criteria**:
- [ ] TTL values match data change frequency
- [ ] Manual invalidation works
- [ ] No stale data persists >5 minutes

---

### Task 2.3: Add Missing Postgres Indexes
**Impact**: Query performance, reduced full scans  
**Effort**: 1 hour  
**Owner**: [Assign team member]

#### Steps:
1. [ ] Add indexes via Supabase SQL editor:
   ```sql
   create index if not exists user_roles_role_deleted_updated_at_idx
     on user_roles (role, isDeleted, updatedAt desc);

   create index if not exists users_uid_deleted_idx
     on users (uid, isDeleted);
   ```

2. [ ] Wait for indexing to complete
3. [ ] Verify queries use indexes (check Supabase query planner)

**Success Criteria**:
- [ ] Indexes deployed
- [ ] No index warnings in Supabase query planner
- [ ] Queries show index usage

---

## PHASE 3: Medium Priority (Week 4) 🟡

### Task 3.1: Replace SharedPreferences Caching
**Impact**: Faster cache operations, better memory  
**Effort**: 6 hours  
**Owner**: [Assign team member]

#### Steps:
1. [ ] Add dependencies to pubspec.yaml:
   ```yaml
   hive: ^2.2.3
   hive_flutter: ^1.1.0
   ```

2. [ ] Create cache adapter:
   ```dart
   // lib/core/services/hive_cache_service.dart
   class HiveCacheService {
     late Box _cacheBox;
     
     Future<void> init() async {
      _cacheBox = await Hive.openBox('app_cache');
     }
     
     Future<void> saveCollection(String key, List<T> items) async {
       await _cacheBox.put(key, items); // Direct object storage
     }
     
     Future<List<T>?> getCollection(String key) async {
       return _cacheBox.get(key);
     }
   }
   ```

3. [ ] Migrate cache_service.dart to use Hive
4. [ ] Update cache initialization in main.dart
5. [ ] Test with large datasets:
   - [ ] 500 students cache
   - [ ] 1000+ jadwal entries
   - [ ] Verify no SharedPreferences size limits

**Success Criteria**:
- [ ] Cache operations <10ms
- [ ] No SharedPreferences size warnings
- [ ] Memory usage reduced by 30%

---

### Task 3.2: Implement Query Parallelization
**Impact**: Reduce waterfall dependencies  
**Effort**: 4 hours  
**Owner**: [Assign team member]

#### Steps:
1. [ ] Use [parallel_query_executor.dart](lib/services/parallel_query_executor.dart)
2. [ ] Identify sequential query chains:
   - [ ] Find all `await X; await Y;` patterns
   - [ ] Convert to `await Future.wait([X, Y])`

3. [ ] Update key providers:
   - [ ] [jadwal_guru_firestore_provider.dart](lib/features/guru/providers/jadwal_guru_firestore_provider.dart)
   - [ ] [nilai_guru_firestore_provider.dart](lib/features/guru/providers/nilai_guru_firestore_provider.dart)
   - [ ] Dashboard providers

4. [ ] Test latency improvements

**Success Criteria**:
- [ ] All independent queries run in parallel
- [ ] Waterfall depth reduced
- [ ] Latency improvements measured

---

### Task 3.3: Move Filtering to Service Layer
**Impact**: Reduce client-side processing  
**Effort**: 3 hours  
**Owner**: [Assign team member]

#### Steps:
1. [ ] Find all client-side filters:
   - [ ] Search for `.where(` patterns in providers
   - [ ] Search for `.filter(` patterns

2. [ ] Move to service layer:
   ```dart
   // BEFORE: Filter in memory
   final all = await jadwalService.getAll();
   final filtered = all.where((j) => j.tahunAjaranId == tahunId).toList();
   
   // AFTER: Query filter at source
   final filtered = await jadwalService.getByTahunAjaran(tahunId);
   ```

3. [ ] Add query variants to services
4. [ ] Test with large datasets

**Success Criteria**:
- [ ] No client-side filtering
- [ ] All filtering at Firestore layer
- [ ] Memory usage reduced

---

## PHASE 4: Performance Monitoring (Ongoing) 📊

### Task 4.1: Implement Metrics Tracking
**Effort**: 2 hours  
**Owner**: [Assign team member]

#### Steps:
1. [ ] Use provided [firestore_metrics.dart](lib/core/services/firestore_metrics.dart)
2. [ ] Integrate into base services:
   ```dart
   Future<List<T>> getAll() async {
     final timer = PerfTimer('getAll($collectionPath)');
     try {
       final data = await _fetchData();
       FirestoreMetrics().recordRead(
         collection: collectionPath,
         operation: 'query',
         documentCount: data.length,
         fromCache: false,
         latency: timer.elapsed,
       );
       return data;
     } finally {
       timer.stop();
     }
   }
   ```

3. [ ] Create debug dashboard:
   - [ ] Show live metrics
   - [ ] Display cache hit rate
   - [ ] Show hot paths (slowest queries)

4. [ ] Set up baseline metrics

---

## Testing & Validation

### Load Testing
```bash
# Test with 100 concurrent users
flutter drive --target=test_driver/perf_test.dart
```

### Metrics Baseline (Before Optimization)
- Current reads per session: 500-800
- Startup time: 3-4s
- Student list latency: 2-3s
- Cache hit rate: ~40%
- Monthly estimated cost: $1,200

### Metrics Target (After Optimization)
- Target reads per session: 80-120
- Startup time: 1s
- Student list latency: <500ms
- Cache hit rate: >80%
- Monthly estimated cost: $180-250

---

## Risk Mitigation

### Data Consistency
- [ ] Add tests for denormalization sync
- [ ] Monitor for data drift
- [ ] Implement consistency checks

### Backwards Compatibility
- [ ] Feature flag old vs new code paths
- [ ] Gradual rollout (10% → 50% → 100%)
- [ ] Monitor error rates

### Rollback Plan
- [ ] Document current indexes
- [ ] Save current service implementations
- [ ] Have quick-revert checklist

---

## Team Assignments

| Task | Owner | Start Date | Due Date | Status |
|------|-------|-----------|----------|--------|
| 1.1: N+1 Fix | TBD | Week 1 Mon | Week 1 Tue | ⏳ |
| 1.2: Duplicate Query | TBD | Week 1 Wed | Week 1 Wed | ⏳ |
| 1.3: Pagination | TBD | Week 1 Thu | Week 2 Wed | ⏳ |
| 2.1: Parallel Startup | TBD | Week 3 Mon | Week 3 Tue | ⏳ |
| 2.2: Cache TTL | TBD | Week 3 Wed | Week 3 Thu | ⏳ |
| 2.3: Indexes | TBD | Week 3 Fri | Week 3 Fri | ⏳ |
| 3.1: Hive Cache | TBD | Week 4 Mon | Week 4 Wed | ⏳ |
| 3.2: Parallelization | TBD | Week 4 Thu | Week 4 Fri | ⏳ |
| 3.3: Service Filters | TBD | Week 4 Fri | Week 4 Fri | ⏳ |
| 4.1: Metrics | TBD | Ongoing | Ongoing | ⏳ |

---

## Success Criteria Checklist

### Phase 1 Completion
- [ ] Student list: 101 reads → 10 reads
- [ ] No duplicate queries from incremental fetch
- [ ] Pagination implemented on 3+ screens
- [ ] Load test: 50 concurrent users smooth

### Phase 2 Completion
- [ ] Startup time: 3s → 1-2s
- [ ] All TTLs optimized per data type
- [ ] Firestore indexes deployed
- [ ] Load test: 100 concurrent users smooth

### Phase 3 Completion
- [ ] Hive cache integrated
- [ ] No sequential query chains
- [ ] Client-side filtering removed
- [ ] Load test: 200 concurrent users smooth

### Project Completion
- [ ] All 500 students load smoothly
- [ ] Cache hit rate >80%
- [ ] Monthly costs reduced 80%
- [ ] All team trained on patterns
- [ ] Performance monitoring active

---

## Sign-Off

**Project Lead**: _____________________ Date: _________  
**Tech Lead**: _____________________ Date: _________  
**QA Lead**: _____________________ Date: _________

