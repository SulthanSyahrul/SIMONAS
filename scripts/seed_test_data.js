const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseKey) {
  console.error("Error: SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set in .env");
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false,
  },
});

const DEFAULT_PASSWORD = '123456';

async function upsertSingle(table, payload, onConflict, select = '*') {
  const { data, error } = await supabase
    .from(table)
    .upsert(payload, { onConflict })
    .select(select)
    .single();

  if (error) {
    throw error;
  }
  return data;
}

async function ensureAuthAccount(email, username, fullName, password = DEFAULT_PASSWORD) {
  // Query public users to see if they exist
  const { data: userData } = await supabase
    .from('users')
    .select('id')
    .eq('email', email.trim().toLowerCase())
    .maybeSingle();

  if (userData && userData.id) {
    console.log(`User ${email} already exists in public users. Updating auth password...`);
    const { data, error } = await supabase.auth.admin.updateUserById(userData.id, {
      password,
      email_confirm: true,
      user_metadata: { username, full_name: fullName }
    });
    if (error) throw error;
    return data.user;
  }

  // Otherwise, try creating. If it still fails due to email exists, list or catch.
  try {
    const { data, error } = await supabase.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { username, full_name: fullName }
    });
    if (error) {
      if (error.status === 422 || error.code === 'email_exists') {
        // Fallback: list users to find it
        const { data: listData, error: listError } = await supabase.auth.admin.listUsers({ perPage: 1000 });
        if (listError) throw listError;
        const match = listData.users.find(u => u.email.trim().toLowerCase() === email.trim().toLowerCase());
        if (match) {
          const { data: updData, error: updError } = await supabase.auth.admin.updateUserById(match.id, {
            password,
            email_confirm: true,
            user_metadata: { username, full_name: fullName }
          });
          if (updError) throw updError;
          return updData.user;
        }
      }
      throw error;
    }
    return data.user;
  } catch (err) {
    if (err.message && err.message.includes('already been registered')) {
      // Fallback search
      const { data: listData, error: listError } = await supabase.auth.admin.listUsers({ perPage: 1000 });
      if (listError) throw listError;
      const match = listData.users.find(u => u.email.trim().toLowerCase() === email.trim().toLowerCase());
      if (match) {
        const { data: updData, error: updError } = await supabase.auth.admin.updateUserById(match.id, {
          password,
          email_confirm: true,
          user_metadata: { username, full_name: fullName }
        });
        if (updError) throw updError;
        return updData.user;
      }
    }
    throw err;
  }
}

