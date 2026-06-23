# 🚀 QUICK REFERENCE GUIDE - SISTEM PENGAWASAN KELAS

**Tanggal:** 28 April 2026 | **Version:** 1.0

---

## 📋 DAFTAR ISI CEPAT

| Section | Isi |
|---------|-----|
| **Tables** | 16 Supabase tables dengan 120+ atribut |
| **Services** | 17 Supabase-backed services + Authentication |
| **Providers** | 16+ Riverpod state management providers |
| **Features** | 7 Feature modules (Auth, Guru, Kepala Sekolah, Kemahasiswaan, Siswa, Profile, Shared) |
| **User Roles** | 4 roles: Guru, Kepala Sekolah, Kemahasiswaan, Siswa |
| **Key Processes** | 7 main business processes |

---

## 🎯 TABLES AT A GLANCE

### Tier 1: User & Authentication (4 Tables)

| Table | Purpose | Primary Use | Record Count Est. |
|------------|---------|-------------|------------------|
| **users** | User accounts | Login, profile mgmt | ~150-200 |
| **user_roles** | Role assignments | Multi-role support | ~150-200 |
| **guru** | Teacher profiles | Teacher data | ~50-80 |
| **siswa** | Student profiles | Student data | ~500-1000 |

### Tier 2: Academic Setup (4 Tables)

| Table | Purpose | Primary Use | Record Count Est. |
|------------|---------|-------------|------------------|
| **tahun_ajaran** | Academic years | 1-2 per year | ~10-20 |
| **kelas** | Classes | Class grouping | ~30-50 |
| **mapel** | Subjects | Subject definition | ~15-20 |
| **kelas_siswa** | Student enrollment | Class assignment | ~1500-3000 |

### Tier 3: Teaching & Learning (4 Tables)

| Table | Purpose | Primary Use | Record Count Est. |
|------------|---------|-------------|------------------|
| **jadwal** | Schedules | Weekly schedule | ~200-400 |
| **jurnal** | Daily journals | Teaching record | ~2000-5000/year |
| **absensi_jurnal** | Student attendance | Attendance tracking | ~20000-50000/year |
| **tugas** | Assignments | Task assignment | ~500-1000/year |

### Tier 4: Assessment & Admin (2 Tables)

| Table | Purpose | Primary Use | Record Count Est. |
|------------|---------|-------------|------------------|
| **nilai** | Grades | Grade recording | ~5000-10000/year |
| **administrasi_pembelajaran** | Admin docs | Doc upload/approval | ~200-500/year |

### Tier 5: History & Tracking (2 Tables)

| Table | Purpose | Primary Use | Record Count Est. |
|------------|---------|-------------|------------------|
| **histori_kelas_siswa** | Student history | Class promotion | ~500-1000/year |
| **histori_wali_kelas** | Teacher history | Wali kelas tracking | ~50-100/year |

---

## 🔍 QUICK LOOKUP - WHICH TABLE?

**Saya ingin...** | **Gunakan Table** | **Table / PK**
---|---|---
Lihat data guru | guru | guru.id |
Lihat data siswa | siswa | siswa.id |
Lihat jadwal pelajaran | jadwal | jadwal.id |
Catat pembelajaran harian | jurnal + absensi_jurnal | jurnal.id + absensi_jurnal.id |
Input nilai siswa | nilai | nilai.id |
Upload dokumen admin | administrasi_pembelajaran | administrasi_pembelajaran.id |
Lihat kehadiran siswa | absensi_jurnal | absensi_jurnal.id |
Promosi kelas siswa | histori_kelas_siswa | histori_kelas_siswa.id |
List semua kelas | kelas | kelas.id |
List siswa per kelas | kelas_siswa | kelas_siswa.id |
Ubah wali kelas | histori_wali_kelas | histori_wali_kelas.id |
List mata pelajaran | mapel | mapel.id |
Lihat tahun ajaran aktif | tahun_ajaran | tahun_ajaran.id |
User role management | user_roles | user_roles.id |

---

## 👥 ROLE-BASED ACCESS MATRIX

