const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

const supabase = createClient(supabaseUrl, supabaseKey);

async function main() {
  console.log("=== DB STATS ===");
  const tables = ['users', 'roles', 'user_roles', 'guru', 'siswa', 'kelas', 'mapel', 'tahun_ajaran', 'semester'];
  
  for (const table of tables) {
    const { count, error } = await supabase
      .from(table)
      .select('*', { count: 'exact', head: true });
    
    if (error) {
      console.error(`Error counting ${table}:`, error.message);
    } else {
      console.log(`Table: ${table.padEnd(15)} | Count: ${count}`);
    }
  }

  // Check mapel sample
  const { data: mapelData } = await supabase.from('mapel').select('id, nama_mapel').limit(5);
  console.log("\nSample Mapel:", mapelData);

  // Check kelas sample
  const { data: kelasData } = await supabase.from('kelas').select('id, nama_kelas, tingkat').limit(5);
  console.log("Sample Kelas:", kelasData);

  // Check roles sample
  const { data: rolesData } = await supabase.from('roles').select('id, role');
  console.log("Available Roles:", rolesData);
}

main().catch(console.error);
