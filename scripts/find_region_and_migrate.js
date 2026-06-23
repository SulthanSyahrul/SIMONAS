const fs = require('fs');
const path = require('path');
const { Client } = require('pg');

const REGIONS = [
  'ap-southeast-1',
  'ap-southeast-2',
  'ap-northeast-1',
  'ap-northeast-2',
  'ap-south-1',
  'us-east-1',
  'us-east-2',
  'us-west-1',
  'us-west-2',
  'eu-central-1',
  'eu-west-1',
  'eu-west-2',
  'eu-west-3',
  'ca-central-1',
  'sa-east-1'
];
const PREFIXES = ['aws-0', 'aws-1', 'aws-2'];

const PROJECT_REF = 'ppdsbjwjtewbizoktcwp';
const DB_USER = `postgres.${PROJECT_REF}`;
const DB_PASSWORD = 'talangrejo2arul.';
const DB_NAME = 'postgres';

async function findRegion() {
  console.log('--- Finding Project Region with multiple prefixes ---');
  for (const prefix of PREFIXES) {
    for (const region of REGIONS) {
      const host = `${prefix}-${region}.pooler.supabase.com`;
      
      const client = new Client({
        host,
        port: 6543,
        user: DB_USER,
        password: DB_PASSWORD,
        database: DB_NAME,
        ssl: { rejectUnauthorized: false },
        connectionTimeoutMillis: 3000,
      });

      try {
        await client.connect();
        await client.end();
        console.log(`\nSUCCESS: Found correct host: ${host}!\n`);
        return host;
      } catch (err) {
        // If it's a tenant not found error, it's the wrong region/prefix
        if (err.message.includes('tenant/user') && err.message.includes('not found')) {
          continue;
        }
        
        // DNS or network error
        if (err.message.includes('ENOTFOUND') || err.message.includes('timeout')) {
          continue;
        }

        // If it's another error (like auth failed), it means this host IS routing to our tenant but auth failed
        console.log(`Host ${host} matched tenant but returned: ${err.message}`);
        if (err.message.includes('password authentication failed') || err.message.includes('database')) {
          return host;
        }
      }
    }
  }
  throw new Error('Could not find the correct host/region for your project.');
}

async function dropAllPublicTables(client) {
  console.log('--- Dropping all tables in public schema ---');
  const query = `
    SELECT table_name 
    FROM information_schema.tables 
    WHERE table_schema = 'public' AND table_type = 'BASE TABLE';
  `;
  const res = await client.query(query);
  const tables = res.rows.map(row => row.table_name);
  if (tables.length === 0) {
    console.log('No tables found in public schema.');
    return;
  }
  console.log(`Found ${tables.length} tables to drop: ${tables.join(', ')}`);
  const dropQuery = `DROP TABLE IF EXISTS ${tables.map(t => `"${t}"`).join(', ')} CASCADE;`;
  await client.query(dropQuery);
  console.log('All public tables dropped successfully.');
}

async function runMigrations(client) {
  console.log('--- Running Migrations ---');
  const migrationsDir = path.resolve(__dirname, '../supabase/migrations');
  const files = fs.readdirSync(migrationsDir)
    .filter(file => file.endsWith('.sql'))
    .sort();

  for (const file of files) {
    console.log(`Applying migration: ${file}...`);
    const filePath = path.join(migrationsDir, file);
    const sql = fs.readFileSync(filePath, 'utf8');
    try {
      await client.query(sql);
      console.log(`Migration ${file} applied successfully.`);
    } catch (err) {
      console.error(`Error in migration ${file}:`, err.message);
      throw err;
    }
  }
}

async function main() {
  const host = await findRegion();
  console.log(`Connecting to database at ${host}...`);
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
    await dropAllPublicTables(client);
    await runMigrations(client);
    console.log('\nDATABASE SCHEMA RESET COMPLETED SUCCESSFULLY!\n');
  } finally {
    await client.end();
  }
}

main().catch(err => {
  console.error('Fatal Error:', err);
  process.exit(1);
});
