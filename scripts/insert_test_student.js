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

async function main() {
  console.log("Inserting test student 'Abdul Murudul' based on Bab 5 testing scenario...");

  const email = 'abdulmurudul@smpn1jenar.local';
  const username = 'abdulmurudul';
  const password = '123456';
  const fullName = 'Abdul Murudul';

  // 1. Get role ID for 'siswa'
  const { data: roleData, error: roleError } = await supabase
    .from('roles')
    .select('id')
    .eq('role', 'siswa')
    .single();

  if (roleError || !roleData) {
    console.error("Error getting student role:", roleError?.message || "Role not found");
    process.exit(1);
  }
  const studentRoleId = roleData.id;
  console.log(`Found student role ID: ${studentRoleId}`);

  // 2. Check if auth user already exists
  let authUser = null;
  const { data: listData, error: listError } = await supabase.auth.admin.listUsers();
  if (listError) {
    console.error("Error listing users:", listError.message);
    process.exit(1);
  }

  const existingAuth = listData.users.find(u => u.email === email);
  if (existingAuth) {
    console.log(`Auth user already exists with ID: ${existingAuth.id}`);
    authUser = existingAuth;
  } else {
    // Create auth user
    const { data: createData, error: createError } = await supabase.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: {
        username,
        full_name: fullName,
      },
    });

    if (createError) {
      console.error("Error creating auth user:", createError.message);
      process.exit(1);
    }
    console.log(`Created auth user with ID: ${createData.user.id}`);
    authUser = createData.user;
  }

  // 3. Ensure public user exists
  const { error: userError } = await supabase
    .from('users')
    .upsert({
      id: authUser.id,
      email,
      username,
      is_deleted: false,
    }, { onConflict: 'id' });

  if (userError) {
    console.error("Error upserting public user:", userError.message);
    process.exit(1);
  }
  console.log("Upserted public user.");

  // 4. Ensure user role exists
  const { error: roleAssignError } = await supabase
    .from('user_roles')
    .upsert({
      user_id: authUser.id,
      role_id: studentRoleId,
      is_deleted: false,
    }, { onConflict: 'user_id,role_id' });

  if (roleAssignError) {
    console.error("Error assigning role:", roleAssignError.message);
    process.exit(1);
  }
  console.log("Assigned 'siswa' role.");

  // 5. Ensure student profile exists with Bab 5 details:
  // NIM=M113840178,
  // Nama=Abdul Murudul,
  // Jenis kelamin=L (Laki-laki),
  // Tempat lahir=Bandung,
  // Tanggal lahir=17/08/65 -> 1965-08-17,
  // Alamat=Jl. Dago 1000, Bandung, 40123
  // No. telepon=2500052
  const studentProfile = {
    user_id: authUser.id,
    nis: 'M113840178',
    nama: fullName,
    jenis_kelamin: 'Laki-laki',
    tempat_lahir: 'Bandung',
    tanggal_lahir: '1965-08-17',
    alamat: 'Jl. Dago 1000, Bandung, 40123',
    no_hp: '2500052',
    is_deleted: false,
  };

  const { data: profileData, error: profileError } = await supabase
    .from('siswa')
    .upsert(studentProfile, { onConflict: 'user_id' })
    .select();

  if (profileError) {
    console.error("Error upserting student profile:", profileError.message);
    process.exit(1);
  }
  console.log("Upserted student profile successfully:", profileData);
  console.log("🎉 Test student Abdul Murudul inserted successfully!");
}

main().catch(console.error);
