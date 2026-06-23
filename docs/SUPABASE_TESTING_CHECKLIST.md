-- Comprehensive Testing Checklist for Supabase Migration
-- Document: SUPABASE_TESTING_CHECKLIST.md
-- Purpose: Validation tests for Firebase to Supabase migration

# Supabase Migration - Comprehensive Testing Checklist

## Phase 1: Data Migration Validation

### 1.1 Data Count Verification

- [ ] Total users count matches Firebase export
  - Command: `SELECT count(*) FROM users WHERE is_deleted = false;`
  - Expected: {firebase_count}

- [ ] Total guru count matches
  - Command: `SELECT count(*) FROM guru WHERE is_deleted = false;`
  - Expected: {firebase_count}

- [ ] Total siswa count matches
  - Command: `SELECT count(*) FROM siswa WHERE is_deleted = false;`
  - Expected: {firebase_count}

- [ ] Total jurnal count matches
  - Command: `SELECT count(*) FROM jurnal WHERE is_deleted = false;`
  - Expected: {firebase_count}

- [ ] Total nilai count matches
  - Command: `SELECT count(*) FROM nilai WHERE is_deleted = false;`
  - Expected: {firebase_count}

- [ ] Total kelas count matches
  - Command: `SELECT count(*) FROM kelas WHERE is_deleted = false;`
  - Expected: {firebase_count}

- [ ] Total jadwal count matches
  - Command: `SELECT count(*) FROM jadwal WHERE is_deleted = false;`
  - Expected: {firebase_count}

### 1.2 Referential Integrity Tests

- [ ] No orphaned guru records (user_id not in users)
  ```sql
  SELECT count(*) FROM guru WHERE user_id NOT IN (SELECT id FROM users) AND is_deleted = false;
  -- Expected: 0
  ```

- [ ] No orphaned siswa records
  ```sql
  SELECT count(*) FROM siswa WHERE user_id NOT IN (SELECT id FROM users) AND is_deleted = false;
  -- Expected: 0
  ```

- [ ] No orphaned jurnal records (guru_uid not in users)
  ```sql
  SELECT count(*) FROM jurnal WHERE guru_uid NOT IN (SELECT id FROM users) AND is_deleted = false;
  -- Expected: 0
  ```

- [ ] No orphaned jadwal records
  ```sql
  SELECT count(*) FROM jadwal WHERE guru_uid NOT IN (SELECT id FROM users) AND is_deleted = false;
  -- Expected: 0
  ```

- [ ] No orphaned nilai records
  ```sql
  SELECT count(*) FROM nilai 
  WHERE (siswa_uid NOT IN (SELECT id FROM users) 
     OR guru_uid NOT IN (SELECT id FROM users))
  AND is_deleted = false;
  -- Expected: 0
  ```

- [ ] No orphaned kelas_siswa records
  ```sql
  SELECT count(*) FROM kelas_siswa 
  WHERE (kelas_id NOT IN (SELECT id FROM kelas) 
     OR siswa_uid NOT IN (SELECT id FROM users))
  AND is_deleted = false;
  -- Expected: 0
  ```

### 1.3 Data Quality Tests

- [ ] No duplicate emails in users table
  ```sql
  SELECT email FROM users WHERE is_deleted = false GROUP BY email HAVING count(*) > 1;
  -- Expected: (no results)
  ```

- [ ] All email addresses are valid format
  ```sql
  SELECT count(*) FROM users WHERE email NOT LIKE '%@%.%' AND is_deleted = false;
  -- Expected: 0
  ```

- [ ] No null required fields in users
  ```sql
  SELECT count(*) FROM users WHERE (email IS NULL OR nama IS NULL) AND is_deleted = false;
  -- Expected: 0
  ```

- [ ] All timestamps are valid
  ```sql
  SELECT count(*) FROM users WHERE created_at > updated_at;
  -- Expected: 0
  ```

- [ ] Kelas entries have valid tingkat (7, 8, or 9)
  ```sql
  SELECT count(*) FROM kelas WHERE tingkat NOT IN (7, 8, 9) AND is_deleted = false;
  -- Expected: 0
  ```

- [ ] Nilai semester is 1 or 2
  ```sql
  SELECT count(*) FROM nilai WHERE semester NOT IN (1, 2) AND is_deleted = false;
  -- Expected: 0
  ```

- [ ] Jadwal hari_ke is between 1-5 (Monday-Friday)
  ```sql
  SELECT count(*) FROM jadwal WHERE hari_ke NOT BETWEEN 1 AND 5 AND is_deleted = false;
  -- Expected: 0
  ```

