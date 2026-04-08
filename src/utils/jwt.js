const jwt = require('jsonwebtoken');

const JWT_SECRET = process.env.JWT_SECRET;

if (!JWT_SECRET || JWT_SECRET === 'your-256-bit-secret-code') {
  console.warn(
    '⚠️  WARNING: JWT_SECRET is not set or is using the placeholder value. ' +
    'Set a strong secret in .env before deploying to production.'
  );
}

/**
 * Sign an access token.
 * Payload should include: { sub, email, lang }
 */
const signAccessToken = (payload) => {
  return jwt.sign(payload, JWT_SECRET, {
    expiresIn: process.env.JWT_ACCESS_EXPIRY || '15m',
    issuer: 'auth-api',
  });
};

/**
 * Verify and decode an access token.
 * Throws on invalid/expired tokens.
 */
const verifyAccessToken = (token) => {
  return jwt.verify(token, JWT_SECRET, {
    issuer: 'auth-api',
  });
};

module.exports = {
  signAccessToken,
  verifyAccessToken,
};
