const crypto = require('crypto');

/**
 * Generate a cryptographically secure random refresh token (64 bytes → 128 hex chars).
 */
const generateRefreshToken = () => {
  return crypto.randomBytes(64).toString('hex');
};

/**
 * One-way SHA-256 hash of a token for safe DB storage.
 * Never store raw refresh tokens — only their hashes.
 */
const hashToken = (token) => {
  return crypto.createHash('sha256').update(token).digest('hex');
};

module.exports = {
  generateRefreshToken,
  hashToken,
};
