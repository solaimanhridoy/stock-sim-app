const pool = require('../db/pool');

// ═══════════════════════════════════════════════════════════════════════
// POST /api/trade/buy
// ═══════════════════════════════════════════════════════════════════════
const buyStock = async (req, res) => {
  const { ticker, quantity } = req.body;
  const userId = req.userId;

  // ── Validate input ──────────────────────────────────────────────
  if (!ticker || typeof ticker !== 'string') {
    return res.status(400).json({
      success: false,
      error: { code: 'INVALID_INPUT', message: 'Ticker is required' },
    });
  }

  const qty = parseInt(quantity, 10);
  if (!Number.isInteger(qty) || qty <= 0 || qty > 10000) {
    return res.status(400).json({
      success: false,
      error: { code: 'INVALID_INPUT', message: 'Quantity must be a positive integer (max 10,000)' },
    });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // 1. Get user's simulation date and balance
    const userResult = await client.query(
      'SELECT virtual_balance, simulation_date FROM users WHERE id = $1 FOR UPDATE',
      [userId]
    );
    if (userResult.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({
        success: false,
        error: { code: 'USER_NOT_FOUND', message: 'User not found' },
      });
    }

    const user = userResult.rows[0];
    const balance = parseFloat(user.virtual_balance);
    const simDate = user.simulation_date;

    if (!simDate) {
      await client.query('ROLLBACK');
      return res.status(400).json({
        success: false,
        error: { code: 'NO_SIM_DATE', message: 'Simulation date not set. Load market data first.' },
      });
    }

    // 2. Verify stock exists and is active
    const stockResult = await client.query(
      'SELECT ticker, company_name FROM stocks WHERE ticker = $1 AND is_active = TRUE',
      [ticker.toUpperCase()]
    );
    if (stockResult.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({
        success: false,
        error: { code: 'STOCK_NOT_FOUND', message: `Stock ${ticker} not found or inactive` },
      });
    }

    // 3. Get close price for the simulation date
    const priceResult = await client.query(
      'SELECT close FROM prices WHERE ticker = $1 AND date = $2',
      [ticker.toUpperCase(), simDate]
    );
    if (priceResult.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(400).json({
        success: false,
        error: { code: 'NO_PRICE', message: `No price data for ${ticker} on ${simDate}` },
      });
    }

    const price = parseFloat(priceResult.rows[0].close);
    const totalCost = price * qty;

    // 4. Check sufficient balance
    if (balance < totalCost) {
      await client.query('ROLLBACK');
      return res.status(400).json({
        success: false,
        error: {
          code: 'INSUFFICIENT_BALANCE',
          message: `Insufficient balance. Need ৳${totalCost.toFixed(2)}, have ৳${balance.toFixed(2)}`,
        },
      });
    }

    // 5. Deduct balance
    await client.query(
      'UPDATE users SET virtual_balance = virtual_balance - $1, updated_at = NOW() WHERE id = $2',
      [totalCost, userId]
    );

    // 6. Upsert portfolio (cached holding)
    await client.query(
      `INSERT INTO portfolios (user_id, ticker, quantity, avg_price)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (user_id, ticker) DO UPDATE SET
         avg_price = (portfolios.avg_price * portfolios.quantity + $4 * $3) / (portfolios.quantity + $3),
         quantity = portfolios.quantity + $3`,
      [userId, ticker.toUpperCase(), qty, price]
    );

    // 7. Record transaction
    const txResult = await client.query(
      `INSERT INTO transactions (user_id, ticker, action, price, quantity, total_value)
       VALUES ($1, $2, 'BUY', $3, $4, $5)
       RETURNING id, ticker, action, price, quantity, total_value, date`,
      [userId, ticker.toUpperCase(), price, qty, totalCost]
    );

    await client.query('COMMIT');

    // 8. Get updated balance
    const updatedUser = await pool.query(
      'SELECT virtual_balance FROM users WHERE id = $1',
      [userId]
    );

    return res.status(200).json({
      success: true,
      data: {
        transaction: txResult.rows[0],
        updated_balance: parseFloat(updatedUser.rows[0].virtual_balance),
      },
    });
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Buy error:', error);
    return res.status(500).json({
      success: false,
      error: { code: 'SERVER_ERROR', message: 'Failed to execute buy order' },
    });
  } finally {
    client.release();
  }
};

