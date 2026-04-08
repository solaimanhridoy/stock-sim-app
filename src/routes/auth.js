const express = require('express');
const { googleLogin, refreshAccessToken, logout } = require('../controllers/authController');
const authMiddleware = require('../utils/middleware');

const router = express.Router();

// POST /api/auth/google  — Verify Google ID token, create/find user, return JWT tokens
router.post('/google', googleLogin);

// POST /api/auth/refresh  — Rotate refresh token, issue new access token
router.post('/refresh', refreshAccessToken);

// POST /api/auth/logout   — Invalidate session, clear cookie (auth required)
router.post('/logout', authMiddleware, logout);

module.exports = router;
