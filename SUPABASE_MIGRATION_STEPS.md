# Supabase Migration Steps (Firebase -> Supabase)

Tujuan dokumen ini adalah menjadi rencana kerja langkah demi langkah untuk migrasi penuh dari Firebase ke Supabase, termasuk redesain database dari NoSQL (Firestore) ke PostgreSQL.

## A. Apa yang akan diganti (full Supabase)

1) Database
- Firestore -> PostgreSQL (Supabase Database)
- Firestore indexes -> SQL indexes
- Firestore security rules -> PostgreSQL Row Level Security (RLS)

2) Auth
- Firebase Auth -> Supabase Auth
- Custom claims/roles -> tabel roles + RLS policy

3) Storage
- Firebase Storage -> Supabase Storage buckets
- Storage rules -> Storage policies (RLS)

4) Cloud Functions
- Firebase Functions -> Supabase Edge Functions (jika dibutuhkan)

5) Hosting (opsional)
- Firebase Hosting -> Supabase Hosting / Vercel / Netlify (pilih salah satu)

6) SDK dan konfigurasi aplikasi
- Hapus dependency Firebase (firebase_core, cloud_firestore, firebase_auth, firebase_storage, dll)
- Tambahkan dependency supabase_flutter dan config env
- Update service layer (repository, data source, auth flow, upload file)

## B. Cara mengganti desain database NoSQL ke PostgreSQL

1) Inventarisasi data dan use case
- Daftar semua koleksi, subkoleksi, field, dan aturan akses
- Petakan query yang dipakai aplikasi (filter, sorting, pagination)

2) Identifikasi entitas dan relasi
- Tentukan entitas inti (mis. siswa, guru, kelas, mapel, jadwal, absensi, jurnal, tahun_ajaran, pengguna)
- Tentukan relasi: one-to-many, many-to-many

3) Normalisasi data
- Simpan atribut berulang sebagai tabel terpisah
- Ubah array of objects menjadi tabel relasi
- Simpan referensi sebagai foreign key (FK)

4) Pilih tipe data yang tepat
- Gunakan UUID untuk primary key (PK)
- Gunakan timestamptz untuk waktu
- Gunakan enum untuk nilai terbatas (mis. status, role)

5) Terapkan constraint dan index
- NOT NULL, UNIQUE, CHECK untuk validasi data
- Index pada kolom yang sering dipakai filter/sort
- FK dengan ON DELETE/UPDATE sesuai kebutuhan

6) Rancang keamanan berbasis RLS
- Buat kebijakan per tabel, berbasis user_id atau role
- Jangan andalkan filter di client

7) Buat migrasi SQL terstruktur
- Gunakan file migration SQL dan jalankan berurutan
- Pisahkan schema, data seed, dan policies

## C. Step-by-step migrasi dari Firebase ke Supabase

### Fase 1: Persiapan
1) Audit fitur Firebase yang dipakai
- Firestore (koleksi, rules, indexes)
- Auth (provider, claims, email/password)
- Storage (bucket, rules)
- Cloud Functions, FCM, Hosting

2) Siapkan Supabase project
- Buat project baru
- Tentukan region dan database password
- Setup env vars dan CI secret

3) Buat arsitektur target
- Diagram entity-relationship (ERD)
- Rancangan RLS per role
- Rencana bucket storage

### Fase 2: Desain database PostgreSQL
1) Konversi model data
- Buat tabel per entitas
- Definisikan PK, FK, dan constraint

2) Tulis migration SQL
- schema.sql: create table, enum, index
- policies.sql: RLS policies
- seed.sql (opsional)

3) Review performa query
- Pastikan index mendukung query utama

### Fase 3: Migrasi data
1) Export data Firestore
- Gunakan script export (JSON/CSV)

2) Transform data (ETL)
- Ubah struktur dokumen ke tabel relasional
- Buat mapping ID -> UUID
- Bersihkan data invalid

3) Import ke PostgreSQL
- Gunakan COPY atau insert batch
- Validasi row count dan FK

### Fase 4: Migrasi Auth
1) Tentukan strategi migrasi akun
- Import user dari Firebase (CSV) atau minta reset password

2) Setup provider di Supabase Auth
- Email/password, OAuth, magic link (sesuai kebutuhan)

3) Mapping role
- Buat tabel user_roles
- Terapkan RLS berbasis role

### Fase 5: Migrasi Storage
1) Buat bucket di Supabase Storage
- Mapping nama bucket dari Firebase

2) Tulis policy akses file
- Akses berdasarkan user_id/role

3) Migrasikan file
- Download dari Firebase Storage
- Upload ke Supabase Storage

### Fase 6: Update aplikasi (Flutter)
1) Ganti dependency
- Hapus Firebase SDK
- Tambah supabase_flutter

2) Update layer service/repository
- Ganti query Firestore -> SQL (RPC atau view)
- Gunakan Supabase Auth untuk login
- Update upload/download file

3) Update config dan env
- Simpan url dan anon key

### Fase 7: Testing dan validasi
1) Verifikasi data
- Bandingkan row count dan sampel data
- Cek integritas FK

2) Verifikasi akses
- Uji RLS untuk tiap role
- Pastikan tidak ada data bocor

3) Uji performa
- Latency query dan load time

### Fase 8: Cutover
1) Freeze write di Firebase
2) Jalankan migrasi final
3) Switch env ke Supabase
4) Monitor error dan performa

### Fase 9: Post-migration
1) Backup dan monitoring
- Aktifkan backup otomatis
- Tambahkan log dan alert

2) Dokumentasi dan SOP
- Cara membuat migration baru
- Panduan RLS dan role

## D. Checklist ringkas

- [ ] Audit semua fitur Firebase
- [ ] ERD disetujui
- [ ] Migration SQL siap
- [ ] RLS policy diuji
- [ ] ETL berhasil dan tervalidasi
- [ ] App Flutter sudah pakai supabase_flutter
- [ ] Cutover sukses dan monitor aktif

## E. Perubahan yang sudah diterapkan di repo

- Hapus Firebase SDK (firebase_core, cloud_firestore, firebase_auth) dari pubspec.yaml dan tambah supabase_flutter
- Tambah dependency uuid untuk pembuatan ID user sementara
- Inisialisasi Supabase di lib/main.dart dan hapus firebase_options.dart
- Supabase config placeholder di lib/core/config/supabase_config.dart
- Service layer direfaktor ke Supabase (base_firestore_service.dart, base_incremental_service.dart, paginated_firestore_service.dart, dan turunan service)
- Tambah contoh optimisasi Supabase di lib/optimization/n1_query_fix_examples.dart
- Pagination diganti ke offset-based (range)
- Hapus konfigurasi Firebase (firebase.json, .firebaserc, firestore.indexes.json, storage.rules, android/app/google-services.json)
- Hapus Google Services Gradle plugin di Android

## F. Catatan dan pekerjaan lanjutan

- Auth masih memakai tabel users dan login custom, belum memakai Supabase Auth
- Script di scripts/*_to_firestore.js dan grant_all_roles_to_user.js masih memakai Firebase Admin; perlu rewrite ke Supabase ETL atau dinonaktifkan
- Regenerasi plugin registrant iOS/macOS setelah dependency berubah (jalankan flutter pub get)

## G. Session limit log

- Session rate limit terjadi saat migrasi; dilanjutkan pada sesi berikutnya (isi tanggal/jam bila perlu)
