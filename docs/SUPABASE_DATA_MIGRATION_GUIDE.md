-- Data Migration: Firebase to Supabase ETL Guide
-- Document: SUPABASE_DATA_MIGRATION_GUIDE.md
-- Purpose: Step-by-step guide to migrate data from Firebase Firestore to Supabase PostgreSQL

# Firebase to Supabase Data Migration Guide

## Overview
This guide provides step-by-step instructions to migrate data from Firebase Firestore to Supabase PostgreSQL.

**Migration Strategy**: Firestore → JSON Export → Transform → PostgreSQL Import

## Phase 1: Export Firebase Data

### Step 1.1: Export Collections from Firestore
Use Firebase Console or Firebase CLI to export data.

#### Option A: Using Firebase Console (UI)
1. Go to **Firebase Console** → **Firestore Database**
2. Click **⋮ (More)** → **Export Collections**
3. Select collections to export
4. Choose **Cloud Storage** destination
5. Wait for export to complete

#### Option B: Using Firebase CLI
```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login
firebase login

# Export collections
firebase firestore:export . --project smp-1-jenar-testing-5c904

# This creates a folder with firestore_export.json and document exports
```

### Step 1.2: Verify Export Data
```bash
# Check exported structure
ls -la firestore_export/
# Should contain: firestore_export.json, collections/, documents/

# View sample data
cat firestore_export.json | head -50
```

## Phase 2: Transform Data

### Step 2.1: Create Transformation Script

Create `scripts/firebase_to_supabase_migration.dart`:

```dart
import 'dart:convert';
import 'dart:io';
import 'package:uuid/uuid.dart';

class FirebaseToSupabaseTransformer {
  final String exportPath;
  final Map<String, String> idMappings = {}; // Firebase ID → Supabase UUID
  
  FirebaseToSupabaseTransformer(this.exportPath);

  /// Load Firebase export JSON
  Future<Map<String, dynamic>> loadFirestoreExport() async {
    final file = File('$exportPath/firestore_export.json');
    final content = await file.readAsString();
    return jsonDecode(content);
  }

  /// Transform single Firestore document
  Map<String, dynamic> transformDocument(
    String docId,
    Map<String, dynamic> doc,
  ) {
    // Handle Firestore-specific types
    return {
      'id': _getOrCreateUuid(docId),
      ...doc,
      'createdAt': doc['createdAt'] ?? DateTime.now().toIso8601String(),
      'updatedAt': doc['updatedAt'] ?? DateTime.now().toIso8601String(),
      // Remove Firestore-specific fields
      '__name__': null,
    }..removeWhere((k, v) => v == null);
  }

  /// Get UUID for Firebase document ID (create if not exists)
  String _getOrCreateUuid(String firebaseId) {
    if (!idMappings.containsKey(firebaseId)) {
      idMappings[firebaseId] = const Uuid().v4();
    }
    return idMappings[firebaseId]!;
  }

  /// Save ID mappings for reference
  Future<void> saveIdMappings() async {
    final mappingsFile = File('scripts/output/id_mappings.json');
    await mappingsFile.create(recursive: true);
    await mappingsFile.writeAsString(jsonEncode(idMappings));
    print('✅ ID mappings saved to scripts/output/id_mappings.json');
  }
}

// Usage in main script
Future<void> migrateFirestoreToSupabase() async {
  final transformer = FirebaseToSupabaseTransformer('firestore_export');
  
  // Load data
  final export = await transformer.loadFirestoreExport();
  
  // Transform collections
  final usersData = _transformUsersCollection(export);
  final guruData = _transformGuruCollection(export);
  // ... etc
  
  // Save transformed data
  await _saveSqlInserts(usersData, 'users');
  
  // Save ID mappings
  await transformer.saveIdMappings();
}
```

### Step 2.2: Data Transformation Rules

