const express = require('express');
const { buyStock, sellStock } = require('../controllers/tradeController');
const authMiddleware = require('../utils/middleware');

const router = express.Router();

// All trade routes require authentication
router.use(authMiddleware);

// POST /api/trade/buy  — Execute a buy order
router.post('/buy', buyStock);

// POST /api/trade/sell — Execute a sell order
router.post('/sell', sellStock);

module.exports = router;
