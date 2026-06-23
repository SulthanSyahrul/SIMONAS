const { Client } = require('pg');

const PROJECT_REF = 'ppdsbjwjtewbizoktcwp';
const DB_USER = `postgres.${PROJECT_REF}`;
const DB_PASSWORD = 'talangrejo2arul.';
const DB_NAME = 'postgres';
const host = 'aws-1-ap-southeast-1.pooler.supabase.com';

const RLS_SQL = `
-- 1. Helper Functions
CREATE OR REPLACE FUNCTION user_has_role(user_id UUID, role_name VARCHAR)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM user_roles ur
    JOIN roles r ON ur.role_id = r.id
    WHERE ur.user_id = $1
    AND r.role = $2
    AND ur.is_deleted = false
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Drop existing policies if any
DO $$
DECLARE
    pol record;
BEGIN
    FOR pol IN 
        SELECT policyname, tablename 
        FROM pg_policies 
        WHERE schemaname = 'public'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON %I', pol.policyname, pol.tablename);
    END LOOP;
END $$;

-- 3. Users Table Policies
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view all users" ON users FOR SELECT USING (true);
CREATE POLICY "Insert policy for users" ON users FOR INSERT WITH CHECK (true);
CREATE POLICY "Users can update own or kepsek update users" ON users FOR UPDATE USING (auth.uid() = id OR user_has_role(auth.uid(), 'kepala_sekolah') OR user_has_role(auth.uid(), 'kesiswaan'));

-- 4. Roles Table Policies
ALTER TABLE roles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "View roles" ON roles FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Manage roles" ON roles FOR ALL USING (user_has_role(auth.uid(), 'kepala_sekolah'));

-- 5. User Roles Table Policies
ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "View user roles" ON user_roles FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Manage user roles" ON user_roles FOR ALL USING (user_has_role(auth.uid(), 'kepala_sekolah') OR user_has_role(auth.uid(), 'kesiswaan'));

-- 6. Guru Table Policies
ALTER TABLE guru ENABLE ROW LEVEL SECURITY;
CREATE POLICY "View guru data" ON guru FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Insert guru data" ON guru FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "Update guru data" ON guru FOR UPDATE USING (auth.uid() = user_id OR user_has_role(auth.uid(), 'kepala_sekolah') OR user_has_role(auth.uid(), 'kesiswaan'));

-- 7. Siswa Table Policies
ALTER TABLE siswa ENABLE ROW LEVEL SECURITY;
CREATE POLICY "View siswa data" ON siswa FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Insert siswa data" ON siswa FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "Update siswa data" ON siswa FOR UPDATE USING (auth.uid() = user_id OR user_has_role(auth.uid(), 'kepala_sekolah') OR user_has_role(auth.uid(), 'kesiswaan'));

-- 8. Tahun Ajaran Table Policies
ALTER TABLE tahun_ajaran ENABLE ROW LEVEL SECURITY;
CREATE POLICY "View tahun ajaran" ON tahun_ajaran FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Manage tahun ajaran" ON tahun_ajaran FOR ALL USING (user_has_role(auth.uid(), 'kepala_sekolah'));

-- 9. Semester Table Policies
ALTER TABLE semester ENABLE ROW LEVEL SECURITY;
CREATE POLICY "View semester" ON semester FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Manage semester" ON semester FOR ALL USING (user_has_role(auth.uid(), 'kepala_sekolah'));

-- 10. Kelas Table Policies
ALTER TABLE kelas ENABLE ROW LEVEL SECURITY;
CREATE POLICY "View kelas" ON kelas FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Manage kelas" ON kelas FOR ALL USING (user_has_role(auth.uid(), 'kepala_sekolah'));

-- 11. Mapel Table Policies
ALTER TABLE mapel ENABLE ROW LEVEL SECURITY;
CREATE POLICY "View mapel" ON mapel FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Manage mapel" ON mapel FOR ALL USING (user_has_role(auth.uid(), 'kepala_sekolah'));

-- 12. Jadwal Table Policies
ALTER TABLE jadwal ENABLE ROW LEVEL SECURITY;
CREATE POLICY "View jadwal" ON jadwal FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Manage jadwal" ON jadwal FOR ALL USING (user_has_role(auth.uid(), 'kepala_sekolah'));

-- 13. Jurnal Table Policies
ALTER TABLE jurnal ENABLE ROW LEVEL SECURITY;
CREATE POLICY "View jurnal" ON jurnal FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Guru insert own jurnal" ON jurnal FOR INSERT WITH CHECK (auth.uid() = (SELECT user_id FROM guru WHERE guru.id = guru_uid));
CREATE POLICY "Guru update own jurnal" ON jurnal FOR UPDATE USING (auth.uid() = (SELECT user_id FROM guru WHERE guru.id = guru_uid));
CREATE POLICY "Kepsek delete jurnal" ON jurnal FOR DELETE USING (user_has_role(auth.uid(), 'kepala_sekolah'));

-- 14. Absensi Jurnal Table Policies
ALTER TABLE absensi_jurnal ENABLE ROW LEVEL SECURITY;
CREATE POLICY "View absensi_jurnal" ON absensi_jurnal FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Guru insert absensi" ON absensi_jurnal FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "Guru update absensi" ON absensi_jurnal FOR UPDATE USING (auth.uid() IS NOT NULL);

-- 15. Kelas Siswa Table Policies
ALTER TABLE kelas_siswa ENABLE ROW LEVEL SECURITY;
CREATE POLICY "View kelas_siswa" ON kelas_siswa FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Manage kelas_siswa" ON kelas_siswa FOR ALL USING (user_has_role(auth.uid(), 'kepala_sekolah') OR user_has_role(auth.uid(), 'kesiswaan'));

-- 16. Nilai Ujian Table Policies
ALTER TABLE nilai_ujian ENABLE ROW LEVEL SECURITY;
CREATE POLICY "View nilai_ujian" ON nilai_ujian FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Guru manage nilai_ujian" ON nilai_ujian FOR ALL USING (auth.uid() = (SELECT user_id FROM guru WHERE guru.id = guru_uid) OR user_has_role(auth.uid(), 'kepala_sekolah'));

-- 17. Nilai Tugas Table Policies
ALTER TABLE nilai_tugas ENABLE ROW LEVEL SECURITY;
CREATE POLICY "View nilai_tugas" ON nilai_tugas FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Guru manage nilai_tugas" ON nilai_tugas FOR ALL USING (auth.uid() IS NOT NULL);

-- 18. Tugas Table Policies
ALTER TABLE tugas ENABLE ROW LEVEL SECURITY;
CREATE POLICY "View tugas" ON tugas FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Guru manage tugas" ON tugas FOR ALL USING (auth.uid() = (SELECT user_id FROM guru WHERE guru.id = guru_uid) OR user_has_role(auth.uid(), 'kepala_sekolah'));

-- 19. Administrasi Pembelajaran Table Policies
ALTER TABLE administrasi_pembelajaran ENABLE ROW LEVEL SECURITY;
CREATE POLICY "View administrasi_pembelajaran" ON administrasi_pembelajaran FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Guru manage own administrasi" ON administrasi_pembelajaran FOR ALL USING (auth.uid() = (SELECT user_id FROM guru WHERE guru.id = guru_uid) OR user_has_role(auth.uid(), 'kepala_sekolah'));

-- 20. Histori Wali Kelas Table Policies
ALTER TABLE histori_wali_kelas ENABLE ROW LEVEL SECURITY;
CREATE POLICY "View histori_wali_kelas" ON histori_wali_kelas FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Manage histori_wali_kelas" ON histori_wali_kelas FOR ALL USING (user_has_role(auth.uid(), 'kepala_sekolah'));
`;

async function main() {
  const client = new Client({
    host,
    port: 6543,
    user: DB_USER,
    password: DB_PASSWORD,
    database: DB_NAME,
    ssl: { rejectUnauthorized: false },
  });

  await client.connect();
  try {
    console.log('Running RLS policy setup SQL...');
    await client.query(RLS_SQL);
    console.log('RLS policies setup successfully!');
  } catch (err) {
    console.error('RLS policy setup failed:', err);
  } finally {
    await client.end();
  }
}

main().catch(console.error);
