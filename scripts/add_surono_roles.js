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
    // Fetch Surono's user ID dynamically
    const userRes = await client.query("SELECT id FROM public.users WHERE email = 'surono@smpn1jenar.local'");
    if (userRes.rows.length === 0) {
      throw new Error("User surono@smpn1jenar.local not found in public.users table.");
    }
    const suronoId = userRes.rows[0].id;
    console.log(`Found Surono user ID: ${suronoId}`);

    // Fetch all roles from the database
    const rolesRes = await client.query("SELECT id, role FROM public.roles");
    console.log("Available roles in database:", rolesRes.rows);

    for (const roleRow of rolesRes.rows) {
      await client.query(`
        INSERT INTO public.user_roles (user_id, role_id, is_deleted)
        VALUES ($1, $2, false)
        ON CONFLICT (user_id, role_id) 
        DO UPDATE SET is_deleted = false
      `, [suronoId, roleRow.id]);
      console.log(`Role ${roleRow.role} (ID: ${roleRow.id}) granted/enabled for Surono.`);
    }

    const res = await client.query(`
      SELECT u.id, u.email, u.username, r.id as role_id, r.role as role_name
      FROM public.users u
      LEFT JOIN public.user_roles ur ON u.id = ur.user_id
      LEFT JOIN public.roles r ON ur.role_id = r.id
      WHERE u.id = $1 AND ur.is_deleted = false
    `, [suronoId]);
    
    console.log('\nUpdated Surono roles in DB:');
    console.table(res.rows);
  } catch (err) {
    console.error(err);
  } finally {
    await client.end();
  }
}

main().catch(console.error);
