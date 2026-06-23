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
    const authRes = await client.query('SELECT count(*) FROM auth.users');
    console.log('Total users in auth.users:', authRes.rows[0].count);

    const publicRes = await client.query('SELECT count(*) FROM public.users');
    console.log('Total users in public.users:', publicRes.rows[0].count);

    const rolesRes = await client.query('SELECT count(*) FROM public.user_roles');
    console.log('Total roles in public.user_roles:', rolesRes.rows[0].count);

    // Query roles and matching users
    const roles = await client.query("SELECT * FROM public.roles");
    console.log('Roles:', roles.rows);

    const checkUser = await client.query("SELECT * FROM public.users WHERE username = 'abdulghany' OR email LIKE '%abdulghany%'");
    console.log('User abdulghany:', checkUser.rows);
  } catch (err) {
    console.error('Database inspection failed:', err);
  } finally {
    await client.end();
  }
}

main().catch(console.error);
