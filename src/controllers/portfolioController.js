const pool = require('../db/pool');

// ═══════════════════════════════════════════════════════════════════════
// GET /api/portfolio
// Returns user's holdings with current market values and P&L
// ═══════════════════════════════════════════════════════════════════════
const getPortfolio = async (req, res) => {
  const userId = req.userId;

  try {
    // 1. Get user's simulation date and balance
    const userResult = await pool.query(
      'SELECT virtual_balance, simulation_date FROM users WHERE id = $1',
      [userId]
    );
    if (userResult.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: { code: 'USER_NOT_FOUND', message: 'User not found' },
      });
    }

    const { virtual_balance, simulation_date: simDate } = userResult.rows[0];
    const cashBalance = parseFloat(virtual_balance);

    if (!simDate) {
      return res.json({
        success: true,
        data: {
          holdings: [],
          summary: {
            total_invested: 0,
            total_market_value: 0,
            total_pnl: 0,
            total_pnl_percentage: 0,
            cash_balance: cashBalance,
            total_portfolio_value: cashBalance,
          },
        },
      });
    }

    // 2. Get holdings joined with current prices and stock info
    const holdingsResult = await pool.query(
      `SELECT
         p.ticker,
         s.company_name,
         s.sector,
         p.quantity,
         p.avg_price,
         COALESCE(pr.close, p.avg_price) as current_price
       FROM portfolios p
       JOIN stocks s ON p.ticker = s.ticker
       LEFT JOIN prices pr ON p.ticker = pr.ticker AND pr.date = $2
       WHERE p.user_id = $1 AND p.quantity > 0
       ORDER BY p.ticker`,
      [userId, simDate]
    );

    // 3. Compute P&L for each holding
    let totalInvested = 0;
    let totalMarketValue = 0;

    const holdings = holdingsResult.rows.map(h => {
      const qty = h.quantity;
      const avgPrice = parseFloat(h.avg_price);
      const currentPrice = parseFloat(h.current_price);
      const costBasis = avgPrice * qty;
      const marketValue = currentPrice * qty;
      const unrealizedPnl = marketValue - costBasis;
      const pnlPercentage = costBasis > 0 ? (unrealizedPnl / costBasis) * 100 : 0;

      totalInvested += costBasis;
      totalMarketValue += marketValue;

      return {
        ticker: h.ticker,
        company_name: h.company_name,
        sector: h.sector,
        quantity: qty,
        avg_price: avgPrice,
        current_price: currentPrice,
        cost_basis: parseFloat(costBasis.toFixed(2)),
        market_value: parseFloat(marketValue.toFixed(2)),
        unrealized_pnl: parseFloat(unrealizedPnl.toFixed(2)),
        pnl_percentage: parseFloat(pnlPercentage.toFixed(2)),
      };
    });

    const totalPnl = totalMarketValue - totalInvested;
    const totalPnlPct = totalInvested > 0 ? (totalPnl / totalInvested) * 100 : 0;

    return res.json({
      success: true,
      data: {
        simulation_date: simDate,
        holdings,
        summary: {
          total_invested: parseFloat(totalInvested.toFixed(2)),
          total_market_value: parseFloat(totalMarketValue.toFixed(2)),
          total_pnl: parseFloat(totalPnl.toFixed(2)),
          total_pnl_percentage: parseFloat(totalPnlPct.toFixed(2)),
          cash_balance: cashBalance,
          total_portfolio_value: parseFloat((cashBalance + totalMarketValue).toFixed(2)),
          holdings_count: holdings.length,
        },
      },
    });
  } catch (error) {
    console.error('Portfolio error:', error);
    return res.status(500).json({
      success: false,
      error: { code: 'SERVER_ERROR', message: 'Failed to fetch portfolio' },
    });
  }
};

// ═══════════════════════════════════════════════════════════════════════
// GET /api/portfolio/transactions
// Returns user's transaction history, most recent first
// ═══════════════════════════════════════════════════════════════════════
const getTransactions = async (req, res) => {
  const userId = req.userId;
  const limit = Math.min(parseInt(req.query.limit, 10) || 50, 200);
  const offset = parseInt(req.query.offset, 10) || 0;

  try {
    const result = await pool.query(
      `SELECT t.id, t.ticker, s.company_name, t.action, t.price, t.quantity, 
              t.total_value, t.date
       FROM transactions t
       JOIN stocks s ON t.ticker = s.ticker
       WHERE t.user_id = $1
       ORDER BY t.date DESC, t.id DESC
       LIMIT $2 OFFSET $3`,
      [userId, limit, offset]
    );

    const countResult = await pool.query(
      'SELECT COUNT(*) as total FROM transactions WHERE user_id = $1',
      [userId]
    );

    return res.json({
      success: true,
      data: {
        transactions: result.rows,
        pagination: {
          total: parseInt(countResult.rows[0].total, 10),
          limit,
          offset,
        },
      },
    });
  } catch (error) {
    console.error('Transactions error:', error);
    return res.status(500).json({
      success: false,
      error: { code: 'SERVER_ERROR', message: 'Failed to fetch transactions' },
    });
  }
};

module.exports = { getPortfolio, getTransactions };
