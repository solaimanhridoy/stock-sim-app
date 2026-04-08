# Google Authentication API

Production-safe MVP backend for Google Sign-In with JWT-based session management.

## Architecture

```
POST /api/auth/google
  ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
  │  Frontend    │────▶│  Auth API    │────▶│  PostgreSQL  │
  │  (ID Token)  │◀────│  (Express)   │◀────│  (users +    │
  └──────────────┘     └──────────────┘     │   sessions)  │
                              │              └──────────────┘
                     ┌────────┴────────┐
                     │  Google OAuth   │
                     │  (token verify) │
                     └─────────────────┘
```

## Features

- **Google ID Token verification** via `google-auth-library`
- **Auto user creation** on first login (100,000 virtual balance)
- **JWT access tokens** (short-lived, 15m default)
- **Refresh token rotation** — old session deleted on each refresh, new one issued
- **Secure cookie storage** — httpOnly, Secure, SameSite=Strict
- **Hashed refresh tokens** — only SHA-256 hashes stored in DB
- **Rate limiting** — 20 auth requests / 15min, 100 global / 15min
- **Helmet** security headers
- **Automatic session cleanup** — expired sessions purged every 6 hours
- **Google profile sync** — display name & avatar updated on every login

## Tech Stack

| Component     | Technology                  |
|---------------|-----------------------------|
| Runtime       | Node.js (v18+)              |
| Framework     | Express 5                   |
| Database      | PostgreSQL                  |
| Auth          | Google OAuth 2.0 + JWT      |
| Security      | Helmet, express-rate-limit  |

## Quick Start

### 1. Prerequisites

- Node.js LTS (v18+)
- PostgreSQL running locally
- Google OAuth Client ID from [Google Cloud Console](https://console.cloud.google.com/apis/credentials)

### 2. Configure Environment

Copy and edit `.env`:

```env
PORT=3000
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/stock_sim
GOOGLE_CLIENT_ID=<your-google-client-id>
JWT_SECRET=<generate-a-strong-256-bit-secret>
JWT_ACCESS_EXPIRY=15m
JWT_REFRESH_EXPIRY=30d
CORS_ORIGIN=http://localhost:3001
NODE_ENV=development
```

> ⚠️ Generate a real JWT secret: `node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"`

### 3. Initialize Database

```bash
psql $DATABASE_URL -f src/db/schema.sql
```

### 4. Install & Run

```bash
npm install
npm run dev     # development (nodemon)
npm start       # production
```

## API Endpoints

### `POST /api/auth/google`

Verify Google ID token, create or find user, return JWT tokens.

**Request:**
```json
{
  "idToken": "<google-id-token-from-frontend>"
}
```

**Response (200):**
```json
{
  "success": true,
  "data": {
    "accessToken": "eyJhbGci...",
    "isNewUser": true,
    "user": {
      "id": "uuid",
      "displayName": "John Doe",
      "email": "john@gmail.com",
      "avatarUrl": "https://...",
      "language": null,
      "experience": null,
      "virtualBalance": 100000.00
    }
  }
}
```

> Refresh token is set as an httpOnly cookie (`refreshToken`).

### `POST /api/auth/refresh`

Exchange refresh token cookie for a new access token. Uses **token rotation** (old session deleted, new one created).

**Response (200):**
```json
{
  "success": true,
  "data": {
    "accessToken": "eyJhbGci..."
  }
}
```

### `POST /api/auth/logout`

Requires `Authorization: Bearer <accessToken>`. Destroys session and clears cookie.

**Response (200):**
```json
{
  "success": true,
  "message": "Logged out successfully"
}
```

### `GET /api/user/profile`

Requires `Authorization: Bearer <accessToken>`.

### `PATCH /api/user/profile`

Requires `Authorization: Bearer <accessToken>`.

```json
{
  "language": "en",
  "experience": "beginner"
}
```

## Project Structure

```
src/
├── app.js                  # Express app setup + middleware
├── server.js               # HTTP server + session cleanup scheduler
├── controllers/
│   ├── authController.js   # Google login, refresh, logout
│   └── userController.js   # Profile get/update
├── db/
│   ├── client.js           # PostgreSQL pool
│   ├── schema.sql          # Database DDL
│   ├── sessions.js         # Session CRUD
│   └── users.js            # User CRUD
├── routes/
│   ├── auth.js             # Auth routes
│   └── user.js             # User routes
└── utils/
    ├── jwt.js              # JWT sign/verify
    ├── middleware.js        # Auth middleware
    └── tokens.js           # Refresh token generation + hashing
```

## Error Response Format

All errors follow a consistent structure:

```json
{
  "success": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable description"
  }
}
```

| Code                    | HTTP | Description                        |
|-------------------------|------|------------------------------------|
| `MISSING_TOKEN`         | 400  | No idToken in request body         |
| `INVALID_GOOGLE_TOKEN`  | 401  | Google token verification failed   |
| `NO_TOKEN`              | 401  | No Authorization header            |
| `TOKEN_EXPIRED`         | 401  | Access token expired               |
| `INVALID_TOKEN`         | 401  | Malformed access token             |
| `NO_REFRESH_TOKEN`      | 401  | No refresh token cookie            |
| `INVALID_REFRESH_TOKEN` | 401  | Refresh token invalid or expired   |
| `INVALID_FIELD`         | 400  | Bad value for language/experience  |
| `NOT_FOUND`             | 404  | User or route not found            |
| `RATE_LIMIT`            | 429  | Too many requests                  |
| `SERVER_ERROR`          | 500  | Unexpected server error            |