| Action | Guru | Kepala Sekolah | Staff | Siswa | Notes |
|--------|------|-----------------|-------|-------|-------|
| **Login** | ✅ | ✅ | ✅ | ✅ | Supabase Auth |
| **View Own Schedule** | ✅ | ✅ | ❌ | ✅ | jadwal table |
| **Create/Edit Schedule** | ❌ | ✅ | ❌ | ❌ | Admin only |
| **Record Daily Journal** | ✅ | ❌ | ❌ | ❌ | Guru only |
| **Record Attendance** | ✅ | ❌ | ❌ | ❌ | Guru only |
| **Input Grades** | ✅ | ❌ | ❌ | ❌ | Guru only |
| **View All Grades** | ✅ | ✅ | ❌ | 🔒 | Filtered by siswa_id for student |
| **Create Assignment** | ✅ | ❌ | ❌ | ❌ | Guru only |
| **Upload Admin Docs** | ✅ | ❌ | ❌ | ❌ | Guru only |
| **Verify Admin Docs** | ❌ | ✅ | ❌ | ❌ | Kepsek only |
| **Create Academic Year** | ❌ | ✅ | ❌ | ❌ | Admin only |
| **Manage Classes** | ❌ | ✅ | ✅ | ❌ | Create/Edit/Assign |
| **Manage Students** | ❌ | ✅ | ✅ | ❌ | CRUD students |
| **Promote Students** | ❌ | ✅ | ✅ | ❌ | End of year |
| **Generate Reports** | ❌ | ✅ | ❌ | ❌ | Admin only |
| **Monitor Learning** | ❌ | ✅ | ❌ | ❌ | View journalss |
| **View Own Grades** | ✅ | ✅ | ❌ | ✅ | Filtered by user |
| **Delete Records** | ❌ | ❌ | ❌ | ❌ | Soft delete only |

**Legend:** ✅ = Allowed | ❌ = Not Allowed | 🔒 = Filtered by user context

---

## 🔗 KEY RELATIONSHIPS QUICK LOOKUP

**Jika ingin tahu...** | **Query Pattern** |
---|---|
Guru mana saja yang mengajar? | Query `guru` → filter by `uid` di `jadwal` |
Siswa di kelas mana? | Query `kelas_siswa` → filter by `siswa_id` |
Nilai siswa untuk mata pelajaran? | Query `nilai` → filter by `siswa_id` + `mapel_id` |
Jadwal kelas apa saja? | Query `jadwal` → filter by `kelas_id` |
Pembelajaran harian kelas? | Query `jurnal` → filter by `kelas_id` + `tanggal` |
Kehadiran siswa di pembelajaran? | Query `absensi_jurnal` → filter by `siswa_id` + `jurnal_id` |
Dokumen admin guru mana? | Query `administrasi_pembelajaran` → filter by `guru_uid` |
Promosi siswa apa saja? | Query `histori_kelas_siswa` → filter by `siswa_id` |
Wali kelas tahun ini? | Query `histori_wali_kelas` → filter by `tahun_ajaran_id` + `is_aktif=true` |

---

## 📊 POSTGRES INDEXES RECOMMENDATION

**Untuk optimal query performance, buat index di PostgreSQL:**

```
1. Table: kelas_siswa
   Fields: (tahun_ajaran_id, kelas_id, siswa_id, isDeleted)
   Use: List siswa per kelas per tahun

2. Table: jadwal
   Fields: (guru_uid, tahun_ajaran_id, semester, isDeleted)
   Use: List jadwal guru per tahun/semester

3. Table: nilai
   Fields: (siswa_id, tahun_ajaran_id, semester, isDeleted)
   Use: List nilai siswa per tahun/semester

4. Table: jurnal
   Fields: (kelas_id, tanggal, tahun_ajaran_id, isDeleted)
   Use: List jurnal kelas per tanggal

5. Table: absensi_jurnal
   Fields: (siswa_id, tanggal, tahun_ajaran_id, isDeleted)
   Use: List kehadiran siswa per periode

6. Table: administrasi_pembelajaran
   Fields: (guru_uid, status_verifikasi, tahun_ajaran_id, isDeleted)
   Use: List dokumen pending approval

7. Table: user_roles
   Fields: (uid, role, isDeleted)
   Use: Check user roles fast
```

---

## 🛠️ SERVICE LAYER - QUICK REFERENCE

Catatan: nama file masih memakai suffix _firestore_service.dart, tapi implementasinya sudah memakai Supabase.

