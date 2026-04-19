const express = require('express');
const pool = require('../db/pool');
const authMiddleware = require('../utils/middleware');

const router = express.Router();

// Apply auth to all market routes
router.use(authMiddleware);

// ═══════════════════════════════════════════════════════════════════════
// GET /api/market?date=YYYY-MM-DD (optional — defaults to user's sim date)
// Returns full market data for a given date
// ═══════════════════════════════════════════════════════════════════════
router.get('/', async (req, res) => {
  const userId = req.userId;

  try {
    // 1. Get user's simulation date (or use query param for backward compat)
    let date = req.query.date;

    if (!date) {
      const userResult = await pool.query(
        'SELECT simulation_date FROM users WHERE id = $1',
        [userId]
      );
      date = userResult.rows[0]?.simulation_date;
    }

    // If still no date, initialize to first available date
    if (!date) {
      const firstDate = await pool.query('SELECT MIN(date) as first_date FROM prices');
      date = firstDate.rows[0]?.first_date;

      if (date) {
        // Persist the simulation date
        await pool.query(
          'UPDATE users SET simulation_date = $1 WHERE id = $2',
          [date, userId]
        );
      } else {
        return res.status(404).json({ success: false, message: 'No market data available' });
      }
    }

    // Normalize date format
    const dateStr = typeof date === 'object' ? date.toISOString().split('T')[0] : String(date).split('T')[0];

    // 2. Get all market data for the given date
    const marketData = await pool.query(
      `SELECT p.ticker, s.company_name, s.sector, p.open, p.high, p.low, p.close, p.volume
       FROM prices p
       JOIN stocks s ON p.ticker = s.ticker
       WHERE p.date = $1
       ORDER BY p.volume DESC`,
      [dateStr]
    );

    if (marketData.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'No market data found for this date' });
    }

    // 3. Calculate change percentage (close - open) / open
    let enrichedData = marketData.rows.map(stock => {
      const open = Number(stock.open);
      const close = Number(stock.close);
      const change = open !== 0 ? ((close - open) / open) * 100 : 0;
      
      return {
        ...stock,
        change_percentage: parseFloat(change.toFixed(2)),
      };
    });

    const gainers = enrichedData
      .filter(s => s.change_percentage > 0)
      .sort((a, b) => b.change_percentage - a.change_percentage)
      .slice(0, 5);

    const losers = enrichedData
      .filter(s => s.change_percentage < 0)
      .sort((a, b) => a.change_percentage - b.change_percentage)
      .slice(0, 5);

    return res.json({
      success: true,
      data: {
        date: dateStr,
        total_stocks: enrichedData.length,
        summary: { gainers, losers },
        market: enrichedData,
      },
    });
  } catch (error) {
    console.error('Error fetching market data:', error);
    return res.status(500).json({ success: false, error: 'Database error fetching market data' });
  }
});

// ═══════════════════════════════════════════════════════════════════════
// GET /api/market/stocks
// List all available stocks
// ═══════════════════════════════════════════════════════════════════════
router.get('/stocks', async (req, res) => {
  try {
    const stocks = await pool.query(
      'SELECT ticker, company_name, sector FROM stocks WHERE is_active = TRUE ORDER BY ticker ASC'
    );
    res.json({ success: true, data: stocks.rows });
  } catch (error) {
    console.error('Error fetching stocks:', error);
    res.status(500).json({ success: false, error: 'Database error fetching stocks' });
  }
});