## Phase 2: Authentication Testing

### 2.1 Supabase Auth Integration

- [ ] **User Sign Up Works**
  - Create new account with valid email/password
  - Verify user appears in `users` table
  - Verify user appears in Supabase Auth dashboard
  - Clean up test account

- [ ] **User Sign In Works**
  - Login with valid credentials
  - Verify JWT token is returned
  - Verify user session is established

- [ ] **Password Reset Works**
  - Request password reset
  - Verify email is sent
  - Click reset link
  - Set new password
  - Login with new password succeeds

- [ ] **User Roles Are Assigned**
  - Create user with 'guru' role
  - Verify entry in `user_roles` table
  - Verify `getUserRole()` returns correct role
  - Create user with 'siswa' role and verify

- [ ] **Invalid Credentials Rejected**
  - Attempt login with wrong password → fails
  - Attempt login with non-existent email → fails
  - Attempt signup with existing email → fails

### 2.2 Role-Based Access Control

- [ ] **Kepsek can access all data**
  - Login as kepsek user
  - Verify can read all journals
  - Verify can read all grades
  - Verify can read all user profiles

- [ ] **Guru can only access own data**
  - Login as guru1
  - Verify can read own journals
  - Verify can read own grades (as assigned teacher)
  - Verify cannot read guru2's journals
  - Verify cannot modify guru2's schedules

- [ ] **Siswa can only access own data**
  - Login as siswa1
  - Verify can read own grades
  - Verify can read own attendance
  - Verify cannot read other students' grades
  - Verify cannot modify any grades

- [ ] **Kemahasiswaan can manage students**
  - Login as kemahasiswaan user
  - Verify can create new student
  - Verify can update student data
  - Verify can view all student profiles
  - Verify cannot create users (admin only)

## Phase 3: Service Layer Tests

### 3.1 BaseFirestoreService Tests

- [ ] **Create Operation**
  ```dart
  final service = GuruFirestoreService();
  final guru = {
    'nama_guru': 'Test Guru',
    'email_guru': 'test@school.com',
  };
  await service.create(guru, id: 'test-id');
  final fetched = await service.getById('test-id');
  expect(fetched?.namaGuru, equals('Test Guru'));
  ```

- [ ] **Read Operation**
  - Create record
  - Fetch by ID
  - Verify all fields match

- [ ] **Update Operation**
  - Create record
  - Update a field
  - Fetch and verify update
  - Verify updatedAt timestamp changed

- [ ] **Delete Operation (Soft)**
  - Create record
  - Delete record
  - Verify isDeleted = true
  - Verify getById returns null

- [ ] **List Operation**
  - Create 5 test records
  - Call getAll()
  - Verify returns only non-deleted records
  - Verify count = 5

### 3.2 PaginatedFirestoreService Tests

- [ ] **First Page Fetch**
  - Get first page (pageSize=10)
  - Verify returns exactly 10 items
  - Verify hasMore = true (if total > 10)
  - Verify nextPageCursor is not null

- [ ] **Next Page Fetch**
  - Get first page with cursor1
  - Get second page with cursor1
  - Verify different items returned
  - Verify no overlapping IDs

- [ ] **Last Page Fetch**
  - Navigate to last page
  - Verify hasMore = false
  - Verify nextPageCursor = null

- [ ] **Filter with Pagination**
  - Get paginated results with filters
  - Verify all results match filter criteria
  - Verify pagination still works

- [ ] **Sorting**
  - Test ascending sort
  - Test descending sort
  - Verify items are properly ordered

### 3.3 Incremental Service Tests

- [ ] **Incremental Sync**
  - Fetch all data first
  - Store lastFetchTime
  - Modify one record
  - Fetch incremental (since lastFetchTime)
  - Verify only modified record returned

- [ ] **Cache Operations**
  - Load and save to cache
  - Clear local data
  - Load from cache
  - Verify cache contains correct data

- [ ] **Empty Result Handling**
  - No changes since last fetch
  - Call incremental sync
  - Verify returns empty list
  - Verify loadedFromCache = true

## Phase 4: Feature Provider Tests

### 4.1 Authentication Provider Tests