| Service | File | Method | Purpose |
|---------|------|--------|---------|
| **Auth** | login_firestore_service.dart | `login()` | User authentication |
| | | `logout()` | User logout |
| | | `signup()` | Create new user |
| **User** | user_firestore_service.dart | `getAllUsers()` | Get all users |
| | | `createUser()` | Create user |
| | | `updateUser()` | Update user |
| **Guru** | guru_firestore_service.dart | `getGuruById()` | Get guru profile |
| | | `getAllGuru()` | Get all guru |
| | | `createGuru()` | Create guru record |
| **Siswa** | siswa_firestore_service.dart | `getSiswaById()` | Get siswa profile |
| | | `getAllSiswa()` | Get all siswa |
| | | `createSiswa()` | Create siswa record |
| **Jadwal** | jadwal_firestore_service.dart | `getJadwalByGuru()` | Get guru schedule |
| | | `getJadwalByKelas()` | Get class schedule |
| **Jurnal** | jurnal_firestore_service.dart | `createJurnal()` | Create daily journal |
| | | `getJurnalByKelas()` | Get class journals |
| **Nilai** | nilai_firestore_service.dart | `createNilai()` | Create grade |
| | | `getNilaiByStudent()` | Get student grades |
| | | `updateNilai()` | Update grade |
| **Absensi** | absensi_jurnal_firestore_service.dart | `createAbsensi()` | Record attendance |
| | | `getAbsensiByJurnal()` | Get attendance per lesson |
| **Kelas** | kelas_firestore_service.dart | `getKelasById()` | Get class |
| | | `getAllKelas()` | Get all classes |
| **KelasSiswa** | kelas_siswa_firestore_service.dart | `enrollStudent()` | Add student to class |
| | | `getSiswaByKelas()` | Get students in class |

---

## 📡 PROVIDER SETUP - RIVERPOD QUICK REFERENCE

```dart
// Authentication
final loginFirestoreServiceProvider → LoginFirestoreService

// User Management  
final userServiceProvider → UserFirestoreService
final userRoleServiceProvider → UserRoleFirestoreService

// Academic Setup
final tahunAjaranServiceProvider → TahunAjaranFirestoreService
final kelasServiceProvider → KelasFirestoreService
final mapelServiceProvider → MapelFirestoreService
final kelasSiswaServiceProvider → KelasSiswaFirestoreService

// Teacher Management
final guruServiceProvider → GuruFirestoreService

// Student Management
final siswaServiceProvider → SiswaFirestoreService

// Teaching & Learning
final jadwalServiceProvider → JadwalFirestoreService
final jurnalServiceProvider → JurnalFirestoreService
final absensiJurnalServiceProvider → AbsensiJurnalFirestoreService

// Assessment
final nilaiServiceProvider → NilaiFirestoreService

// Admin & Docs
final administrasiPembelajaranServiceProvider → AdministrasiPembelajaranFirestoreService
final administrasiStorageServiceProvider → AdministrasiStorageService

// Assignments
final tugasServiceProvider → TugasFirestoreService

// History & Tracking
final historiKelasSiswaServiceProvider → HistoriKelasSiswaFirestoreService
final historiWaliKelasServiceProvider → HistoriWaliKelasFirestoreService
```

---

## 🎯 MAIN FEATURES OVERVIEW

### 1. 👨‍🏫 GURU (Teacher) Module
```
lib/features/guru/
├── schedule/         ← View & manage teaching schedule
├── journal/          ← Record daily journal + attendance
├── grades/           ← Input & manage grades
├── assignments/      ← Create & manage assignments
├── admin_docs/       ← Upload admin documents
└── reports/          ← View grade reports
```

### 2. 👔 KEPALA SEKOLAH (Principal) Module
```
lib/features/kepala_sekolah/
├── monitoring/              ← Monitor student learning
├── academic_setup/          ← Setup years/classes/subjects
├── account_management/      ← User & account management
└── reports/                 ← Generate reports
```

### 3. 📋 KEMAHASISWAAN (Student Affairs) Module
```
lib/features/kemahasiswaan/
├── student_management/      ← Create & manage students
├── class_promotion/         ← Handle class promotion
└── reports/                 ← Student reports
```

