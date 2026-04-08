const db = require('./client');

/**
 * Find a user by their Google ID.
 */
const findByGoogleId = async (googleId) => {
  const result = await db.query(
    'SELECT * FROM users WHERE google_id = $1',
    [googleId]
  );
  return result.rows[0] || null;
};

/**
 * Find a user by internal UUID.
 */
const findById = async (userId) => {
  const result = await db.query(
    'SELECT * FROM users WHERE id = $1',
    [userId]
  );
  return result.rows[0] || null;
};

/**
 * Create a new user from Google profile data.
 */
const createUser = async (googleId, email, displayName, avatarUrl) => {
  const result = await db.query(
    `INSERT INTO users (google_id, email, display_name, avatar_url)
     VALUES ($1, $2, $3, $4) RETURNING *`,
    [googleId, email, displayName, avatarUrl]
  );
  return result.rows[0];
};

/**
 * Sync display_name and avatar_url from Google on every login.
 * Keeps local data fresh if the user updates their Google profile.
 */
const updateGoogleProfile = async (userId, displayName, avatarUrl) => {
  await db.query(
    `UPDATE users SET display_name = $2, avatar_url = $3, updated_at = NOW()
     WHERE id = $1`,
    [userId, displayName, avatarUrl]
  );
};

module.exports = {
  findByGoogleId,
  findById,
  createUser,
  updateGoogleProfile,
};