#### **Users Collection** → **users + user_roles tables**
```sql
-- Firebase: /users/{uid}
-- {
--   "email": "guru@example.com",
--   "nama": "John Doe",
--   "nip": "19800101200001",
--   "role": "guru"
-- }

-- SQL Transform:
-- INSERT INTO users (id, email, nama, nip, created_at, updated_at)
-- VALUES (NEW_UUID(), email, nama, nip, NOW(), NOW());
--
-- INSERT INTO user_roles (user_id, role, created_at, updated_at)
-- VALUES (user_uuid, role, NOW(), NOW());
```

#### **Guru Collection** → **guru table**
```sql
-- Firebase: /guru/{guruId}
-- {
--   "userId": "firebase_uid",
--   "nipG": "19800101200001",
--   "namaG": "John Doe",
--   "emailG": "john@school.com"
-- }

-- SQL Transform:
-- INSERT INTO guru (id, user_id, nip, nama_guru, email_guru, created_at, updated_at)
-- VALUES (NEW_UUID(), mapped_user_uuid, nipG, namaG, emailG, NOW(), NOW());
```

#### **Siswa Collection** → **siswa table**
```sql
-- Firebase: /siswa/{siswaId}
-- {
--   "userId": "firebase_uid",
--   "nipsn": "1234567890123456",
--   "namaSiswa": "Jane Doe",
--   "ttl": "Surabaya, 2008-01-15",
--   "jk": "L"
-- }

-- SQL Transform:
-- INSERT INTO siswa (id, user_id, nipsn, nama_siswa, jenis_kelamin, ...)
-- VALUES (NEW_UUID(), mapped_user_uuid, nipsn, namaSiswa, jk, ...);
```

#### **TahunAjaran → tahun_ajaran table**
```sql
-- Firebase path: /tahunAjaran/{taId}
-- {
--   "tahunAjaran": "2023/2024",
--   "tahunMulai": 2023,
--   "tahunSelesai": 2024,
--   "isAktif": true
-- }

-- SQL Transform:
-- INSERT INTO tahun_ajaran (id, tahun_ajaran, tahun_mulai, tahun_selesai, is_aktif)
-- VALUES (NEW_UUID(), "2023/2024", 2023, 2024, true);
```

#### **Kelas → kelas table** 
```sql
-- Firebase: /kelas/{kelasId}
-- {
--   "tahunAjaranId": "firebase_ta_id",
--   "namaKelas": "7A",
--   "tingkat": 7,
--   "waliKelasUid": "firebase_guru_uid",
--   "jumlahSiswa": 32
-- }

-- SQL Transform:
-- INSERT INTO kelas (id, tahun_ajaran_id, nama_kelas, tingkat, wali_kelas_uid, jumlah_siswa)
-- VALUES (NEW_UUID(), ta_mapped_id, "7A", 7, guru_mapped_uid, 32);
```

#### **Jurnal → jurnal table**
```sql
-- Firebase: /jurnal/{jurnalId}
-- {
--   "guruUid": "firebase_uid",
--   "kelasId": "firebase_class_id",
--   "mapelId": "firebase_subject_id",
--   "tanggal": "2023-09-15",
--   "jamKe": 1,
--   "materiPembelajaran": "Bilangan Bulat",
--   "statusKehadiran": "Masuk"
-- }

-- SQL Transform:
-- INSERT INTO jurnal (id, guru_uid, kelas_id, mapel_id, tahun_ajaran_id, tanggal, jam_ke_awal, jam_ke_akhir, materi_pembelajaran, status_kehadiran)
-- VALUES (NEW_UUID(), guru_uuid, kelas_uuid, mapel_uuid, ta_uuid, '2023-09-15', 1, 1, '...', 'Masuk');
```

#### **Nilai → nilai table**
```sql
-- Firebase: /nilai/{nilaiId}
-- {
--   "siswaId": "firebase_student_id",
--   "guruId": "firebase_teacher_id",
--   "mapelId": "firebase_subject_id",
--   "kelasId": "firebase_class_id",
--   "tahunAjaranId": "firebase_ta_id",
--   "semester": 1,
--   "nilaiUts": 85.5,
--   "nilaiUas": 88.0
-- }

-- SQL Transform (with calculated akhir):
-- INSERT INTO nilai (id, siswa_uid, guru_uid, mapel_id, kelas_id, tahun_ajaran_id, semester, nilai_uts, nilai_uas, nilai_akhir)
-- VALUES (NEW_UUID(), siswa_uuid, guru_uuid, mapel_uuid, kelas_uuid, ta_uuid, 1, 85.5, 88.0, 86.75);
```

