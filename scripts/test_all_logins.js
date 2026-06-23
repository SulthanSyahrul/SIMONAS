const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const client = createClient(supabaseUrl, supabaseKey);

const TEST_USERS = [
  { role: 'Kepala Sekolah', email: 'surono@smpn1jenar.local', password: '123456' },
  { role: 'Guru', email: 'afifatun@smpn1jenar.local', password: '123456' },
  { role: 'BK (Kesiswaan)', email: 'budi@smpn1jenar.local', password: '123456' },
  { role: 'Siswa', email: 'abdulghany@smpn1jenar.local', password: '123456' },
];

async function testLogin(user) {
  console.log(`[${user.role}] Testing login for ${user.email}...`);
  const { data, error } = await client.auth.signInWithPassword({
    email: user.email,
    password: user.password,
  });

  if (error) {
    console.error(`🔴 [${user.role}] Login failed: ${error.message}`);
    return false;
  } else {
    console.log(`✅ [${user.role}] Login success! UID: ${data.user.id}`);
    return true;
  }
}

async function main() {
  console.log('--- STARTING ALL ROLES AUTHENTICATION TEST ---');
  let allSuccess = true;
  for (const user of TEST_USERS) {
    const success = await testLogin(user);
    if (!success) {
      allSuccess = false;
    }
  }
  
  if (allSuccess) {
    console.log('\n🎉 SUCCESS: All role logins are configured and working properly on Supabase Auth!');
  } else {
    console.log('\n❌ FAILURE: Some login attempts failed. Please inspect database configuration.');
  }
}

main().catch(console.error);