```dart
test('Auth provider reflects login state', () async {
  final container = ProviderContainer();
  
  // Initially no user
  final initialState = container.read(currentUserProvider);
  expect(initialState, isA<AsyncValue<User?>>());
  
  // After login
  final authService = container.read(authServiceProvider);
  await authService.signIn(email: 'test@school.com', password: 'password');
  
  final loggedInState = container.read(currentUserProvider);
  expect(loggedInState.value, isNotNull);
});
```

### 4.2 Jurnal Provider Tests

- [ ] **Fetch Journal by Teacher**
  - Login as guru
  - Fetch journals for specific date range
  - Verify returns only own journals
  - Verify data structure matches model

- [ ] **Create Journal Entry**
  - Login as guru
  - Create new journal
  - Verify appears in database
  - Verify attendance records created

- [ ] **Update Journal**
  - Login as guru
  - Update journal entry
  - Verify changes saved
  - Verify updatedAt timestamp updated

- [ ] **Journal Pagination**
  - Get first page of journals
  - Verify pagination works
  - Navigate through pages

### 4.3 Nilai Provider Tests

- [ ] **Fetch Grades**
  - Login as guru
  - Fetch grades for class/subject
  - Verify returns only assigned grades

- [ ] **Create/Update Grade**
  - Create new grade record
  - Verify calculation works (nilai_akhir = (uts+uas)/2)
  - Update grade
  - Verify not allowed to update grade of another teacher

- [ ] **Student View Grades**
  - Login as student
  - View own grades
  - Verify all grades displayed
  - Verify cannot modify any grade

### 4.4 Jadwal Provider Tests

- [ ] **Fetch Teacher Schedule**
  - Login as guru
  - Fetch schedule
  - Verify returns own classes
  - Verify no conflicts/overlaps

- [ ] **Fetch Class Schedule**
  - Get schedule for class 7A
  - Verify all subjects listed
  - Verify no time overlaps

## Phase 5: UI/Integration Tests

### 5.1 Login Screen Tests

```dart
testWidgets('Login succeeds with valid credentials', (WidgetTester tester) async {
  await tester.pumpWidget(const MyApp());
  
  // Find text fields
  final emailField = find.byType(TextField).at(0);
  final passwordField = find.byType(TextField).at(1);
  
  // Enter credentials
  await tester.enterText(emailField, 'guru@school.com');
  await tester.enterText(passwordField, 'password123');
  
  // Tap login button
  await tester.tap(find.byType(ElevatedButton));
  await tester.pumpAndSettle();
  
  // Verify navigation to home
  expect(find.text('Home'), findsOneWidget);
});
```

- [ ] **Valid Login**
  - Enter correct email/password
  - Verify navigates to home screen

- [ ] **Invalid Password**
  - Enter wrong password
  - Verify error message shown
  - Verify stays on login screen

- [ ] **Non-existent Email**
  - Enter non-existent email
  - Verify error message shown

- [ ] **Empty Fields**
  - Try submit with empty fields
  - Verify validation errors shown

### 5.2 Data Display Tests

- [ ] **Journal List Screen**
  - Login as guru
  - Navigate to journal list
  - Verify journals display correctly
  - Verify pagination works (scroll loads more)

- [ ] **Grade Entry Screen**
  - Login as guru
  - Navigate to grade entry
  - Verify students listed
  - Verify can enter grades
  - Verify auto-calculation works

- [ ] **Schedule Screen**
  - Login as guru
  - View schedule
  - Verify all classes shown
  - Verify grouped by day/time

- [ ] **Student Dashboard**
  - Login as student
  - Verify shows own data only
  - Verify grades, attendance, schedules display

### 5.3 CRUD Operations Tests

- [ ] **Create Operation**
  - Create new journal entry
  - Verify appears in list
  - Verify can edit immediately

- [ ] **Update Operation**
  - Edit existing record
  - Verify changes saved
  - Verify displayed correctly

- [ ] **Delete Operation**
  - Delete record
  - Verify removed from list
  - Verify soft-deleted (can be recovered if needed)

## Phase 6: Performance Tests

### 6.1 Query Performance

- [ ] **Large Dataset Query** (1000+ records)
  - Measure query time: target < 500ms
  - Fetch 1000 jurnal records
  - Verify completion within time limit

- [ ] **Pagination Performance**
  - Fetch multiple pages sequentially
  - Verify consistent response time (~200ms per page)
  - No N+1 queries

- [ ] **Filter Performance**
  - Query with multiple filters
  - Verify indexes being used
  - Explain plan shows index usage

### 6.2 Sync Performance

- [ ] **Initial Sync**
  - Full sync of all data
  - Measure total time
  - Target < 5 seconds for typical dataset

