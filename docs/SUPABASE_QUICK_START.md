-- Quick Start Guide: From Firebase to Supabase
-- Document: SUPABASE_QUICK_START.md
-- Purpose: Fast-track guide for developers to get started

# Supabase Migration - Quick Start Guide

**For**: Developers ready to deploy the migrated application  
**Time**: 2-3 hours for complete setup  
**Prerequisites**: Supabase account, Flutter environment

---

## ⚡ Super Quick Start (TL;DR)

```bash
# 1. Update config (5 min)
# Edit: lib/core/config/supabase_config.dart
projectUrl = 'https://YOUR_PROJECT_ID.supabase.co'
publishableKey = 'YOUR_ANON_KEY'

# 2. Create database (10 min)
# Copy content from: supabase/migrations/001_create_schema.sql
# Paste into: Supabase Dashboard → SQL Editor → Run

# 3. Export Firebase data (15 min)
# Firebase Console → Firestore → Export Collections

# 4. Migrate data (30 min)
# Follow: docs/SUPABASE_DATA_MIGRATION_GUIDE.md

# 5. Set up RLS (20 min)
# Follow: docs/SUPABASE_RLS_POLICIES.md

# 6. Test app (30 min)
# flutter run
# Login test (from SUPABASE_TESTING_CHECKLIST.md)
```

---

## Step-by-Step Setup (30 Minutes)

### 1️⃣ Create Supabase Project (5 min)

