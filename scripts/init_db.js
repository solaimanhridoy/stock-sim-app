require('dotenv').config();
const fs = require('fs');
const path = require('path');
const { Client } = require('pg');

async function main() {
  const connectionString = process.env.DATABASE_URL;
  if (!connectionString) {
    console.error('Error: DATABASE_URL not found in .env');
    process.exit(1);
  }

  const client = new Client({ connectionString });

  try {
    console.log('--- Connecting to PostgreSQL ---');
    await client.connect();

    console.log('--- Reading Schema File ---');
    const schemaPath = path.join(__dirname, '../src/db/schema.sql');
    const sql = fs.readFileSync(schemaPath, 'utf-8');

    console.log('--- Executing Schema ---');
    await client.query(sql);

    console.log('✅ Database schema initialized successfully.');
  } catch (err) {
    console.error('❌ Error initializing database:', err.message);
    if (err.message.includes('authentication failed')) {
      console.error('\nTIP: Check your DATABASE_URL in .env. Ensure the username and password are correct.');
    }
  } finally {
    await client.end();
  }
}

main();
