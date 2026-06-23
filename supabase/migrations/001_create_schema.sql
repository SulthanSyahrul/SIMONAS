-- Supabase PostgreSQL Schema Migration
-- Migration: 001_create_schema.sql
-- Purpose: Create complete schema for Pengawasan Kelas SMP Negeri 1 Jenar application
-- Tables: users, user_roles, guru, siswa, tahun_ajaran, kelas, mapel, jadwal, jurnal, 
--         absensi_jurnal, tugas, nilai, administrasi_pembelajaran, kelas_siswa,
--         histori_wali_kelas

-- Enable INTEGER GENERATED ALWAYS AS IDENTITY extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- USERS TABLE (Supabase Auth integration)
-- ============================================================================
CREATE TABLE IF NOT EXISTS users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(255) UNIQUE NOT NULL,
  username VARCHAR(255) NOT NULL,
  is_deleted BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Index on email for auth lookups
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_users_updated_at ON users(updated_at) WHERE is_deleted = false;

-- ============================================================================
-- USER_ROLES TABLE (Authorization)
-- ============================================================================

CREATE TABLE IF NOT EXISTS roles (
  id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  role VARCHAR(50) UNIQUE NOT NULL, -- 'admin', 'kepsek', 'guru', 'siswa'
  description TEXT,
  is_deleted BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);


CREATE INDEX IF NOT EXISTS idx_roles_updated_at ON roles(updated_at) WHERE is_deleted = false;


-- ============================================================================
-- USER_ROLES TABLE (Authorization)
-- ============================================================================
CREATE TABLE IF NOT EXISTS user_roles (
  id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  role_id INTEGER NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
  is_deleted BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(user_id, role_id)
);

-- Index for role lookups
CREATE INDEX IF NOT EXISTS idx_user_roles_user_id ON user_roles(user_id) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_user_roles_role_id ON user_roles(role_id) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_user_roles_updated_at ON user_roles(updated_at) WHERE is_deleted = false;

