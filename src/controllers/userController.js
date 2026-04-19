const db = require('../db/client');

/**
 * GET /api/user/profile
 * Returns the authenticated user's profile.
 */
const getProfile = async (req, res) => {
  try {
    const result = await db.query(
      `SELECT id, google_id, email, display_name, avatar_url,
              language, experience, virtual_balance, simulation_date, created_at
       FROM users WHERE id = $1`,
      [req.userId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: 'User not found' },
      });
    }

    const u = result.rows[0];
    return res.status(200).json({
      success: true,
      data: {
        id: u.id,
        displayName: u.display_name,
        email: u.email,
        avatarUrl: u.avatar_url,
        language: u.language,
        experience: u.experience,
        virtualBalance: parseFloat(u.virtual_balance),
        createdAt: u.created_at,
      },
    });
  } catch (error) {
    console.error('Get profile error:', error);
    return res.status(500).json({
      success: false,
      error: { code: 'SERVER_ERROR', message: 'Failed to retrieve profile' },
    });
  }
};

/**
 * PATCH /api/user/profile
 * Update language and/or experience fields.
 */
const updateProfile = async (req, res) => {
  try {
    const { display_name, language, experience } = req.body;
    const updates = [];
    const values = [];
    let paramIdx = 1;

    if (display_name !== undefined) {
      const trimmed = typeof display_name === 'string' ? display_name.trim() : '';
      if (!trimmed || trimmed.length > 100) {
        return res.status(400).json({
          success: false,
          error: { code: 'INVALID_FIELD', message: 'Display name must be 1-100 characters' },
        });
      }
      updates.push(`display_name = $${paramIdx++}`);
      values.push(trimmed);
    }

    if (language !== undefined) {
      if (typeof language !== 'string' || !['bn', 'en'].includes(language)) {
        return res.status(400).json({
          success: false,
          error: { code: 'INVALID_FIELD', message: 'Language must be "bn" or "en"' },
        });
      }
      updates.push(`language = $${paramIdx++}`);
      values.push(language);
    }

    if (experience !== undefined) {
      if (typeof experience !== 'string' || !['beginner', 'intermediate'].includes(experience)) {
        return res.status(400).json({
          success: false,
          error: { code: 'INVALID_FIELD', message: 'Experience must be "beginner" or "intermediate"' },
        });
      }
      updates.push(`experience = $${paramIdx++}`);
      values.push(experience);
    }

    if (updates.length === 0) {
      return res.status(400).json({
        success: false,
        error: { code: 'INVALID_FIELD', message: 'No valid fields provided to update' },
      });
    }

    values.push(req.userId);
    const query = `UPDATE users SET ${updates.join(', ')}, updated_at = NOW()
                   WHERE id = $${paramIdx}
                   RETURNING id, display_name, language, experience`;

    const result = await db.query(query, values);

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: 'User not found' },
      });
    }

    const u = result.rows[0];
    return res.status(200).json({
      success: true,
      data: {
        id: u.id,
        displayName: u.display_name,
        language: u.language,
        experience: u.experience,
      },
    });
  } catch (error) {
    console.error('Update profile error:', error);
    return res.status(500).json({
      success: false,
      error: { code: 'SERVER_ERROR', message: 'Failed to update profile' },
    });
  }
};

module.exports = {
  getProfile,
  updateProfile,
};