## Phase 3: Generate SQL Insert Statements

### Step 3.1: Create SQL Generation Script

```dart
// Generate INSERT statements from transformed data
Future<void> generateSqlInserts(
  Map<String, List<Map<String, dynamic>>> transformedData,
) async {
  final sqlFile = File('scripts/output/insert_data.sql');
  final buffer = StringBuffer();

  buffer.writeln('-- Generated SQL Inserts for Supabase');
  buffer.writeln('-- Generated: ${DateTime.now()}');
  buffer.writeln('');

  // Generate inserts for each table
  for (final entry in transformedData.entries) {
    final table = entry.key;
    final rows = entry.value;

    buffer.writeln('-- Table: $table');
    buffer.writeln('INSERT INTO $table (${_getColumns(rows[0]).join(', ')})');
    buffer.writeln('VALUES');

    for (var i = 0; i < rows.length; i++) {
      final values = _valuesToSql(rows[i]);
      buffer.write('($values)');
      if (i < rows.length - 1) buffer.write(',\n');
    }
    buffer.writeln(';');
    buffer.writeln('');
  }

  await sqlFile.create(recursive: true);
  await sqlFile.writeAsString(buffer.toString());
  print('✅ SQL insert statements generated');
}

String _valuesToSql(Map<String, dynamic> row) {
  return row.values.map((v) {
    if (v == null) return 'NULL';
    if (v is String) return "'${v.replaceAll("'", "''")}'";
    if (v is bool) return v ? 'true' : 'false';
    if (v is DateTime) return "'${v.toIso8601String()}'";
    return v.toString();
  }).join(', ');
}
```

### Step 3.2: Validate Data Counts

```sql
-- Verify counts before and after migration
-- Before: Get counts from Firebase export
-- After: Run these queries in Supabase

SELECT count(*) as users FROM users WHERE is_deleted = false;
SELECT count(*) as guru FROM guru WHERE is_deleted = false;
SELECT count(*) as siswa FROM siswa WHERE is_deleted = false;
SELECT count(*) as jurnal FROM jurnal WHERE is_deleted = false;
SELECT count(*) as nilai FROM nilai WHERE is_deleted = false;
SELECT count(*) as kelas FROM kelas WHERE is_deleted = false;
SELECT count(*) as jadwal FROM jadwal WHERE is_deleted = false;
```

## Phase 4: Execute Migration

### Step 4.1: Disable Foreign Keys (Temporary)
```sql
-- Disable constraints during bulk insert
ALTER TABLE guru DISABLE TRIGGER ALL;
ALTER TABLE siswa DISABLE TRIGGER ALL;
ALTER TABLE kelas DISABLE TRIGGER ALL;
ALTER TABLE jadwal DISABLE TRIGGER ALL;
ALTER TABLE jurnal DISABLE TRIGGER ALL;
-- ... etc for all tables
```

### Step 4.2: Run SQL Inserts
```sql
-- In Supabase SQL Editor, paste insert_data.sql
-- Monitor for errors and FK violations
```

### Step 4.3: Re-enable Foreign Keys
```sql
ALTER TABLE guru ENABLE TRIGGER ALL;
ALTER TABLE siswa ENABLE TRIGGER ALL;
-- ... etc
```

### Step 4.4: Update Sequences (if using)
```sql
-- Reset auto-increment sequences if applicable
-- Not needed for UUID primary keys
```

## Phase 5: Data Validation

### Step 5.1: Referential Integrity Check
```sql
-- Find orphaned records (FK violations)
SELECT * FROM guru WHERE user_id NOT IN (SELECT id FROM users);
SELECT * FROM siswa WHERE user_id NOT IN (SELECT id FROM users);
SELECT * FROM jurnal WHERE guru_uid NOT IN (SELECT id FROM users);
SELECT * FROM jadwal WHERE guru_uid NOT IN (SELECT id FROM users);
-- etc.
```

