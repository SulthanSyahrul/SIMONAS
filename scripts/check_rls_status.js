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
      SELECT id, name, public FROM storage.buckets
    `);
    console.log('Buckets in storage schema:');
    console.table(res.rows);
    
    const res2 = await client.query(`
      SELECT policyname, tablename, cmd, qual, with_check 
      FROM pg_policies 
      WHERE schemaname = 'storage'
    `);
    console.log('Existing policies in storage schema:');
    console.table(res2.rows);
  } catch (err) {
    console.error(err);
  } finally {
    await client.end();
  }
}

main().catch(console.error);
