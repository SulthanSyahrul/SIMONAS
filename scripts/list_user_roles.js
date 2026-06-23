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
    const res = await client.query(`
      SELECT u.id, u.email, u.username, r.id as role_id, r.role as role_name
      FROM public.users u
      LEFT JOIN public.user_roles ur ON u.id = ur.user_id
      LEFT JOIN public.roles r ON ur.role_id = r.id
      WHERE u.email IN ('surono@smpn1jenar.local', 'afifatun@smpn1jenar.local', 'budi@smpn1jenar.local', 'abdulghany@smpn1jenar.local')
    `);
    console.log('User roles in DB:');
    console.table(res.rows);
  } catch (err) {
    console.error(err);
  } finally {
    await client.end();
  }
}

main().catch(console.error);