// ═══════════════════════════════════════════════════════════════════════
// POST /api/trade/sell
// ═══════════════════════════════════════════════════════════════════════
const sellStock = async (req, res) => {
  const { ticker, quantity } = req.body;
  const userId = req.userId;

  // ── Validate input ──────────────────────────────────────────────
  if (!ticker || typeof ticker !== 'string') {
    return res.status(400).json({
      success: false,
      error: { code: 'INVALID_INPUT', message: 'Ticker is required' },
    });
  }

  const qty = parseInt(quantity, 10);
  if (!Number.isInteger(qty) || qty <= 0 || qty > 10000) {
    return res.status(400).json({
      success: false,
      error: { code: 'INVALID_INPUT', message: 'Quantity must be a positive integer (max 10,000)' },
    });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // 1. Get user's simulation date
    const userResult = await client.query(
      'SELECT simulation_date FROM users WHERE id = $1',
      [userId]
    );
    const simDate = userResult.rows[0]?.simulation_date;

    if (!simDate) {
      await client.query('ROLLBACK');
      return res.status(400).json({
        success: false,
        error: { code: 'NO_SIM_DATE', message: 'Simulation date not set.' },
      });
    }

    // 2. Check user owns enough shares (lock row for update)
    const holdingResult = await client.query(
      'SELECT quantity, avg_price FROM portfolios WHERE user_id = $1 AND ticker = $2 FOR UPDATE',
      [userId, ticker.toUpperCase()]
    );
    if (holdingResult.rows.length === 0 || holdingResult.rows[0].quantity < qty) {
      await client.query('ROLLBACK');
      const owned = holdingResult.rows[0]?.quantity || 0;
      return res.status(400).json({
        success: false,
        error: {
          code: 'INSUFFICIENT_SHARES',
          message: `Cannot sell ${qty} shares of ${ticker}. You own ${owned}.`,
        },
      });
    }

    // 3. Get current close price
    const priceResult = await client.query(
      'SELECT close FROM prices WHERE ticker = $1 AND date = $2',
      [ticker.toUpperCase(), simDate]
    );
    if (priceResult.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(400).json({
        success: false,
        error: { code: 'NO_PRICE', message: `No price data for ${ticker} on ${simDate}` },
      });
    }

    const price = parseFloat(priceResult.rows[0].close);
    const totalValue = price * qty;

    // 4. Credit balance
    await client.query(
      'UPDATE users SET virtual_balance = virtual_balance + $1, updated_at = NOW() WHERE id = $2',
      [totalValue, userId]
    );

    // 5. Update portfolio
    const currentQty = holdingResult.rows[0].quantity;
    if (currentQty === qty) {
      // Sold all — remove the holding
      await client.query(
        'DELETE FROM portfolios WHERE user_id = $1 AND ticker = $2',
        [userId, ticker.toUpperCase()]
      );
    } else {
      // Partial sell — keep avg_price the same, reduce quantity
      await client.query(
        'UPDATE portfolios SET quantity = quantity - $1 WHERE user_id = $2 AND ticker = $3',
        [qty, userId, ticker.toUpperCase()]
      );
    }

    // 6. Record transaction
    const txResult = await client.query(
      `INSERT INTO transactions (user_id, ticker, action, price, quantity, total_value)
       VALUES ($1, $2, 'SELL', $3, $4, $5)
       RETURNING id, ticker, action, price, quantity, total_value, date`,
      [userId, ticker.toUpperCase(), price, qty, totalValue]
    );

    await client.query('COMMIT');

    // 7. Get updated balance
    const updatedUser = await pool.query(
      'SELECT virtual_balance FROM users WHERE id = $1',
      [userId]
    );

    return res.status(200).json({
      success: true,
      data: {
        transaction: txResult.rows[0],
        updated_balance: parseFloat(updatedUser.rows[0].virtual_balance),
      },
    });
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Sell error:', error);
    return res.status(500).json({
      success: false,
      error: { code: 'SERVER_ERROR', message: 'Failed to execute sell order' },
    });
  } finally {
    client.release();
  }
};

module.exports = { buyStock, sellStock };
