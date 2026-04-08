const express = require('express');
const pool = require('../db/pool');
const authMiddleware = require('../utils/middleware');

const router = express.Router();

// Apply auth to all market routes
router.use(authMiddleware);

// GET /api/market?date=YYYY-MM-DD
router.get('/', async (req, res) => {
  const { date } = req.query;

  if (!date) {
    return res.status(400).json({ success: false, error: 'Query parameter "date" is required (YYYY-MM-DD)' });
  }

  try {
    // 1. Get all market data for the given date
    const marketData = await pool.query(
      `SELECT p.ticker, s.company_name, s.sector, p.open, p.high, p.low, p.close, p.volume
       FROM prices p
       JOIN stocks s ON p.ticker = s.ticker
       WHERE p.date = $1
       ORDER BY p.volume DESC`,
      [date]
    );

    if (marketData.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'No market data found for this date' });
    }

    // 2. Calculate top gainers, losers, and overall market summary
    // Since we don't necessarily have previous day data easily accessible in this single query,
    // we'll approximate the price change today as (close - open) / open for the MVP.
    // In a real simulator, you'd compare current close to previous close.
    let enrichedData = marketData.rows.map(stock => {
      const open = Number(stock.open);
      const close = Number(stock.close);
      const change = open !== 0 ? ((close - open) / open) * 100 : 0;
      
      return {
        ...stock,
        change_percentage: parseFloat(change.toFixed(2))
      };
    });

    const gainers = enrichedData.filter(s => s.change_percentage > 0).sort((a, b) => b.change_percentage - a.change_percentage).slice(0, 5);
    const losers = enrichedData.filter(s => s.change_percentage < 0).sort((a, b) => a.change_percentage - b.change_percentage).slice(0, 5);

    return res.json({
      success: true,
      data: {
        date,
        total_stocks: enrichedData.length,
        summary: {
          gainers,
          losers
        },
        market: enrichedData
      }
    });

  } catch (error) {
    console.error('Error fetching market date:', error);
    return res.status(500).json({ success: false, error: 'Database error fetching market data' });
  }
});

// GET /api/market/stocks
// Get a list of all available stocks
router.get('/stocks', async (req, res) => {
  try {
    const stocks = await pool.query('SELECT ticker, company_name, sector FROM stocks WHERE is_active = TRUE ORDER BY ticker ASC');
    res.json({ success: true, data: stocks.rows });
  } catch (error) {
    console.error('Error fetching stocks:', error);
    res.status(500).json({ success: false, error: 'Database error fetching stocks' });
  }
});

// GET /api/market/next-date?current=YYYY-MM-DD
// Finds the next date that has price data in the system
router.get('/next-date', async (req, res) => {
  const { current } = req.query;
  if (!current) return res.status(400).json({ success: false, error: 'Current date required' });

  try {
    const result = await pool.query(
      'SELECT MIN(date) as next_date FROM prices WHERE date > $1',
      [current]
    );
    
    if (!result.rows[0].next_date) {
      return res.status(404).json({ success: false, message: 'No more historical data available' });
    }

    res.json({ success: true, data: { next_date: result.rows[0].next_date } });
  } catch (error) {
    res.status(500).json({ success: false, error: 'Database error' });
  }
});

module.exports = router;