async function main() {
  console.log("=== Seeding Minimal Test Data ===");

  // 1. Roles Seed
  const roleSeeds = [
    { role: 'kepala_sekolah', description: 'Kepala sekolah' },
    { role: 'guru', description: 'Guru' },
    { role: 'kesiswaan', description: 'Kesiswaan / BK' },
    { role: 'siswa', description: 'Siswa' }
  ];
  const roleMap = {};
  for (const r of roleSeeds) {
    roleMap[r.role] = await upsertSingle('roles', r, 'role');
  }
  console.log("Roles seeded.");

  // 2. Tahun Ajaran Seed
  const ta = await upsertSingle('tahun_ajaran', {
    tahun_ajaran: '2025_2026',
    is_aktif: true,
    is_deleted: false
  }, 'tahun_ajaran');
  console.log("Tahun ajaran '2025_2026' seeded.");

  // 3. Semester Seed
  const sem1 = await upsertSingle('semester', {
    tahun_ajaran_id: ta.id,
    semester_ke: 1,
    is_aktif: true,
    is_deleted: false
  }, 'tahun_ajaran_id,semester_ke');
  const sem2 = await upsertSingle('semester', {
    tahun_ajaran_id: ta.id,
    semester_ke: 2,
    is_aktif: false,
    is_deleted: false
  }, 'tahun_ajaran_id,semester_ke');
  console.log("Semesters seeded.");

  // 4. Kelas Seed (2 classes: 7A, 8A)
  const kelas7A = await upsertSingle('kelas', { nama_kelas: '7A', tingkat: 7, is_deleted: false }, 'nama_kelas');
  const kelas8A = await upsertSingle('kelas', { nama_kelas: '8A', tingkat: 8, is_deleted: false }, 'nama_kelas');
  console.log("Classes 7A and 8A seeded.");

  // 5. Mapel Seed (2 subjects: Matematika, Bahasa Indonesia)
  const mapelMath = await upsertSingle('mapel', { nama_mapel: 'Matematika', is_deleted: false }, 'nama_mapel');
  const mapelIndo = await upsertSingle('mapel', { nama_mapel: 'Bahasa Indonesia', is_deleted: false }, 'nama_mapel');
  console.log("Subjects 'Matematika' and 'Bahasa Indonesia' seeded.");

  // Helper for adding user
  async function seedUser(email, username, fullName, roles) {
    const authUser = await ensureAuthAccount(email, username, fullName);
    
    // Ensure in public users
    await upsertSingle('users', {
      id: authUser.id,
      email,
      username,
      is_deleted: false
    }, 'id');

    // Assign roles
    for (const roleName of roles) {
      const r = roleMap[roleName];
      await upsertSingle('user_roles', {
        user_id: authUser.id,
        role_id: r.id,
        is_deleted: false
      }, 'user_id,role_id');
    }
    return authUser;
  }

  // 6. Users & Roles Seed
  // 1 Kepala Sekolah (Surono - has all roles for easy testing)
  const suronoUser = await seedUser('surono@smpn1jenar.local', 'surono', 'Drs. Surono, M.Pd.', ['kepala_sekolah', 'guru', 'kesiswaan', 'siswa']);
  await upsertSingle('guru', {
    user_id: suronoUser.id,
    nama_lengkap: 'Drs. Surono, M.Pd.',
    is_deleted: false
  }, 'user_id');
  console.log("Kepala Sekolah Surono seeded.");

  // 2 Guru
  const afifatunUser = await seedUser('afifatun@smpn1jenar.local', 'afifatun', 'Afifatun, S.Pd.', ['guru']);
  await upsertSingle('guru', {
    user_id: afifatunUser.id,
    nama_lengkap: 'Afifatun, S.Pd.',
    is_deleted: false
  }, 'user_id');

  const ekoUser = await seedUser('eko@smpn1jenar.local', 'eko', 'Eko, S.T.', ['guru']);
  await upsertSingle('guru', {
    user_id: ekoUser.id,
    nama_lengkap: 'Eko, S.T.',
    is_deleted: false
  }, 'user_id');
  console.log("2 Guru (Afifatun, Eko) seeded.");

  // 1 BK
  const budiUser = await seedUser('budi@smpn1jenar.local', 'budi', 'Budi, S.Psi.', ['kesiswaan', 'guru']);
  await upsertSingle('guru', {
    user_id: budiUser.id,
    nama_lengkap: 'Budi, S.Psi.',
    is_deleted: false
  }, 'user_id');
  console.log("1 BK (Budi) seeded.");

  // 2 Siswa
  const ghanyUser = await seedUser('abdulghany@smpn1jenar.local', 'abdulghany', 'Abdul Ghany', ['siswa']);
  const profileGhany = await upsertSingle('siswa', {
    user_id: ghanyUser.id,
    nama: 'Abdul Ghany',
    jenis_kelamin: 'Laki-laki',
    is_deleted: false
  }, 'user_id');
  await upsertSingle('kelas_siswa', {
    kelas_id: kelas7A.id,
    siswa_uid: profileGhany.id,
    tahun_ajaran_id: ta.id,
    status_aktif: true,
    is_deleted: false
  }, 'kelas_id,siswa_uid,tahun_ajaran_id');

  const murudulUser = await seedUser('abdulmurudul@smpn1jenar.local', 'abdulmurudul', 'Abdul Murudul', ['siswa']);
  const profileMurudul = await upsertSingle('siswa', {
    user_id: murudulUser.id,
    nis: 'M113840178',
    nama: 'Abdul Murudul',
    jenis_kelamin: 'Laki-laki',
    tempat_lahir: 'Bandung',
    tanggal_lahir: '1965-08-17',
    alamat: 'Jl. Dago 1000, Bandung, 40123',
    no_hp: '2500052',
    is_deleted: false
  }, 'user_id');
  await upsertSingle('kelas_siswa', {
    kelas_id: kelas7A.id,
    siswa_uid: profileMurudul.id,
    tahun_ajaran_id: ta.id,
    status_aktif: true,
    is_deleted: false
  }, 'kelas_id,siswa_uid,tahun_ajaran_id');
  console.log("2 Siswa (Abdul Ghany, Abdul Murudul) seeded and enrolled in class 7A.");

  console.log("🎉 Seeding complete successfully!");
}

main().catch(console.error);
