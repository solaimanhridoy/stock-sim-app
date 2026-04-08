const db = require('./client');

/**
 * Parse a duration string like "30d" into milliseconds.
 */
function parseDuration(str) {
  const match = str.match(/^(\d+)([smhd])$/);
  if (!match) return 30 * 24 * 60 * 60 * 1000; // default 30 days
  const val = parseInt(match[1], 10);
  const unit = match[2];
  const multipliers = { s: 1000, m: 60000, h: 3600000, d: 86400000 };
  return val * multipliers[unit];
}

/**
 * Create a new session row with a hashed refresh token.
 */
const createSession = async (userId, refreshTokenHash, userAgent, ipAddress) => {
  const ttl = parseDuration(process.env.JWT_REFRESH_EXPIRY || '30d');
  const expiresAt = new Date(Date.now() + ttl);

  const result = await db.query(
    `INSERT INTO sessions (user_id, refresh_token_hash, user_agent, ip_address, expires_at)
     VALUES ($1, $2, $3, $4, $5) RETURNING *`,
    [userId, refreshTokenHash, userAgent, ipAddress, expiresAt]
  );
  return result.rows[0];
};

/**
 * Find a valid (non-expired) session by token hash.
 */
const findSessionByHash = async (tokenHash) => {
  const result = await db.query(
    'SELECT * FROM sessions WHERE refresh_token_hash = $1 AND expires_at > NOW()',
    [tokenHash]
  );
  return result.rows[0] || null;
};

/**
 * Delete a specific session by its token hash.
 */
const deleteSessionByHash = async (tokenHash) => {
  await db.query(
    'DELETE FROM sessions WHERE refresh_token_hash = $1',
    [tokenHash]
  );
};

/**
 * Delete all sessions for a user (logout everywhere).
 */
const deleteAllSessionsByUser = async (userId) => {
  await db.query(
    'DELETE FROM sessions WHERE user_id = $1',
    [userId]
  );
};

/**
 * Remove expired sessions. Call periodically.
 */
const cleanupExpired = async () => {
  const result = await db.query(
    'DELETE FROM sessions WHERE expires_at < NOW()'
  );
  return result.rowCount;
};

module.exports = {
  createSession,
  findSessionByHash,
  deleteSessionByHash,
  deleteAllSessionsByUser,
  cleanupExpired,
};