1. Go to [supabase.com](https://supabase.com)
2. Click **New Project**
3. Fill in:
   - **Project Name**: pengawasan-kelas
   - **Database Password**: (generate strong password)
   - **Region**: Choose closest to Indonesia (Singapore if available)
   - **Pricing Plan**: Free tier is fine for testing
4. Click **Create**
5. Wait 2-3 minutes for project to initialize

### 2️⃣ Get Credentials (2 min)

1. Go to **Settings** → **API**
2. Copy these values:
   - **Project URL**: `https://[project-id].supabase.co`
   - **Anon Public**: (your anon key)
   - **Service Role**: (save for server-side use later)

3. Also note **Storage Bucket** name (usually first bucket created)

### 3️⃣ Update Flutter Config (5 min)

**File**: `lib/core/config/supabase_config.dart`

```dart
class SupabaseConfig {
  const SupabaseConfig._();

  // 🔴 REPLACE THESE WITH YOUR ACTUAL VALUES:
  static const String projectUrl = 'https://YOUR_PROJECT_ID.supabase.co';
  // Example: https://xyzabc123.supabase.co

  static const String publishableKey = 'YOUR_SUPABASE_ANON_KEY';
  // Example: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

  static const String storageBucket = 'YOUR_STORAGE_BUCKET';
  // Example: administrasi_pembelajaran
}
```

### 4️⃣ Create Database Schema (10 min)

1. **Copy schema file**:
   ```bash
   # Copy entire content from:
   supabase/migrations/001_create_schema.sql
   ```

2. **Run in Supabase**:
   - Go to Supabase Dashboard
   - Click **SQL Editor**
   - Click **New Query**
   - Paste the SQL
   - Click **Run**
   - Wait for completion (should take 10-20 seconds)

3. **Verify**:
   - Go to **Database** → **Tables**
   - Should see 16 tables: users, guru, siswa, kelas, jadwal, jurnal, etc.

### 5️⃣ Compile Flutter App (3 min)

```bash
# Get dependencies
flutter pub get

# Build app
flutter run

# Or if using Android:
flutter run -d android-device
```

### 6️⃣ Test Sign Up (5 min)

1. **Open app** in emulator/device
2. **Go to login screen**
3. **Sign up new account**:
   - Email: `test@example.com`
   - Password: `password123`
   - Nama: `Test User`
   - NIP: `12345678`
4. **Verify**: Should see confirmation message
5. **Check Supabase Dashboard**:
   - Auth → Users: Should see your test user
   - Database → users table: Should see user record

### 7️⃣ Test Login (2 min)

1. **Close/reopen app**
2. **Login with credentials**: test@example.com / password123
3. **Verify**: Should navigate to home screen
4. **Success!** ✅

---

## What's Ready to Use

### Services (17 Total)
```dart
final guruService = GuruFirestoreService();
final siswaService = SiswaFirestoreService();
final jurnalService = JurnalFirestoreService();
// ... all services use Supabase client automatically
```

### State Management (Riverpod)
```dart
// In any widget/provider:
final authService = ref.watch(authServiceProvider);
final currentUser = ref.watch(currentUserProvider);
final userRole = ref.watch(userRoleProvider);
```

### Authentication
```dart
// Sign up
await authService.signUp(
  email: 'guru@school.com',
  password: 'password123',
  nama: 'John Doe',
  nip: '19800101200001',
);

// Sign in
await authService.signIn(
  email: 'guru@school.com',
  password: 'password123',
);

// Sign out
await authService.signOut();

// Check role
bool isGuru = await authService.hasRole('guru');
```

### Data Operations
```dart
// Create
await guruService.create({'nama_guru': 'John', 'nip': '123'});

// Read
final guru = await guruService.getById('guru-id');
final allGuru = await guruService.getAll();

// Update
await guruService.update('guru-id', {'nama_guru': 'Jane'});

// Delete (soft)
await guruService.delete('guru-id');

// Paginated query
final page = await jurnalService.getPage(
  pageSize: 10,
  filters: {'guru_uid': 'my-id'},
);
```

### File Upload
```dart
// Upload avatar
final url = await storageService.uploadAvatar(
  userId: userId,
  imageFile: File('/path/to/image.jpg'),
);

// Upload document
final docUrl = await storageService.uploadAdministrasiDocument(
  guruId: guruId,
  document: File('/path/to/document.pdf'),
);
```

---

## Migration Path (If Coming from Firebase)

### Option A: Quick Test (No Production Data)
1. Set up Supabase project
2. Create test accounts in UI
3. Create test data in app
4. Verify everything works
5. Ready for production!

### Option B: Migrate Existing Data
1. Set up Supabase project (steps 1-4 above)
2. Export Firebase data:
   ```bash
   firebase firestore:export . --project YOUR_PROJECT
   ```
3. Follow: `docs/SUPABASE_DATA_MIGRATION_GUIDE.md`
4. Validate migration
5. Test app with real data

---

## Common Issues & Fixes

### ❌ "Cannot connect to Supabase"
**Fix**: Check config values in `supabase_config.dart`
```dart
// Verify format:
// projectUrl: https://xxxxx.supabase.co (no trailing slash)
// publishableKey: eyJhbGc... (long string starting with eyJ)
```

### ❌ "RLS policy violation"
**Fix**: RLS not set up yet. Either:
1. Follow: `docs/SUPABASE_RLS_POLICIES.md`
2. Or temporarily disable RLS for testing:
   - Go to each table
   - Click "..."
   - Disable RLS
   - (Re-enable for production!)

### ❌ "No tables found"
**Fix**: Schema not created
- Run SQL from: `supabase/migrations/001_create_schema.sql`
- Verify in Supabase Dashboard → Tables

### ❌ "Auth not working"
**Fix**: Check these:
1. User exists in Supabase Auth dashboard
2. users table has matching email entry
3. Email matches exactly (case-sensitive)

### ❌ "Can't upload files"
**Fix**: Need storage buckets
1. Go to Storage in Supabase
2. Create buckets: avatars, administrasi_pembelajaran
3. Set RLS policies (from docs/SUPABASE_STORAGE_SETUP.md)

---

## What to Test First

### Login System (2 min)
- [ ] Sign up works
- [ ] Login works
- [ ] Logout works
- [ ] Password reset works (optional)

### Data Display (5 min)
- [ ] Can see list of schools (kelas)
- [ ] Can see schedules (jadwal)
- [ ] Can see student list (siswa)
- [ ] Can see grades (nilai)

### CRUD Operations (5 min)
- [ ] Can create new record
- [ ] Can edit existing record
- [ ] Can delete record
- [ ] Can see changes immediately

### Pagination (2 min)
- [ ] Can scroll through large lists
- [ ] "Load more" works
- [ ] No duplicate items

### File Upload (2 min)
- [ ] Can upload avatar
- [ ] Can upload document
- [ ] Files appear in Supabase Storage

---

## File Structure Reference

```
lib/
├── main.dart                          # Supabase init
├── core/
│   └── config/
│       └── supabase_config.dart       # ← UPDATE WITH REAL VALUES
├── services/
│   ├── base_firestore_service.dart    # Base CRUD
│   ├── paginated_firestore_service.dart # Pagination
│   ├── guru_firestore_service.dart    # All services use Supabase
│   └── ... (15 more services)
├── providers/
│   ├── auth_providers.dart            # Auth state
│   └── firestore_providers.dart       # Service providers
└── features/
    └── ... (UI screens)

supabase/
└── migrations/
    └── 001_create_schema.sql          # ← RUN THIS IN SUPABASE SQL EDITOR

docs/
├── SUPABASE_RLS_POLICIES.md           # Access control setup
├── SUPABASE_DATA_MIGRATION_GUIDE.md   # Data migration steps
├── SUPABASE_AUTH_SETUP.md             # Auth integration details
├── SUPABASE_STORAGE_SETUP.md          # File upload setup
└── SUPABASE_TESTING_CHECKLIST.md      # Complete test suite
```

---

## Next Steps After Initial Setup

1. **Set up RLS Policies** (20 min)
   - Read: `docs/SUPABASE_RLS_POLICIES.md`
   - Create policies in Supabase dashboard
   - Test access control

2. **Create Storage Buckets** (10 min)
   - Read: `docs/SUPABASE_STORAGE_SETUP.md`
   - Create buckets in Supabase Storage
   - Set upload policies

3. **Migrate Data** (1-2 hours)
   - Read: `docs/SUPABASE_DATA_MIGRATION_GUIDE.md`
   - Export from Firebase
   - Transform and load to Supabase
   - Validate data

4. **Run Full Test Suite** (1 hour)
   - Read: `docs/SUPABASE_TESTING_CHECKLIST.md`
   - Run all 100+ test cases
   - Fix any issues

5. **Deploy to Production** (1 hour)
   - Set production credentials
   - Final testing
   - Deploy app update

---

## Performance Baseline

These are the targets you should achieve:

| Operation | Target | How to Measure |
|-----------|--------|----------------|
| Login | < 2 seconds | Time from tap to home screen |
| Load list (50 items) | < 500ms | Time from page open to list visible |
| Pagination (next page) | < 300ms | Time to load next 50 items |
| Create record | < 1 second | Time from form submit to success |
| Upload file (5MB) | < 10 seconds | Time from pick to completion |

**If slower**: Check indexes in schema, optimize queries

---

## Security Checklist

Before going to production:

- [ ] RLS policies enabled on all tables
- [ ] Storage bucket policies configured
- [ ] Config values from environment variables (not hardcoded)
- [ ] Passwords minimum 8 characters
- [ ] Email verification enabled
- [ ] HTTPS enforced
- [ ] Regular backups enabled in Supabase
- [ ] Monitoring set up
- [ ] Error logging configured

---

## Getting Help

**For schema questions**:
- Check: `supabase/migrations/001_create_schema.sql`
- Run SQL queries in Supabase SQL Editor

**For auth issues**:
- Check: `docs/SUPABASE_AUTH_SETUP.md`
- Verify users exist in Supabase Auth dashboard

**For RLS access denied**:
- Check: `docs/SUPABASE_RLS_POLICIES.md`
- Test with: `SET auth.uid() to 'user-id'`

**For data migration**:
- Check: `docs/SUPABASE_DATA_MIGRATION_GUIDE.md`
- Run validation queries provided

**For file upload**:
- Check: `docs/SUPABASE_STORAGE_SETUP.md`
- Verify buckets exist and policies set

---

## Estimated Timeline

| Task | Time | Status |
|------|------|--------|
| Supabase setup | 30 min | Ready |
| Schema creation | 10 min | Ready |
| Flutter config | 5 min | Ready |
| Basic testing | 30 min | Ready |
| RLS setup | 20 min | Ready |
| Storage setup | 20 min | Ready |
| Data migration | 1-2 hours | Ready |
| Full testing | 1 hour | Ready |
| Production deploy | 1 hour | Ready |
| **TOTAL** | **5-6 hours** | - |

---

## Success Indicators ✅

When you see these, you're good to go:

✅ App compiles without Firebase errors  
✅ Sign up creates user in Supabase Auth  
✅ Login redirects to home screen  
✅ Can create/edit/delete records  
✅ Can upload files successfully  
✅ All test cases pass (from checklist)  
✅ No RLS policy errors  
✅ Performance meets targets  

---

**Ready to go!** 🚀

Start with Step 1️⃣ above and you'll have a working Supabase app in 2-3 hours.

For detailed guides, check the `docs/` folder.
