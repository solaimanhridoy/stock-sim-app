const express = require('express');
const { getProfile, updateProfile } = require('../controllers/userController');
const authMiddleware = require('../utils/middleware');

const router = express.Router();

// GET  /api/user/profile  — Fetch authenticated user's profile
router.get('/profile', authMiddleware, getProfile);

// PATCH /api/user/profile — Update language or experience
router.patch('/profile', authMiddleware, updateProfile);

module.exports = router;
