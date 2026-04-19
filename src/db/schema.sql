-- ============================================================
-- Google Auth API — Database Schema
-- Run: psql $DATABASE_URL -f src/db/schema.sql
-- ============================================================

DROP TABLE IF EXISTS sessions CASCADE;
DROP TABLE IF EXISTS users CASCADE;

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ======================
-- Users
-- ======================
CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    google_id       VARCHAR(255) UNIQUE NOT NULL,
    email           VARCHAR(255) UNIQUE NOT NULL,
    display_name    VARCHAR(100) NOT NULL,
    avatar_url      TEXT,
    language        VARCHAR(2)  DEFAULT NULL CHECK (language IN ('bn', 'en')),
    experience      VARCHAR(20) DEFAULT NULL CHECK (experience IN ('beginner', 'intermediate')),
    virtual_balance DECIMAL(12,2) NOT NULL DEFAULT 100000.00,
    simulation_date DATE DEFAULT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_users_google_id ON users(google_id);
CREATE INDEX idx_users_email     ON users(email);

-- ======================
-- Sessions (refresh tokens)
-- ======================
CREATE TABLE sessions (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    refresh_token_hash  VARCHAR(128) UNIQUE NOT NULL,
    user_agent          TEXT,
    ip_address          VARCHAR(45),
    expires_at          TIMESTAMPTZ NOT NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_sessions_token_hash ON sessions(refresh_token_hash);
CREATE INDEX idx_sessions_user_id    ON sessions(user_id);
CREATE INDEX idx_sessions_expires_at ON sessions(expires_at);

-- ======================
-- Cleanup helper: delete expired sessions
-- Can be called via pg_cron or app-level scheduler
-- ======================
CREATE OR REPLACE FUNCTION cleanup_expired_sessions()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM sessions WHERE expires_at < NOW();
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- ======================
-- Stock Master
-- ======================
CREATE TABLE stocks (
    ticker          VARCHAR(20) PRIMARY KEY,
    company_name    VARCHAR(255),
    sector          VARCHAR(100),
    is_active       BOOLEAN DEFAULT TRUE
);

-- ======================
-- Market Prices (Historical & Current)
-- ======================
CREATE TABLE prices (
    id          SERIAL PRIMARY KEY,
    date        DATE NOT NULL,
    ticker      VARCHAR(20) NOT NULL REFERENCES stocks(ticker) ON DELETE CASCADE,
    open        DECIMAL(12,2) NOT NULL,
    high        DECIMAL(12,2) NOT NULL,
    low         DECIMAL(12,2) NOT NULL,
    close       DECIMAL(12,2) NOT NULL,
    volume      BIGINT NOT NULL,
    UNIQUE(date, ticker)
);

CREATE INDEX idx_prices_date_ticker ON prices(date, ticker);
CREATE INDEX idx_prices_ticker ON prices(ticker);

-- ======================
-- Portfolio and Transactions
-- ======================
CREATE TABLE portfolios (
    id          SERIAL PRIMARY KEY,
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    ticker      VARCHAR(20) NOT NULL REFERENCES stocks(ticker),
    quantity    INTEGER NOT NULL DEFAULT 0,
    avg_price   DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    UNIQUE(user_id, ticker)
);

CREATE TABLE transactions (
    id          SERIAL PRIMARY KEY,
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    date        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ticker      VARCHAR(20) NOT NULL REFERENCES stocks(ticker),
    action      VARCHAR(10) NOT NULL CHECK (action IN ('BUY', 'SELL')),
    price       DECIMAL(12,2) NOT NULL,
    quantity    INTEGER NOT NULL,
    total_value DECIMAL(12,2) NOT NULL
);
