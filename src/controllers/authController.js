const { OAuth2Client } = require('google-auth-library');
const usersDb = require('../db/users');
const sessionsDb = require('../db/sessions');
const { signAccessToken } = require('../utils/jwt');
const { generateRefreshToken, hashToken } = require('../utils/tokens');

const googleClient = new OAuth2Client(process.env.GOOGLE_CLIENT_ID);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/** Build a safe user object for API responses. */
const sanitizeUser = (u) => ({
  id: u.id,
  displayName: u.display_name,
  email: u.email,
  avatarUrl: u.avatar_url,
  language: u.language,
  experience: u.experience,
  virtualBalance: parseFloat(u.virtual_balance),
});

/** Set the refresh-token cookie with secure defaults. */
const setRefreshCookie = (res, token) => {
  const maxAge = 30 * 24 * 60 * 60 * 1000; // 30 days
  res.cookie('refreshToken', token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'Strict',
    path: '/api/auth',          // scope cookie to auth routes only
    maxAge,
  });
};

// ---------------------------------------------------------------------------
// POST /api/auth/google
// ---------------------------------------------------------------------------
const googleLogin = async (req, res) => {
  try {
    const { idToken, accessToken: googleAccessToken } = req.body;

    if (!idToken && !googleAccessToken) {
      return res.status(400).json({
        success: false,
        error: { code: 'MISSING_TOKEN', message: 'idToken or accessToken is required' },
      });
    }

    let googleId, email, displayName, avatarUrl;

    if (idToken) {
      // 1. Verify the Google ID token
      try {
        const ticket = await googleClient.verifyIdToken({
          idToken,
          audience: process.env.GOOGLE_CLIENT_ID,
        });
        const payload = ticket.getPayload();
        googleId = payload.sub;
        email = payload.email;
        displayName = payload.name;
        avatarUrl = payload.picture;
      } catch (verifyErr) {
        console.error('Google idToken verification failed:', verifyErr.message);
        return res.status(401).json({
          success: false,
          error: { code: 'INVALID_GOOGLE_TOKEN', message: 'Google token verification failed' },
        });
      }
    } else {
      // 1b. Verify via accessToken (Web Google Identity Services Fallback)
      try {
        const response = await fetch('https://www.googleapis.com/oauth2/v3/userinfo', {
          headers: { Authorization: `Bearer ${googleAccessToken}` },
        });
        if (!response.ok) throw new Error('Failed to fetch user profile using access token');
        const payload = await response.json();
        googleId = payload.sub;
        email = payload.email;
        displayName = payload.name;
        avatarUrl = payload.picture;
      } catch (verifyErr) {
        console.error('Google accessToken verification failed:', verifyErr.message);
        return res.status(401).json({
          success: false,
          error: { code: 'INVALID_GOOGLE_TOKEN', message: 'Google token verification failed' },
        });
      }
    }

    // 2. Create or find user
    let user = await usersDb.findByGoogleId(googleId);
    let isNewUser = false;

    if (!user) {
      user = await usersDb.createUser(googleId, email, displayName, avatarUrl);
      isNewUser = true;
    } else {
      // Keep profile data fresh from Google
      await usersDb.updateGoogleProfile(user.id, displayName, avatarUrl);
      user.display_name = displayName;
      user.avatar_url = avatarUrl;
    }

    // 3. Generate JWT access token
    const accessToken = signAccessToken({
      sub: user.id,
      email: user.email,
      lang: user.language,
    });

    // 4. Generate refresh token & store hash in DB
    const rawRefreshToken = generateRefreshToken();
    const refreshTokenHash = hashToken(rawRefreshToken);

    await sessionsDb.createSession(
      user.id,
      refreshTokenHash,
      req.headers['user-agent'] || 'unknown',
      req.ip || ''
    );

    // 5. Set refresh token as httpOnly cookie
    setRefreshCookie(res, rawRefreshToken);

    // 6. Return tokens + is_new_user
    return res.status(200).json({
      success: true,
      data: {
        accessToken,
        refreshToken: rawRefreshToken,
        isNewUser,
        user: sanitizeUser(user),
      },
    });
  } catch (error) {
    console.error('Google Auth Error:', error);
    return res.status(500).json({
      success: false,
      error: { code: 'SERVER_ERROR', message: 'Authentication failed' },
    });
  }
};

// ---------------------------------------------------------------------------
// POST /api/auth/refresh
// ---------------------------------------------------------------------------
const refreshAccessToken = async (req, res) => {
  try {
    const token = req.cookies.refreshToken || req.body.refreshToken;

    if (!token) {
      return res.status(401).json({
        success: false,
        error: { code: 'NO_REFRESH_TOKEN', message: 'No refresh token provided' },
      });
    }

    const tokenHash = hashToken(token);
    const session = await sessionsDb.findSessionByHash(tokenHash);

    if (!session) {
      res.clearCookie('refreshToken', { path: '/api/auth' });
      return res.status(401).json({
        success: false,
        error: { code: 'INVALID_REFRESH_TOKEN', message: 'Invalid or expired session' },
      });
    }

    // Token rotation: delete old session, issue new refresh token
    await sessionsDb.deleteSessionByHash(tokenHash);

    const user = await usersDb.findById(session.user_id);
    if (!user) {
      res.clearCookie('refreshToken', { path: '/api/auth' });
      return res.status(401).json({
        success: false,
        error: { code: 'USER_NOT_FOUND', message: 'User no longer exists' },
      });
    }

    // Issue new access token
    const newAccessToken = signAccessToken({
      sub: user.id,
      email: user.email,
      lang: user.language,
    });

    // Issue new refresh token (rotation)
    const newRawRefresh = generateRefreshToken();
    const newRefreshHash = hashToken(newRawRefresh);

    await sessionsDb.createSession(
      user.id,
      newRefreshHash,
      req.headers['user-agent'] || 'unknown',
      req.ip || ''
    );

    setRefreshCookie(res, newRawRefresh);

    return res.status(200).json({
      success: true,
      data: { 
        accessToken: newAccessToken,
        refreshToken: newRawRefresh
      },
    });
  } catch (error) {
    console.error('Token Refresh Error:', error);
    return res.status(500).json({
      success: false,
      error: { code: 'SERVER_ERROR', message: 'Failed to refresh token' },
    });
  }
};

// ---------------------------------------------------------------------------
// POST /api/auth/logout
// ---------------------------------------------------------------------------
const logout = async (req, res) => {
  try {
    const token = req.cookies.refreshToken;

    if (token) {
      const tokenHash = hashToken(token);
      await sessionsDb.deleteSessionByHash(tokenHash);
    }

    res.clearCookie('refreshToken', {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'Strict',
      path: '/api/auth',
    });

    return res.status(200).json({
      success: true,
      message: 'Logged out successfully',
    });
  } catch (error) {
    console.error('Logout Error:', error);
    return res.status(500).json({
      success: false,
      error: { code: 'SERVER_ERROR', message: 'Failed to logout' },
    });
  }
};

module.exports = {
  googleLogin,
  refreshAccessToken,
  logout,
};
