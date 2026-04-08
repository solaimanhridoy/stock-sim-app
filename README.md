<div align="center">
  <h1>📈 Bangladesh Stock Market Sim</h1>
  <p>A full-stack, cross-platform stock market simulation application built with <strong>Flutter</strong> and <strong>Node.js</strong>.</p>

  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" />
  <img src="https://img.shields.io/badge/Node.js-339933?style=for-the-badge&logo=nodedotjs&logoColor=white" />
  <img src="https://img.shields.io/badge/Express.js-000000?style=for-the-badge&logo=express&logoColor=white" />
  <img src="https://img.shields.io/badge/PostgreSQL-316192?style=for-the-badge&logo=postgresql&logoColor=white" />
</div>

---

## 📖 About the Project

**Stock Sim** is a comprehensive educational and simulation platform designed for the Bangladesh Stock Market. It allows users to practice trading in a risk-free environment using real-time or simulated market data, track their portfolio performance, and learn market dynamics.

## 🚀 Current Project Status

**Overall MVP Progress:** `[██████████░░░░░░░░░░] 50%`

We are currently finishing the **Authentication and Setup Phase** and transitioning into the core **Market Data and Trading Logic**.

### ✅ Completed
- [x] **Monorepo Architecture Setup:** Flutter frontend and Node/Express backend.
- [x] **Database Initialization:** PostgreSQL schema and connection.
- [x] **Robust Authentication:** Secure Google Sign-In integrated with JWT and cross-platform support (Web & Mobile).
- [x] **UI Foundations:** Login screen, Profile Setup screen, and Animated UI Backgrounds.
- [x] **DevOps Basics:** Automated startup scripts (`run.bat` & `run.ps1`) to launch the entire stack instantly.
- [x] **Multi-stock Simulation Engine:** CSV Data integration with PostgreSQL.

### 🚧 Up Next
- [ ] **Stock Market Data Integration:** Fetching realistic stock symbols and prices.
- [ ] **User Portfolio Management:** Virtual wallets and transaction history.
- [ ] **Trading Engine:** Buy/Sell trade execution logic.
- [ ] **Live Price Updates:** WebSocket integration for real-time tickers.
- [ ] **Leaderboards:** Comparing portfolio gains globally.

---

## 🛠 Tech Stack

### Frontend (App/Web/Desktop)
- **Framework:** Flutter (Dart)
- **State Management:** Provider
- **Networking:** HTTP / Dio with Cookie Management
- **Auth Storage:** Flutter Secure Storage / Shared Preferences

### Backend (API Server)
- **Runtime:** Node.js
- **Framework:** Express.js
- **Database:** PostgreSQL (with `pg` module)
- **Security:** Helmet, Express Rate Limit, JWT, Google Auth Library

---

## 📁 Repository Structure

```text
stock-sim-app/
├── frontend/           # Flutter application complete with screens, widgets, and providers
│   ├── lib/            # Main Dart logic
│   └── pubspec.yaml    # Flutter dependencies
├── src/                # Node.js Express backend backend
│   ├── server.js       # Express app and route handling
│   └── db/             # Database queries and schema definitions
├── scripts/            # Database and automation utility scripts
├── .env                # Secret environment variables (ignored in Git)
├── package.json        # Backend dependencies
├── README_AUTH.md      # In-depth Google Auth Implementation docs
├── run.bat             # ⚡ One-click Windows startup script
└── run.ps1             # ⚡ Windows PowerShell startup script
```

## 🚗 How to Run Locally

Since this is a full-stack monorepo, both the frontend and backend need to be running. We've automated this process with a single script!

1. **Prerequisites Checklist:**
   - Flutter SDK installed.
   - Node.js installed.
   - PostgreSQL running locally (with connection details inside `.env`).

2. **Start the environment:**
   Simply double-click `run.bat` or use PowerShell:
   ```powershell
   ./run.ps1
   ```
   *This command will install necessary frontend/backend packages automatically and boot up both the API server and the Flutter development app.*

---
*Built with ❤️ for the future investors of Bangladesh.*