### 4. 👶 SISWA (Student) Module
```
lib/features/siswa/
├── schedule/                ← View my schedule
├── grades/                  ← View my grades
├── assignments/             ← View assignments
└── attendance/              ← View attendance
```

### 5. 🔐 AUTH Module
```
lib/features/auth/
├── login/                   ← Login screen
├── signup/                  ← User registration
└── session_management/      ← Token & session handling
```

---

## ⚡ PERFORMANCE TIPS

### 1. **Caching Strategy**
```
- Use cache_first_repository for frequently accessed data
- Cache jadwal per guru (static weekly)
- Cache nilai per siswa per semester (static after input)
- Clear cache saat data updated
```

### 2. **Query Optimization**
```
- Always filter by tahun_ajaran_id + semester
- Always filter by isDeleted = false
- Use composite indexes (see Postgres Indexes section)
- Limit query results dengan pagination
```

### 3. **Batch Operations**
```
- Use batch write untuk multiple records
- Example: Create 50 absensi_jurnal in 1 batch
- Reduce write operations = save quota
```

### 4. **Offline Support**
```
- Local cache di Hive/Sqflite
- Sync when online
- Show cached data while loading
```

---

## 🚨 COMMON ISSUES & SOLUTIONS

| Issue | Cause | Solution |
|-------|-------|----------|
| Query slow | Missing index | Create composite index (see list above) |
| Data not updated | Cache stale | Call ref.refresh() to invalidate |
| Null pointer | Row not exist | Check isDeleted == false |
| Upload failed | File too large | Check file size < 10MB |
| Login failed | Wrong UID | Verify user_roles record exists |
| Permission denied | Role mismatch | Check user role in user_roles table |
| Quota exceeded | Too many writes | Use batch operations, optimize queries |

---

## 📈 DATABASE SIZE ESTIMATION

**Yearly Data Volume:**

| Table | Records/Year | Avg Size | Total |
|------------|-------------|----------|-------|
| jurnal | 2,000-5,000 | 500 B | 2.5 MB |
| absensi_jurnal | 20,000-50,000 | 200 B | 10 MB |
| nilai | 5,000-10,000 | 300 B | 3 MB |
| histori_kelas_siswa | 500-1,000 | 300 B | 0.3 MB |
| tugas | 500-1,000 | 400 B | 0.4 MB |
| administrasi_pembelajaran | 200-500 | 600 B | 0.3 MB |
| Other static data | - | - | 1 MB |
| **TOTAL/YEAR** | - | - | **~17 MB** |

**Storage Estimate for 3 Years:** ~50 MB (very manageable for Postgres)

---

## 🔄 DATA MIGRATION CHECKLIST

Jika perlu migrate data:

- [ ] Export all users dengan role mapping
- [ ] Export semua guru + siswa profiles
- [ ] Export tahun_ajaran & kelas
- [ ] Export jadwal & materi pelajaran
- [ ] Migrate jurnal & absensi (year by year)
- [ ] Migrate nilai per tahun
- [ ] Verify foreign key relationships
- [ ] Update soft delete flags
- [ ] Test queries setelah migration
- [ ] Backup original data

---

## 📞 SUPPORT & DOCUMENTATION

| Resource | Location |
|----------|----------|
| **Full Analysis** | DATABASE_AND_SYSTEM_ANALYSIS.md |
| **Visual Diagrams** | VISUAL_DIAGRAMS.md |
| **Quick Reference** | This file (QUICK_REFERENCE.md) |
| **Project Architecture** | PROJECT_ARCHITECTURE_ANALYSIS.md |
| **Source Code** | lib/models/firestore/ |
| **Service Code** | lib/services/ |
| **Provider Setup** | lib/providers/firestore_providers.dart |

---

## ✅ CHECKLIST - BEFORE DEPLOYMENT

- [ ] All tables created in Supabase
- [ ] All indexes configured
- [ ] RLS policies configured
- [ ] CORS policy set for Supabase
- [ ] All services tested
- [ ] Cache strategy implemented
- [ ] Error handling complete
- [ ] Logging configured
- [ ] Monitoring setup (Crashlytics, Analytics)
- [ ] Backup strategy in place

---

**Created:** 28 April 2026  
**Last Updated:** 28 April 2026  
**Version:** 1.0  
**Status:** ✅ Production Ready

