/**
 * Migration: Add simulation_date column to users table.
 * Server-authoritative simulation date tracking.
 * 
 * Run: node scripts/migrate_add_simulation_date.js
 */

const pool = require('../src/db/pool');

async function main() {
  const client = await pool.connect();
  try {
    console.log('🔄 Adding simulation_date column to users table...');

    // Add column if it doesn't exist
    await client.query(`
      ALTER TABLE users
      ADD COLUMN IF NOT EXISTS simulation_date DATE DEFAULT NULL
    `);

    // Set default simulation_date to earliest available price date for existing users
    const earliest = await client.query('SELECT MIN(date) as first_date FROM prices');
    if (earliest.rows[0]?.first_date) {
      const firstDate = earliest.rows[0].first_date;
      await client.query(
        `UPDATE users SET simulation_date = $1 WHERE simulation_date IS NULL`,
        [firstDate]
      );
      console.log(`✅ Set default simulation_date to ${firstDate} for existing users`);
    } else {
      console.log('⚠️  No price data found — simulation_date will be set on first market fetch');
    }

    console.log('✅ Migration complete');
  } catch (err) {
    console.error('❌ Migration failed:', err);
  } finally {
    client.release();
    await pool.end();
  }
}

main();