// ═══════════════════════════════════════════════════════════════════════
// GET /api/market/stock/:ticker
// Stock detail with price history (last 30 available trading days)
// ═══════════════════════════════════════════════════════════════════════
router.get('/stock/:ticker', async (req, res) => {
  const { ticker } = req.params;
  const userId = req.userId;

  try {
    // Get stock info
    const stockResult = await pool.query(
      'SELECT ticker, company_name, sector, is_active FROM stocks WHERE ticker = $1',
      [ticker.toUpperCase()]
    );

    if (stockResult.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: { code: 'STOCK_NOT_FOUND', message: `Stock ${ticker} not found` },
      });
    }

    // Get user's simulation date for "current" price context
    const userResult = await pool.query(
      'SELECT simulation_date FROM users WHERE id = $1',
      [userId]
    );
    const simDate = userResult.rows[0]?.simulation_date;

    // Get price history (up to sim date, last 30 trading days)
    const priceHistory = await pool.query(
      `SELECT date, open, high, low, close, volume
       FROM prices
       WHERE ticker = $1 AND ($2::date IS NULL OR date <= $2)
       ORDER BY date DESC
       LIMIT 30`,
      [ticker.toUpperCase(), simDate]
    );

    // Get user's holding for this stock (if any)
    const holdingResult = await pool.query(
      'SELECT quantity, avg_price FROM portfolios WHERE user_id = $1 AND ticker = $2',
      [userId, ticker.toUpperCase()]
    );

    const stock = stockResult.rows[0];
    const prices = priceHistory.rows.reverse(); // chronological order
    const currentPrice = prices.length > 0 ? parseFloat(prices[prices.length - 1].close) : null;
    const holding = holdingResult.rows[0] || null;

    return res.json({
      success: true,
      data: {
        stock: {
          ...stock,
          current_price: currentPrice,
        },
        price_history: prices,
        holding: holding ? {
          quantity: holding.quantity,
          avg_price: parseFloat(holding.avg_price),
          current_value: currentPrice ? holding.quantity * currentPrice : null,
          pnl: currentPrice ? (currentPrice - parseFloat(holding.avg_price)) * holding.quantity : null,
        } : null,
        simulation_date: simDate,
      },
    });
  } catch (error) {
    console.error('Error fetching stock detail:', error);
    res.status(500).json({ success: false, error: 'Database error' });
  }
});

// ═══════════════════════════════════════════════════════════════════════
// POST /api/market/advance-day
// Server-authoritative: advances the user's simulation date to next trading day
// ═══════════════════════════════════════════════════════════════════════
router.post('/advance-day', async (req, res) => {
  const userId = req.userId;

  try {
    // Get current simulation date
    const userResult = await pool.query(
      'SELECT simulation_date FROM users WHERE id = $1',
      [userId]
    );
    const currentDate = userResult.rows[0]?.simulation_date;

    if (!currentDate) {
      // Initialize to first date
      const first = await pool.query('SELECT MIN(date) as first_date FROM prices');
      if (!first.rows[0]?.first_date) {
        return res.status(404).json({ success: false, message: 'No market data available' });
      }
      await pool.query(
        'UPDATE users SET simulation_date = $1 WHERE id = $2',
        [first.rows[0].first_date, userId]
      );
      return res.json({ success: true, data: { simulation_date: first.rows[0].first_date } });
    }

    // Find next trading day
    const nextResult = await pool.query(
      'SELECT MIN(date) as next_date FROM prices WHERE date > $1',
      [currentDate]
    );

    if (!nextResult.rows[0]?.next_date) {
      return res.status(404).json({
        success: false,
        message: 'No more historical data available. You have reached the end of simulation.',
      });
    }

    const nextDate = nextResult.rows[0].next_date;

    // Update user's simulation date
    await pool.query(
      'UPDATE users SET simulation_date = $1, updated_at = NOW() WHERE id = $2',
      [nextDate, userId]
    );

    return res.json({
      success: true,
      data: {
        previous_date: currentDate,
        simulation_date: nextDate,
      },
    });
  } catch (error) {
    console.error('Error advancing day:', error);
    res.status(500).json({ success: false, error: 'Failed to advance simulation day' });
  }
});

// ═══════════════════════════════════════════════════════════════════════
// GET /api/market/next-date?current=YYYY-MM-DD
// (LEGACY — kept for backward compatibility)
// ═══════════════════════════════════════════════════════════════════════
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
