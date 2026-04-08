const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000,
});

// Prevent unhandled pool errors from crashing the process
pool.on('error', (err) => {
  console.error('Unexpected idle client error:', err);
});

module.exports = {
  query: (text, params) => pool.query(text, params),
  pool,
};
