const app = require('./app');
const sessionsDb = require('./db/sessions');

const PORT = process.env.PORT || 3000;

app.listen(PORT, () => {
  console.log(`✅ Auth API running → http://localhost:${PORT}`);
  console.log(`   Environment: ${process.env.NODE_ENV || 'development'}`);
});

// ---------------------------------------------------------------------------
// Periodic cleanup of expired sessions (every 6 hours)
// ---------------------------------------------------------------------------
const CLEANUP_INTERVAL = 6 * 60 * 60 * 1000;

const runCleanup = async () => {
  try {
    const count = await sessionsDb.cleanupExpired();
    if (count > 0) {
      console.log(`🧹 Cleaned up ${count} expired session(s)`);
    }
  } catch (err) {
    console.error('Session cleanup error:', err.message);
  }
};

setInterval(runCleanup, CLEANUP_INTERVAL);
// Run once on startup after a short delay
setTimeout(runCleanup, 5000);
