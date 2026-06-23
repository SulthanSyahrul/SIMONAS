const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseKey) {
  console.error('ERROR: SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required in .env');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false,
  },
});

const TABLES_TO_CLEAR = [
  // Child tables / tables with foreign keys first
  'absensi_jurnal',
  'nilai_tugas',
  'nilai_ujian',
  'kelas_siswa',
  'histori_wali_kelas',
  'administrasi_pembelajaran',
  'jadwal',
  'jurnal',
  'tugas',
  'semester',
  'user_roles',
  'siswa',
  'guru',
  // Parent tables
  'users',
  'roles',
  'kelas',
  'mapel',
  'tahun_ajaran'
];

async function clearPublicTables() {
  console.log('--- Clearing public tables ---');
  for (const table of TABLES_TO_CLEAR) {
    console.log(`Clearing table: ${table}...`);
    try {
      const { error } = await supabase
        .from(table)
        .delete()
        .neq('created_at', '1970-01-01T00:00:00Z'); // Delete all rows
      if (error) {
        // If created_at doesn't exist, try another filter or generic delete
        const { error: error2 } = await supabase
          .from(table)
          .delete()
          .gte('id', 0); // for integer PK tables
        if (error2) {
          // Try uuid PK delete
          const { error: error3 } = await supabase
            .from(table)
            .delete()
            .neq('id', '00000000-0000-0000-0000-000000000000');
          if (error3) {
            throw new Error(`Failed to delete from ${table}: ${error3.message}`);
          }
        }
      }
      console.log(`Table ${table} cleared.`);
    } catch (err) {
      console.warn(`Warning: Could not clear ${table}: ${err.message}. This might be normal if the table is already empty or does not exist.`);
    }
  }
}

async function clearAuthUsers() {
  console.log('--- Clearing auth users ---');
  let page = 1;
  const perPage = 100;
  let deletedCount = 0;

  while (true) {
    const { data, error } = await supabase.auth.admin.listUsers({ page, perPage });
    if (error) {
      throw error;
    }

    const users = data?.users ?? [];
    if (users.length === 0) {
      break;
    }

    console.log(`Found ${users.length} auth users on page ${page}. Deleting...`);
    for (const user of users) {
      const { error: delErr } = await supabase.auth.admin.deleteUser(user.id);
      if (delErr) {
        console.error(`Error deleting user ${user.id} (${user.email}):`, delErr.message);
      } else {
        deletedCount++;
      }
    }

    if (users.length < perPage) {
      break;
    }
    // Stay on page 1 since we are deleting users
  }
  console.log(`Cleared ${deletedCount} auth users.`);
}

async function main() {
  await clearPublicTables();
  await clearAuthUsers();
  console.log('Database data cleared successfully!');
}

main().catch((err) => {
  console.error('Fatal Error:', err);
  process.exit(1);
});
