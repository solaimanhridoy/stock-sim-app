const express = require('express');
const { getPortfolio, getTransactions } = require('../controllers/portfolioController');
const authMiddleware = require('../utils/middleware');

const router = express.Router();

// All portfolio routes require authentication
router.use(authMiddleware);

// GET /api/portfolio            — User holdings with P&L
router.get('/', getPortfolio);

// GET /api/portfolio/transactions — Transaction history
router.get('/transactions', getTransactions);

module.exports = router;