- [ ] **Incremental Sync**
  - Incremental sync after full sync
  - Measure delta time
  - Should be < 500ms if few changes

### 6.3 Storage Performance

- [ ] **File Upload** (5MB document)
  - Upload time < 10 seconds
  - File verified in storage bucket
  - No errors/truncation

- [ ] **File Download**
  - Download time proportional to size
  - File content matches original

## Phase 7: RLS Policy Tests

### 7.1 Teacher Access Control

- [ ] **Guru can read own journals**
  ```sql
  SET auth.uid() to 'guru1-uuid';
  SELECT count(*) FROM jurnal WHERE guru_uid = auth.uid() AND is_deleted = false;
  -- Expected: > 0
  ```

- [ ] **Guru cannot read other guru's journals**
  ```sql
  SET auth.uid() to 'guru1-uuid';
  SELECT count(*) FROM jurnal WHERE guru_uid = 'guru2-uuid' AND is_deleted = false;
  -- Expected: 0 (policy blocks)
  ```

### 7.2 Student Access Control

- [ ] **Siswa can read own grades**
  ```sql
  SET auth.uid() to 'siswa1-uuid';
  SELECT count(*) FROM nilai WHERE siswa_uid = auth.uid() AND is_deleted = false;
  -- Expected: > 0
  ```

- [ ] **Siswa cannot read other students' grades**
  ```sql
  SET auth.uid() to 'siswa1-uuid';
  SELECT count(*) FROM nilai WHERE siswa_uid = 'siswa2-uuid' AND is_deleted = false;
  -- Expected: 0 (policy blocks)
  ```

### 7.3 Principal Access Control

- [ ] **Kepsek can read all data**
  ```sql
  SET auth.uid() to 'kepsek-uuid';
  SELECT count(*) FROM jurnal WHERE is_deleted = false;
  -- Expected: all journals
  ```

## Phase 8: Error Handling Tests

- [ ] **Network Timeout**
  - Disconnect network during operation
  - Verify graceful error message
  - Verify can retry

- [ ] **Invalid Data**
  - Attempt insert with invalid FK
  - Verify constraint violation error
  - Verify user-friendly message shown

- [ ] **Concurrent Updates**
  - Two users update same record
  - Verify last-write-wins behavior
  - Verify no data corruption

- [ ] **Auth Token Expiry**
  - Wait for token to expire
  - Attempt operation
  - Verify auto-refresh or re-login prompt

## Phase 9: Migration Rollback Tests

- [ ] **Backup Validity**
  - Restore from backup
  - Verify all data intact
  - Verify can query successfully

- [ ] **Rollback Procedure**
  - Delete migrated data
  - Restore from backup
  - Verify Firebase data still available

## Phase 10: Production Readiness

### 10.1 Security Checklist

- [ ] RLS policies enabled on all tables
- [ ] No direct table access via anon key
- [ ] Sensitive data (passwords) not in app
- [ ] API keys not hardcoded (use env vars)
- [ ] HTTPS enforced
- [ ] SQL injection prevention (parameterized queries)
- [ ] XSS prevention (input validation)

### 10.2 Performance Checklist

- [ ] Database indexes created on all filtered columns
- [ ] Query performance acceptable (< 500ms)
- [ ] Pagination implemented
- [ ] Caching strategy implemented
- [ ] No N+1 queries
- [ ] Database metrics monitored

### 10.3 Monitoring Checklist

- [ ] Logging configured
- [ ] Error tracking enabled
- [ ] Performance monitoring setup
- [ ] Database query logs reviewed
- [ ] Auth logs reviewed

## Success Criteria

✅ All data migration validation passes (Phase 1)
✅ All authentication tests pass (Phase 2)
✅ All service tests pass (Phase 3)
✅ All feature provider tests pass (Phase 4)
✅ All UI/integration tests pass (Phase 5)
✅ Performance meets targets (Phase 6)
✅ RLS policies enforce access correctly (Phase 7)
✅ Error handling works properly (Phase 8)
✅ Rollback procedure validated (Phase 9)
✅ Production readiness verified (Phase 10)

## Sign-off

- [ ] QA Lead: __________________ Date: __________
- [ ] Tech Lead: ________________ Date: __________
- [ ] Project Manager: __________ Date: __________

---

**Next Steps After Testing:**
1. Deploy to production
2. Set up monitoring/alerting
3. Train users on new system
4. Archive Firebase data
5. Schedule maintenance windows for final sync