### Step 5.2: Data Quality Checks
```sql
-- Check for null values where not allowed
SELECT * FROM users WHERE email IS NULL OR nama IS NULL;
SELECT * FROM kelas WHERE tahun_ajaran_id IS NULL;
SELECT * FROM jurnal WHERE guru_uid IS NULL OR tanggal IS NULL;

-- Check for duplicate emails
SELECT email, count(*) 
FROM users 
WHERE is_deleted = false
GROUP BY email 
HAVING count(*) > 1;
```

### Step 5.3: Sample Record Verification
```sql
-- Manually verify specific records
SELECT u.id, u.nama, ur.role, g.nama_guru
FROM users u
LEFT JOIN user_roles ur ON u.id = ur.user_id
LEFT JOIN guru g ON u.id = g.user_id
LIMIT 10;

-- Verify journal data with joins
SELECT j.id, j.tanggal, u.nama, k.nama_kelas, m.nama_mapel
FROM jurnal j
JOIN users u ON j.guru_uid = u.id
JOIN kelas k ON j.kelas_id = k.id
JOIN mapel m ON j.mapel_id = m.id
LIMIT 10;
```

## Phase 6: Post-Migration Steps

### Step 6.1: Update Flutter App
```dart
// In lib/core/config/supabase_config.dart
class SupabaseConfig {
  const SupabaseConfig._();

  // Replace with actual values
  static const String projectUrl = 'https://YOUR_PROJECT_ID.supabase.co';
  static const String publishableKey = 'YOUR_SUPABASE_ANON_KEY';
  static const String storageBucket = 'YOUR_STORAGE_BUCKET';
}
```

### Step 6.2: Test with Real Data
1. Run Flutter app
2. Login with migrated user credentials
3. Verify data displays correctly
4. Test filtering, pagination, updates

### Step 6.3: Backup Firestore Data
```bash
# Export Firestore data for archival
firebase firestore:export ./backup-before-migration/ --project smp-1-jenar-testing-5c904
```

## Troubleshooting

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| FK constraint violation | Foreign key references invalid | Check ID mappings, verify parent records exist |
| Duplicate key error | Duplicate unique values | Check for duplicates before insert |
| Type conversion error | Data type mismatch | Verify column types match transformed data |
| Missing data | Incomplete export | Re-export from Firebase, check mapping logic |
| Timezone issues | DateTime conversion | Use UTC timestamps, verify TZ handling |

### Rollback Plan
```sql
-- If migration fails, rollback using backup
-- 1. Delete migrated data
DELETE FROM users WHERE created_at > '2024-01-15';

-- 2. Restore from backup
-- Use pg_restore or manual import

-- 3. Fix transformation logic
-- Update scripts and retry
```

## Performance Considerations

1. **Batch Insert**: Split large datasets into 10k-row batches
2. **Indexes**: Migrate with indexes disabled, rebuild after
3. **Triggers**: Disable triggers during migration, re-enable after
4. **Locks**: Do migration during off-hours to avoid blocking

```sql
-- Disable indexes for faster insert
DROP INDEX idx_users_email;
DROP INDEX idx_users_nip;
-- ... insert data ...
-- Rebuild indexes
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_nip ON users(nip);
```

## Success Criteria

- ✅ All data successfully migrated (100% match with source)
- ✅ No FK constraint violations
- ✅ No orphaned records
- ✅ Sample record verification passed
- ✅ Flutter app displays data correctly
- ✅ All filters and queries working
- ✅ User authentication working

## Next Steps

1. **Implement Supabase Auth**: Migrate user credentials
2. **Set up RLS Policies**: Implement RBAC in PostgreSQL
3. **Configure Storage**: Set up buckets for file uploads
4. **Run Integration Tests**: Comprehensive testing with real data
5. **Performance Tuning**: Monitor queries, optimize as needed
