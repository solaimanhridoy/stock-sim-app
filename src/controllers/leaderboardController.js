const pool = require('../db/pool');

// ═══════════════════════════════════════════════════════════════════════
// GET /api/leaderboard
// Returns top users ranked by total portfolio profit percentage
// ═══════════════════════════════════════════════════════════════════════
const getLeaderboard = async (req, res) => {
  const limit = Math.min(parseInt(req.query.limit, 10) || 20, 50);
  const userId = req.userId;

  try {
    // Calculate portfolio value for each user:
    // total_value = cash_balance + SUM(holdings * current_price)
    // profit_pct = ((total_value - 100000) / 100000) * 100
    //
    // We get the latest available price for each stock the user holds.
    const result = await pool.query(
      `WITH user_holdings AS (
        SELECT 
          u.id as user_id,
          u.display_name,
          u.avatar_url,
          u.virtual_balance,
          u.simulation_date,
          COALESCE(SUM(
            p.quantity * COALESCE(
              (SELECT pr.close FROM prices pr WHERE pr.ticker = p.ticker AND pr.date = u.simulation_date LIMIT 1),
              p.avg_price
            )
          ), 0) as holdings_value
        FROM users u
        LEFT JOIN portfolios p ON u.id = p.user_id AND p.quantity > 0
        GROUP BY u.id, u.display_name, u.avatar_url, u.virtual_balance, u.simulation_date
      )
      SELECT 
        user_id,
        display_name,
        avatar_url,
        virtual_balance::numeric as cash_balance,
        holdings_value,
        (virtual_balance::numeric + holdings_value) as total_value,
        CASE 
          WHEN 100000 > 0 THEN ROUND(((virtual_balance::numeric + holdings_value - 100000) / 100000.0) * 100, 2)
          ELSE 0
        END as profit_pct,
        ROW_NUMBER() OVER (ORDER BY (virtual_balance::numeric + holdings_value) DESC) as rank
      FROM user_holdings
      ORDER BY total_value DESC
      LIMIT $1`,
      [limit]
    );

    // Find the current user's rank if not in top N
    let currentUserRank = null;
    const inList = result.rows.find(r => r.user_id === userId);

    if (!inList) {
      const myRank = await pool.query(
        `WITH user_values AS (
          SELECT 
            u.id as user_id,
            (u.virtual_balance::numeric + COALESCE(SUM(
              p.quantity * COALESCE(
                (SELECT pr.close FROM prices pr WHERE pr.ticker = p.ticker AND pr.date = u.simulation_date LIMIT 1),
                p.avg_price
              )
            ), 0)) as total_value
          FROM users u
          LEFT JOIN portfolios p ON u.id = p.user_id AND p.quantity > 0
          GROUP BY u.id
        )
        SELECT COUNT(*) + 1 as rank, 
               (SELECT total_value FROM user_values WHERE user_id = $1) as total_value
        FROM user_values 
        WHERE total_value > (SELECT total_value FROM user_values WHERE user_id = $1)`,
        [userId]
      );
      if (myRank.rows[0]) {
        currentUserRank = {
          rank: parseInt(myRank.rows[0].rank, 10),
          total_value: parseFloat(myRank.rows[0].total_value || 100000),
        };
      }
    }

    return res.json({
      success: true,
      data: {
        leaderboard: result.rows.map(r => ({
          rank: parseInt(r.rank, 10),
          user_id: r.user_id,
          display_name: r.display_name,
          avatar_url: r.avatar_url,
          total_value: parseFloat(r.total_value),
          profit_pct: parseFloat(r.profit_pct),
          is_current_user: r.user_id === userId,
        })),
        current_user_rank: inList
          ? { rank: parseInt(inList.rank, 10), total_value: parseFloat(inList.total_value) }
          : currentUserRank,
      },
    });
  } catch (error) {
    console.error('Leaderboard error:', error);
    return res.status(500).json({
      success: false,
      error: { code: 'SERVER_ERROR', message: 'Failed to fetch leaderboard' },
    });
  }
};

module.exports = { getLeaderboard };
