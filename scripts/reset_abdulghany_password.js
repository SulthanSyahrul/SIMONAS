const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const supabase = createClient(supabaseUrl, supabaseKey);

async function main() {
  const email = 'abdulghany@smpn1jenar.local';
  console.log(`Checking auth user for ${email}...`);

  // List users to find the ID
  const { data: { users }, error: listError } = await supabase.auth.admin.listUsers();
  if (listError) {
    console.error('Error listing users:', listError.message);
    return;
  }

  const user = users.find(u => u.email === email);
  if (!user) {
    console.log(`User ${email} not found in auth.users. Creating user...`);
    const { data: newUser, error: createError } = await supabase.auth.admin.createUser({
      email,
      password: '123456',
      email_confirm: true
    });
    if (createError) {
      console.error('Error creating user:', createError.message);
    } else {
      console.log('User created successfully:', newUser.user.id);
    }
  } else {
    console.log(`User ${email} found with ID: ${user.id}. Resetting password to 123456...`);
    const { data: updatedUser, error: updateError } = await supabase.auth.admin.updateUserById(
      user.id,
      { password: '123456' }
    );
    if (updateError) {
      console.error('Error updating password:', updateError.message);
    } else {
      console.log('Password reset successful!');
    }
  }
}

main().catch(console.error);
