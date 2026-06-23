const { Client } = require('pg');

const PROJECT_REF = 'ppdsbjwjtewbizoktcwp';
const DB_USER = `postgres.${PROJECT_REF}`;
const DB_PASSWORD = 'talangrejo2arul.';
const DB_NAME = 'postgres';
const host = 'aws-1-ap-southeast-1.pooler.supabase.com';

const SQL = `
-- 1. Hapus kebijakan jika sudah ada
DROP POLICY IF EXISTS "Allow anonymous select for username lookup" ON public.users;

-- 2. Buat kebijakan baru agar role anon (unauthenticated) dapat membaca data users
CREATE POLICY "Allow anonymous select for username lookup" 
ON public.users
FOR SELECT 
TO anon 
USING (true);
`;

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
    console.log('Adding anonymous select policy for users table...');
    await client.query(SQL);
    console.log('Policy created successfully! Anonymous users can now query username-to-email mappings.');
  } catch (err) {
    console.error('Failed to create policy:', err);
  } finally {
    await client.end();
  }
}

main().catch(console.error);