-- ============================================================================
-- GURU TABLE (Teachers)
-- ============================================================================
CREATE TABLE IF NOT EXISTS guru (
  id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id uuid NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  nama_lengkap VARCHAR(255) NOT NULL,
  nip VARCHAR(50) UNIQUE,
  nuptk VARCHAR(50) UNIQUE,
  golongan VARCHAR(20),
  no_hp VARCHAR(20),
  alamat TEXT,
  tanggal_lahir DATE,
  tempat_lahir VARCHAR(100),
  jenis_kelamin VARCHAR(10),

  is_deleted BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_guru_user_id ON guru(user_id) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_guru_nip ON guru(nip) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_guru_updated_at ON guru(updated_at) WHERE is_deleted = false;

-- ============================================================================
-- SISWA TABLE (Students)
-- ============================================================================
CREATE TABLE IF NOT EXISTS siswa (
  id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id uuid NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  nis VARCHAR(50) UNIQUE,
  nama VARCHAR(255) NOT NULL,
  jenis_kelamin VARCHAR(10),
  tempat_lahir VARCHAR(100),
  tanggal_lahir DATE,
  alamat TEXT,
  no_hp VARCHAR(20),

  is_deleted BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_siswa_user_id ON siswa(user_id) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_siswa_nis ON siswa(nis) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_siswa_updated_at ON siswa(updated_at) WHERE is_deleted = false;

-- ============================================================================
-- TAHUN_AJARAN TABLE (Academic Years)
-- ============================================================================
CREATE TABLE tahun_ajaran (
  id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tahun_ajaran VARCHAR(20) UNIQUE NOT NULL,
  is_aktif BOOLEAN DEFAULT false,
  is_deleted BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_tahun_ajaran_tahun ON tahun_ajaran(tahun_ajaran) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_tahun_ajaran_aktif ON tahun_ajaran(is_aktif) WHERE is_deleted = false AND is_aktif = true;
CREATE INDEX IF NOT EXISTS idx_tahun_ajaran_updated_at ON tahun_ajaran(updated_at) WHERE is_deleted = false;

-- ============================================================================
-- SEMESTER TABLE (Classes/Sections)
-- ============================================================================
CREATE TABLE semester (
  id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tahun_ajaran_id INTEGER NOT NULL REFERENCES tahun_ajaran(id),
  semester_ke INTEGER NOT NULL CHECK (semester_ke IN (1,2)),
  is_aktif BOOLEAN DEFAULT false,
  is_deleted BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(tahun_ajaran_id, semester_ke)
);

CREATE INDEX IF NOT EXISTS idx_semester_tahun_ajaran_id ON semester(tahun_ajaran_id) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_semester_aktif ON semester(is_aktif) WHERE is_deleted = false AND is_aktif = true;
CREATE INDEX IF NOT EXISTS idx_semester_updated_at ON semester(updated_at) WHERE is_deleted = false;

-- ============================================================================
-- KELAS TABLE (Classes/Sections)
-- ============================================================================
CREATE TABLE IF NOT EXISTS kelas (
  id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nama_kelas VARCHAR(50) NOT NULL, -- e.g., "7A", "8B", "9C"
  tingkat INTEGER NOT NULL, -- 7, 8, 9
  is_deleted BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(nama_kelas)
);

CREATE INDEX IF NOT EXISTS idx_kelas_updated_at ON kelas(updated_at) WHERE is_deleted = false;

-- ============================================================================
-- MAPEL TABLE (Subjects)
-- ============================================================================
CREATE TABLE IF NOT EXISTS mapel (
  id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nama_mapel VARCHAR(100) NOT NULL,
  is_deleted BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(nama_mapel)
);

CREATE INDEX IF NOT EXISTS idx_mapel_updated_at ON mapel(updated_at) WHERE is_deleted = false;

-- ============================================================================
-- JADWAL TABLE (Class Schedules)
-- ============================================================================
CREATE TABLE IF NOT EXISTS jadwal (
  id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  semester_id INTEGER NOT NULL REFERENCES semester(id) ON DELETE RESTRICT,
  guru_uid INTEGER NOT NULL REFERENCES guru(id) ON DELETE RESTRICT,
  kelas_id INTEGER NOT NULL REFERENCES kelas(id) ON DELETE RESTRICT,
  mapel_id INTEGER NOT NULL REFERENCES mapel(id) ON DELETE RESTRICT,
  hari_ke INTEGER NOT NULL, -- 1=Monday, 2=Tuesday, ..., 5=Friday
  jam_ke_awal INTEGER NOT NULL,
  jam_ke_akhir INTEGER NOT NULL,
  is_deleted BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_jadwal_semester_id ON jadwal(semester_id) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_jadwal_guru_uid ON jadwal(guru_uid) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_jadwal_kelas_id ON jadwal(kelas_id) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_jadwal_mapel_id ON jadwal(mapel_id) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_jadwal_hari_ke ON jadwal(hari_ke) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_jadwal_composite ON jadwal(guru_uid, semester_id) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_jadwal_updated_at ON jadwal(updated_at) WHERE is_deleted = false;

-- ============================================================================
-- JURNAL TABLE (Teaching Journals/Daily Records)
-- ============================================================================
CREATE TABLE IF NOT EXISTS jurnal (
  id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  guru_uid INTEGER NOT NULL REFERENCES guru(id) ON DELETE RESTRICT,
  kelas_id INTEGER NOT NULL REFERENCES kelas(id) ON DELETE RESTRICT,
  mapel_id INTEGER NOT NULL REFERENCES mapel(id) ON DELETE RESTRICT,
  semester_id INTEGER NOT NULL REFERENCES semester(id) ON DELETE RESTRICT,
  tanggal DATE NOT NULL,
  jam_ke_awal INTEGER NOT NULL,
  jam_ke_akhir INTEGER NOT NULL,
  materi_pembelajaran TEXT,
  catatan TEXT,
  status_kehadiran VARCHAR(20) DEFAULT 'Masuk', -- 'Masuk', 'Sakit', 'Izin', 'Cuti'
  is_deleted BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_jurnal_guru_uid ON jurnal(guru_uid) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_jurnal_kelas_id ON jurnal(kelas_id) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_jurnal_mapel_id ON jurnal(mapel_id) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_jurnal_semester_id ON jurnal(semester_id) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_jurnal_tanggal ON jurnal(tanggal) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_jurnal_guru_tanggal ON jurnal(guru_uid, tanggal) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_jurnal_updated_at ON jurnal(updated_at) WHERE is_deleted = false;

-- ============================================================================
-- ABSENSI_JURNAL TABLE (Student Attendance)
-- ============================================================================
CREATE TABLE IF NOT EXISTS absensi_jurnal (
  id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  jurnal_id INTEGER NOT NULL REFERENCES jurnal(id) ON DELETE CASCADE,
  siswa_uid INTEGER NOT NULL REFERENCES siswa(id) ON DELETE RESTRICT,
  status_kehadiran VARCHAR(20) DEFAULT 'Hadir', -- 'Hadir', 'Sakit', 'Izin', 'Alpa'
  is_deleted BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(jurnal_id, siswa_uid) -- One attendance record per student per journal
);

CREATE INDEX IF NOT EXISTS idx_absensi_jurnal_jurnal_id ON absensi_jurnal(jurnal_id) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_absensi_jurnal_siswa_uid ON absensi_jurnal(siswa_uid) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_absensi_jurnal_composite ON absensi_jurnal(jurnal_id, siswa_uid) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_absensi_jurnal_updated_at ON absensi_jurnal(updated_at) WHERE is_deleted = false;

-- ============================================================================
-- KELAS_SISWA TABLE (Class Enrollment)
-- ============================================================================
CREATE TABLE IF NOT EXISTS kelas_siswa (
  id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  kelas_id INTEGER NOT NULL REFERENCES kelas(id) ON DELETE CASCADE,
  siswa_uid INTEGER NOT NULL REFERENCES siswa(id) ON DELETE CASCADE,
  tahun_ajaran_id INTEGER NOT NULL REFERENCES tahun_ajaran(id) ON DELETE RESTRICT,
  status_aktif BOOLEAN DEFAULT true,
  is_deleted BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(kelas_id, siswa_uid, tahun_ajaran_id) -- Student can only be in class once per academic year
);

CREATE INDEX IF NOT EXISTS idx_kelas_siswa_kelas_id ON kelas_siswa(kelas_id) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_kelas_siswa_siswa_uid ON kelas_siswa(siswa_uid) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_kelas_siswa_composite ON kelas_siswa(kelas_id, siswa_uid, tahun_ajaran_id) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_kelas_siswa_updated_at ON kelas_siswa(updated_at) WHERE is_deleted = false;

-- ============================================================================
-- NILAI TABLE (Grades/Scores)
-- ============================================================================
CREATE TABLE IF NOT EXISTS nilai_ujian (
  id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  siswa_uid INTEGER NOT NULL REFERENCES siswa(id) ON DELETE RESTRICT,
  guru_uid INTEGER NOT NULL REFERENCES guru(id) ON DELETE RESTRICT,
  mapel_id INTEGER NOT NULL REFERENCES mapel(id) ON DELETE RESTRICT,
  kelas_id INTEGER NOT NULL REFERENCES kelas(id) ON DELETE RESTRICT,
  tahun_ajaran_id INTEGER NOT NULL REFERENCES tahun_ajaran(id) ON DELETE RESTRICT,
  nilai_uts NUMERIC(5, 2),
  nilai_uas NUMERIC(5, 2),
  is_deleted BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(siswa_uid, mapel_id, kelas_id, tahun_ajaran_id)
);

CREATE INDEX IF NOT EXISTS idx_nilai_siswa_uid ON nilai_ujian(siswa_uid) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_nilai_guru_uid ON nilai_ujian(guru_uid) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_nilai_mapel_id ON nilai_ujian(mapel_id) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_nilai_kelas_id ON nilai_ujian(kelas_id) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_nilai_tahun_ajaran_id ON nilai_ujian(tahun_ajaran_id) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_nilai_updated_at ON nilai_ujian(updated_at) WHERE is_deleted = false;

-- ============================================================================
-- TUGAS TABLE (Assignments)
-- ============================================================================
CREATE TABLE IF NOT EXISTS tugas (
  id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  guru_uid INTEGER NOT NULL REFERENCES guru(id) ON DELETE RESTRICT,
  kelas_id INTEGER NOT NULL REFERENCES kelas(id) ON DELETE RESTRICT,
  mapel_id INTEGER NOT NULL REFERENCES mapel(id) ON DELETE RESTRICT,
  semester_id INTEGER NOT NULL REFERENCES semester(id) ON DELETE RESTRICT,
  judul_tugas VARCHAR(255) NOT NULL,
  deskripsi TEXT,
  tanggal_dibuat DATE NOT NULL,
  tanggal_deadline DATE NOT NULL,
  file_url TEXT,
  is_deleted BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_tugas_guru_uid ON tugas(guru_uid) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_tugas_kelas_id ON tugas(kelas_id) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_tugas_mapel_id ON tugas(mapel_id) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_tugas_semester_id ON tugas(semester_id) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_tugas_tanggal_deadline ON tugas(tanggal_deadline) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_tugas_updated_at ON tugas(updated_at) WHERE is_deleted = false;


-- ============================================================================
-- NILAI TUGAS TABLE (Assignment Grades)
-- ============================================================================
CREATE TABLE IF NOT EXISTS nilai_tugas (
  id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tugas_id INTEGER NOT NULL REFERENCES tugas(id) ON DELETE CASCADE,
  siswa_uid INTEGER NOT NULL REFERENCES siswa(id) ON DELETE RESTRICT,
  nilai NUMERIC(5, 2),
  is_deleted BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(tugas_id, siswa_uid) -- One grade per student per assignment
);

CREATE INDEX IF NOT EXISTS idx_nilai_tugas_tugas_id ON nilai_tugas(tugas_id) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_nilai_tugas_siswa_uid ON nilai_tugas(siswa_uid) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_nilai_tugas_updated_at ON nilai_tugas(updated_at) WHERE is_deleted = false;

-- ============================================================================
-- ADMINISTRASI_PEMBELAJARAN TABLE (Learning Administration)
-- ============================================================================
CREATE TABLE IF NOT EXISTS administrasi_pembelajaran (
  id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  guru_uid INTEGER NOT NULL REFERENCES guru(id) ON DELETE RESTRICT,
  semester_id INTEGER NOT NULL REFERENCES semester(id) ON DELETE RESTRICT,
  kelas_id INTEGER NOT NULL REFERENCES kelas(id) ON DELETE RESTRICT,
  mapel_id INTEGER NOT NULL REFERENCES mapel(id) ON DELETE RESTRICT,
  judul_dokumen VARCHAR(255) NOT NULL,
  tipe_dokumen VARCHAR(100), -- 'RPP', 'Silabus', 'Prota', 'Prosem', 'Penilaian'
  deskripsi TEXT,
  file_url TEXT,
  tanggal_upload DATE NOT NULL,
  is_deleted BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_adm_pembelajaran_guru_uid ON administrasi_pembelajaran(guru_uid) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_adm_pembelajaran_semester_id ON administrasi_pembelajaran(semester_id) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_adm_pembelajaran_kelas_id ON administrasi_pembelajaran(kelas_id) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_adm_pembelajaran_mapel_id ON administrasi_pembelajaran(mapel_id) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_adm_pembelajaran_tipe ON administrasi_pembelajaran(tipe_dokumen) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_adm_pembelajaran_updated_at ON administrasi_pembelajaran(updated_at) WHERE is_deleted = false;
-- ============================================================================
-- HISTORI WALI KELAS TABLE (Class Teacher History)
-- ============================================================================

CREATE TABLE IF NOT EXISTS histori_wali_kelas (
  id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  guru_uid INTEGER NOT NULL REFERENCES guru(id) ON DELETE RESTRICT,
  kelas_id INTEGER NOT NULL REFERENCES kelas(id) ON DELETE RESTRICT,
  tahun_ajaran_id INTEGER NOT NULL REFERENCES tahun_ajaran(id) ON DELETE RESTRICT,
  is_deleted BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(guru_uid, kelas_id, tahun_ajaran_id) -- One history record per teacher-class-year
);

CREATE INDEX IF NOT EXISTS idx_histori_wali_kelas_guru_uid ON histori_wali_kelas(guru_uid) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_histori_wali_kelas_kelas_id ON histori_wali_kelas(kelas_id) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_histori_wali_kelas_tahun_ajaran_id ON histori_wali_kelas(tahun_ajaran_id) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_histori_wali_kelas_updated_at ON histori_wali_kelas(updated_at) WHERE is_deleted = false;
-- ============================================================================
-- TRIGGER: Update updated_at timestamp automatically
-- ============================================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to all tables
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_roles_updated_at BEFORE UPDATE ON roles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_user_roles_updated_at BEFORE UPDATE ON user_roles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_guru_updated_at BEFORE UPDATE ON guru FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_siswa_updated_at BEFORE UPDATE ON siswa FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_tahun_ajaran_updated_at BEFORE UPDATE ON tahun_ajaran FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_kelas_updated_at BEFORE UPDATE ON kelas FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_mapel_updated_at BEFORE UPDATE ON mapel FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_jadwal_updated_at BEFORE UPDATE ON jadwal FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_jurnal_updated_at BEFORE UPDATE ON jurnal FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_absensi_jurnal_updated_at BEFORE UPDATE ON absensi_jurnal FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_kelas_siswa_updated_at BEFORE UPDATE ON kelas_siswa FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_nilai_ujian_updated_at BEFORE UPDATE ON nilai_ujian FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_nilai_tugas_updated_at BEFORE UPDATE ON nilai_tugas FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_tugas_updated_at BEFORE UPDATE ON tugas FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_administrasi_pembelajaran_updated_at BEFORE UPDATE ON administrasi_pembelajaran FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_histori_wali_kelas_updated_at BEFORE UPDATE ON histori_wali_kelas FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- ROW-LEVEL SECURITY (RLS) POLICIES
-- ============================================================================
-- Note: Uncomment and modify based on your Supabase RLS setup
-- 
-- ALTER TABLE users ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE guru ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE siswa ENABLE ROW LEVEL SECURITY;
-- etc...
--
-- Example policy for users table:
-- CREATE POLICY "Users can view own profile" ON users
--   FOR SELECT USING (auth.uid() = id);
--
-- CREATE POLICY "Kepsek can view all users" ON users
--   FOR SELECT USING (
--     EXISTS (
--       SELECT 1 FROM user_roles ur
--       WHERE ur.user_id = auth.uid()
--       AND ur.role = 'kepsek'
--       AND ur.is_deleted = false
--     )
--   );
--
-- For comprehensive RLS implementation, refer to docs/SUPABASE_RLS_POLICIES.md

-- ============================================================================
-- MIGRATION COMPLETED
-- ============================================================================
-- Schema created successfully. Next steps:
-- 1. Run ETL script to migrate data from Firebase to PostgreSQL
-- 2. Implement RLS policies in Supabase dashboard
-- 3. Set up storage buckets (administrasi_pembelajaran, avatars)
-- 4. Run integration tests with Flutter app
