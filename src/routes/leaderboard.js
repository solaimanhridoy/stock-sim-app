const express = require('express');
const { getLeaderboard } = require('../controllers/leaderboardController');
const authMiddleware = require('../utils/middleware');

const router = express.Router();

// All leaderboard routes require authentication
router.use(authMiddleware);

// GET /api/leaderboard — Top users ranked by profit %
router.get('/', getLeaderboard);

module.exports = router;
