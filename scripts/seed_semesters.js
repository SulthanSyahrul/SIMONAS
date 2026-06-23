const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

const supabase = createClient(supabaseUrl, supabaseKey);

async function seedSemesters() {
  console.log('--- Seeding Semesters ---');
  
  // 1. Get the tahun_ajaran ID
  const { data: taData, error: taError } = await supabase
    .from('tahun_ajaran')
    .select('id, tahun_ajaran')
    .eq('tahun_ajaran', '2025_2026')
    .single();

  if (taError) {
    console.error('Error fetching tahun_ajaran:', taError.message);
    return;
  }

  const taId = taData.id;
  console.log(`Found tahun_ajaran '2025_2026' with ID: ${taId}`);

  // 2. Insert Semester 1 & 2
  const semesters = [
    { tahun_ajaran_id: taId, semester_ke: 1, is_aktif: true, is_deleted: false },
    { tahun_ajaran_id: taId, semester_ke: 2, is_aktif: false, is_deleted: false }
  ];

  for (const sem of semesters) {
    const { data, error } = await supabase
      .from('semester')
      .upsert(sem, { onConflict: 'tahun_ajaran_id,semester_ke' })
      .select();

    if (error) {
      console.error(`Error seeding semester ${sem.semester_ke}:`, error.message);
    } else {
      console.log(`Semester ${sem.semester_ke} seeded:`, data);
    }
  }
}

seedSemesters().catch(err => {
  console.error('Semester seeding failed:', err);
});
