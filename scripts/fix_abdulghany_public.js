const { Client } = require('pg');

const PROJECT_REF = 'ppdsbjwjtewbizoktcwp';
const DB_USER = `postgres.${PROJECT_REF}`;
const DB_PASSWORD = 'talangrejo2arul.';
const DB_NAME = 'postgres';
const host = 'aws-1-ap-southeast-1.pooler.supabase.com';

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
    const email = 'abdulghany@smpn1jenar.local';
    const newAuthId = 'cc57db69-ec26-4b9b-984d-2f977ef62377';

    console.log(`Fixing public user mapping for ${email}...`);

    // Get the role ID for 'siswa'
    const roleRes = await client.query("SELECT id FROM public.roles WHERE role = 'siswa'");
    if (roleRes.rows.length === 0) {
      throw new Error("Role 'siswa' not found in public.roles table.");
    }
    const siswaRoleId = roleRes.rows[0].id;

    // Let's delete any old public user and user_roles for this email first
    // to avoid constraint violations.
    const getOldUser = await client.query('SELECT id FROM public.users WHERE email = $1', [email]);
    if (getOldUser.rows.length > 0) {
      const oldId = getOldUser.rows[0].id;
      console.log(`Old user ID: ${oldId}`);
      if (oldId !== newAuthId) {
        // Delete or update
        // Since we want to link it to newAuthId, let's update public.users and public.user_roles and public.siswa
        console.log(`Updating old user ID ${oldId} to new ID ${newAuthId}...`);
        
        // 1. Temporarily disable foreign key constraints or do updates in order
        // Let's do it in order:
        // Update user_roles
        await client.query('UPDATE public.user_roles SET user_id = $1 WHERE user_id = $2', [newAuthId, oldId]);
        // Update siswa
        await client.query('UPDATE public.siswa SET user_id = $1 WHERE user_id = $2', [newAuthId, oldId]);
        // Update users
        await client.query('UPDATE public.users SET id = $1 WHERE id = $2', [newAuthId, oldId]);
        
        console.log('Update completed successfully.');
      } else {
        console.log('ID is already correct. Ensuring user_roles and siswa records exist...');
        await client.query('INSERT INTO public.user_roles (user_id, role_id) VALUES ($1, $2) ON CONFLICT DO NOTHING', [newAuthId, siswaRoleId]);
        await client.query('INSERT INTO public.siswa (user_id, nama) VALUES ($1, $2) ON CONFLICT DO NOTHING', [newAuthId, 'Abdul Ghany']);
      }
    } else {
      console.log('Public user not found, inserting new...');
      await client.query('INSERT INTO public.users (id, email, username) VALUES ($1, $2, $3)', [newAuthId, email, 'abdulghany']);
      await client.query('INSERT INTO public.user_roles (user_id, role_id) VALUES ($1, $2)', [newAuthId, siswaRoleId]);
      await client.query('INSERT INTO public.siswa (user_id, nama) VALUES ($1, $2)', [newAuthId, 'Abdul Ghany']);
    }

    const res = await client.query(`
      SELECT u.id, u.email, r.role as role_name
      FROM public.users u
      LEFT JOIN public.user_roles ur ON u.id = ur.user_id
      LEFT JOIN public.roles r ON ur.role_id = r.id
      WHERE u.email = $1
    `, [email]);
    console.table(res.rows);

  } catch (err) {
    console.error(err);
  } finally {
    await client.end();
  }
}

main().catch(console.error);
