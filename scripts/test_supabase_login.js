const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabaseUrl = process.env.SUPABASE_URL;
const client = createClient(supabaseUrl, 'sb_publishable_GRciSTtW9eP4zp-eQAOzKg_2ANLgbEy');

async function testLogin(email, password) {
  console.log(`Testing login for ${email} with password "${password}"...`);
  const { data, error } = await client.auth.signInWithPassword({
    email,
    password,
  });

  if (error) {
    console.error(`Login failed: ${error.message}`);
  } else {
    console.log('Login success!', {
      id: data.user.id,
      email: data.user.email,
      role: data.user.role,
    });
  }
}

async function main() {
  await testLogin('abdulghany@smpn1jenar.local', '123456');
}

main().catch(console.error);
