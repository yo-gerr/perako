# 💰 PeraKo

> **Your Personal Finance Operating System**

![Flutter](https://img.shields.io/badge/Flutter-3-02569B)
![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20Web-3DDC84)
![License](https://img.shields.io/badge/License-MIT-blue)

Perako OS is an Android + Web, ledger-based personal finance management application built with Flutter. Unlike traditional expense trackers, Perako OS is designed to become a complete financial operating system that manages every aspect of personal finance—from daily expenses and budgeting to savings, investments, automation, and long-term wealth tracking.

The application is intended for personal use and focuses on accuracy, transparency, and automation through a double-entry ledger accounting model.

---

# ✨ Features

Implemented today:

- **Double-entry ledger engine** — every financial event is a balanced ledger
  transaction (post / reverse / replace); balances are computed, never stored.
- **Accounts** — cash, wallets, checking, savings, time deposits, investments,
  MP2, bonds, credit cards, loans, and more; archive/reopen, custom color/icon,
  opening balances.
- **Transactions** — income, expense, and transfers with full edit (reverse +
  repost), notes, and a ledger-entry audit trail.
- **Categories** — hierarchical, with colors and icons; archive/reopen.
- **Dashboard** — net worth, cash flow, and recent transactions.
- **Budgets** — monthly/yearly, category or account scope, spending tracking,
  overrun forecast, rollover.
- **Bills** — recurring with due-date tracking; paying a bill posts a real
  ledger expense; reschedule and skip.
- **Goals** — savings/debt-payoff/investment with progress, completion
  forecast, and ledger-backed contributions.
- **Savings engine** — configurable interest rates, compounding, interest
  credit schedules, and balance forecasting.
- **Time deposits, MP2, and bonds** — maturity/coupon/dividend forecasting with
  generated ledger transactions.
- **Reports & analytics** — net worth over time, cash flow, category/income
  analysis, budget performance; CSV export.
- **Unified search** — across transactions, accounts, bills, notes, categories,
  and tags.
- **Auth & sync (optional)** — the app opens straight to the dashboard with no
  account required. Sign in from the sidebar, the More page, or Settings to
  enable additive Firestore sync/backup (SQLite remains the source of truth;
  the app works fully offline; sign-out keeps local data).
- **Perako Design System** — light/dark modes, neutral surfaces, semantic
  financial colors (green = income/growth, gold = attention/goals, magenta =
  investments), Manrope font, custom icon and color pickers.

---

# 🧰 Tech Stack

| Package | Purpose |
|---|---|
| Flutter / Dart | Framework (SDK `^3.12.2`) |
| `flutter_riverpod` | State management |
| `go_router` | Declarative navigation |
| `drift` / `drift_flutter` | SQLite ORM + native setup |
| `firebase_core` / `cloud_firestore` / `firebase_auth` | Firebase init, sync, auth |
| `shared_preferences` | Local settings |
| `fl_chart` | Charts |
| `font_awesome_flutter` | Icon library |
| `dropdown_button2` | Custom dropdowns |

---

# 🎨 Branding & Logo

PeraKo's identity is an abstract **P + coin** mark: a coin disc fused with the
letter P's stem, with a rising green tick at the foot that suggests financial
growth.

- **PeraKo Blue** `#008BF8` — primary brand color.
- **PeraKo Green** `#04E762` — growth accent; the app-icon tile is green with a
  white symbol.

The mark is defined once as vector geometry in
[`lib/core/branding/perako_logo.dart`](lib/core/branding/perako_logo.dart) and
is shared by the in-app widgets (`PerakoMark`, `PerakoLockup` — sidebar lockup,
rail monogram, login screen) and the offline icon generator, so the launcher
icons never drift from the UI.

To regenerate every platform icon (Android mipmaps, iOS/macOS AppIcon sets,
web PWA icons + favicon, Windows `.ico`) and the preview sheet:

```bash
flutter test tool/logo_renderer.dart
```

The preview sheet is written to `assets/branding/preview.png`.

---

# 🚀 Getting Started

**Prerequisites:** Flutter SDK (stable), and an Android device/emulator or
Chrome for web.

```bash
flutter pub get
flutter run          # pick an Android device/emulator or Chrome
```

> **Android note:** the app uses Firebase, and the Android build reads
> `android/app/google-services.json` from disk (it is git-ignored). Place your
> own file there first — see [`docs/FIREBASE_SETUP.md`](docs/FIREBASE_SETUP.md).

If you modify Drift tables or Riverpod/generated code:

```bash
dart run build_runner build --delete-conflicting-outputs
```

---

# ✅ Testing & Quality

```bash
flutter analyze
flutter test
```

The suite has **~55 test files and 268 tests**, covering the ledger engine,
DAOs, services (budgets, bills, goals, savings, MP2, bonds, sync), widget
tests for screens, and an end-to-end smoke test.

---

# 🗂 Project Structure

```
lib/
├── core/          # database (Drift), router/shell, theme, branding, auth, shared widgets
├── features/      # feature-first modules (data/ domain/ presentation/)
│   ├── accounts/  transactions/  categories/  budgets/  bills/  goals/
│   ├── savings/   time_deposits/  mp2/  bonds/  reports/  search/
│   └── auth/      sync/  settings/  dashboard/  ledger/  more/
├── firebase_options.dart
└── main.dart
assets/branding/   # brand preview sheet
tool/              # icon generator (flutter test tool/logo_renderer.dart)
test/              # unit, widget, and integration tests
docs/              # setup guides (Firebase)
```

---

# ✨ Vision

Perako OS aims to become a single source of truth for your financial life.

Instead of simply tracking expenses, it manages:

- 💵 Cash
- 🏦 Bank Accounts
- 💳 Digital Wallets
- 💰 Savings Accounts
- 📈 Investments
- 🏛 MP2 Savings
- 📃 Bonds
- 📆 Time Deposits
- 💳 Credit Cards
- 💸 Loans
- 🎯 Financial Goals
- 📊 Budgets
- 🤖 Financial Automation
- 📈 Net Worth
- 📅 Financial Calendar
- 📑 Financial Reports

---

# 🎯 Project Goals

- Build a complete Personal Finance Operating System
- Support Android and Web using Flutter
- Maintain a local-first architecture
- Implement a robust ledger-based accounting engine
- Automate repetitive financial tasks
- Provide meaningful financial insights instead of only recording transactions

---

# 🏛 Core Architecture

Perako OS is built around **Double-Entry Bookkeeping**.

Every financial event is recorded as balanced ledger entries.

Instead of storing balances directly:

```
Balance = Sum of all Ledger Entries
```

**Local-first storage.** The authoritative database is a local SQLite database (via Drift). All balances, reports, and forecasts are computed from the local ledger; the app works fully offline and never depends on the network.

**Cloud sync (additive).** Firebase **Cloud Firestore** acts as a sync and backup mirror only. It does not replace the local ledger — documents carry the same local IDs and the local database remains the single source of truth.

This ensures:

- Financial integrity
- Complete audit history
- Historical reporting
- Accurate net worth calculations
- Reliable automation

---

# 📜 License

PeraKo is open source under the **MIT License**. See [LICENSE](LICENSE).

# 🎨 Inspiration & Credits

PeraKo's UX and feature design draws inspiration from
[Cashew](https://github.com/jameskokoska/Cashew) (James Kokoska, **GPL v3**).
Cashew is used strictly as a design reference — all code in this repository is
PeraKo's own, reimplemented from scratch on a double-entry ledger architecture,
and no Cashew source code is incorporated.

---

# 🧩 Planned Features

## 👤 User Management

### User can

- Create and manage a personal profile
- Configure application preferences
- Set preferred currency
- Configure locale and date format
- Enable PIN or biometric authentication
- Export financial data
- Import backups
- Backup and restore the database
- Synchronize data across devices via Firebase Cloud Firestore (additive; SQLite remains source of truth)

### System should

- Securely store user data
- Encrypt sensitive information
- Automatically backup data (optional)
- Synchronize user preferences

---

## 🏠 Dashboard

### User can

- View Net Worth
- View Assets
- View Liabilities
- View Cash Flow
- View Savings
- View Investments
- View Income and Expenses
- Customize dashboard widgets
- Pin favorite accounts
- Filter dashboard data

### System should

- Calculate balances automatically
- Update dashboard after every transaction
- Display financial summaries
- Detect unusual spending
- Display upcoming bills
- Display upcoming interest credits
- Display upcoming dividends

---

## 💳 Accounts

Supported Account Types

- Cash
- Wallet
- Checking
- Savings
- Time Deposit
- Digital Wallet
- Investment
- MP2
- Bonds
- Credit Card
- Loan
- Mortgage
- Emergency Fund
- Business Account
- Foreign Currency
- Crypto (Optional)

### User can

- Create unlimited accounts
- Edit accounts
- Archive accounts
- Close accounts
- Reopen archived accounts
- Assign colors and icons
- Configure opening balances
- Configure opening dates
- Record balance adjustments

### System should

- Calculate balances from ledger entries
- Maintain account history
- Track balance changes
- Prevent invalid balances when configured

---

## 💸 Transactions

### User can

- Record income
- Record expenses
- Record transfers
- Record refunds
- Record reimbursements
- Record adjustments
- Split transactions
- Duplicate transactions
- Attach receipts
- Add notes
- Add tags
- Search transactions
- Filter transactions
- Bulk edit transactions

### System should

- Validate transaction integrity
- Maintain audit history
- Update reports automatically
- Recalculate balances instantly

---

## 🏷 Categories

### User can

- Create custom categories
- Create subcategories
- Edit categories
- Archive categories
- Assign colors
- Assign icons

### System should

- Track category spending
- Suggest categories based on previous transactions

---

## 📊 Budgeting

### User can

- Create monthly budgets
- Create yearly budgets
- Create category budgets
- Create account budgets
- Create envelope budgets
- Roll over unused budgets

### System should

- Track remaining budgets
- Forecast budget overruns
- Notify approaching budget limits

---

## 💰 Savings Management

### User can

- Create savings accounts
- Configure interest rates
- Configure compounding frequency
- Configure interest credit schedules
- Pause interest calculations
- Modify historical interest rates

### System should

- Calculate daily interest
- Calculate monthly interest
- Calculate annual interest
- Automatically generate interest transactions
- Update balances automatically
- Forecast future balances

---

## 📈 Investment Management

Supported Investments

- Stocks
- ETFs
- REITs
- Mutual Funds
- UITFs
- Bonds
- MP2
- Time Deposits
- Crypto (Optional)

### User can

- Record purchases
- Record sales
- Record dividends
- Record capital gains

### System should

- Calculate ROI
- Calculate cost basis
- Calculate realized gains
- Calculate unrealized gains
- Forecast investment value
- Generate dividend transactions

---

## 🏛 MP2 Management

### User can

- Register MP2 accounts
- Record contributions
- Record withdrawals
- Configure dividend rates

### System should

- Forecast maturity value
- Forecast annual dividends
- Generate dividend transactions
- Notify approaching maturity

---

## 📃 Bond Management

### User can

- Register bond investments
- Configure coupon schedules
- Configure coupon rates

### System should

- Generate coupon payments
- Forecast maturity value
- Notify maturity dates

---

## 🏦 Time Deposits

### User can

- Create time deposits
- Configure maturity dates
- Configure interest methods

### System should

- Calculate maturity value
- Generate maturity transactions
- Notify before maturity

---

## 🧾 Bills

### User can

- Create recurring bills
- Mark bills as paid
- Skip bills
- Reschedule bills

### System should

- Generate reminders
- Generate recurring transactions
- Notify overdue bills

---

## 💼 Income Tracking

### User can

- Record salary
- Record bonuses
- Record freelance income
- Record rental income
- Record commissions
- Record dividends
- Record cashback

### System should

- Categorize income
- Generate recurring income transactions

---

## 🎯 Financial Goals

### User can

- Create savings goals
- Create debt payoff goals
- Create investment goals
- Assign funding accounts

### System should

- Calculate goal progress
- Forecast completion
- Recommend contributions

---

## 📅 Financial Calendar

### User can

- View financial events
- Filter events
- Jump to specific dates

### System should display

- Salary
- Bills
- Interest credits
- Dividends
- Investment events
- Transfers
- Loan payments
- Maturity dates

---

## 📈 Reports & Analytics

### User can

- Generate reports
- Compare reporting periods
- Export PDF
- Export Excel
- Export CSV

### System should calculate

- Net Worth
- Cash Flow
- Spending Analysis
- Income Analysis
- Savings Growth
- Investment Growth
- Interest Earned
- Dividend Income
- Budget Performance

---

## 🔍 Search

### User can

- Search transactions
- Search accounts
- Search investments
- Search bills
- Search notes

### System should

- Support advanced filters
- Support date ranges
- Support tags

---

## 🔔 Notifications

### User can

- Configure reminders
- Snooze reminders
- Disable reminders

### System should notify

- Upcoming bills
- Salary
- Interest credits
- MP2 dividends
- Bond coupons
- Budget limits
- Goal milestones

---

# 🤖 Automation Engine

The Automation Engine is one of the defining features of Perako OS.

Instead of manually updating balances, the application generates ledger transactions based on configurable rules.

### User can

- Create automation rules
- Enable or disable rules
- Test automation rules
- Schedule automation
- Chain multiple actions
- Configure conditional rules
- Prioritize rule execution

### Example Automations

```
Every Payday
↓

Transfer ₱5,000

Payroll
↓

Emergency Fund
```

```
Daily

↓

Calculate Interest

↓

Generate Ledger Transaction
```

```
Balance > ₱50,000

↓

Transfer Excess

↓

MP2 Savings
```

### System should

- Execute scheduled automations
- Generate balanced ledger entries
- Calculate interest automatically
- Apply dividends
- Execute recurring transfers
- Process recurring bills
- Maintain execution logs
- Retry failed automations
- Prevent duplicate executions

---

# 📚 Ledger Engine

The Ledger Engine is the heart of Perako OS.

Every financial event becomes a balanced ledger transaction.

### User can

- View ledger entries
- Audit transaction history
- Reverse transactions
- View account history at any date

### System should

- Prevent unbalanced transactions
- Store every financial event as ledger entries
- Calculate balances only from ledger entries
- Maintain a complete audit trail
- Preserve historical financial integrity

---

# 🏗 Development Roadmap

## Phase 1

- Core Ledger Engine
- Accounts
- Transactions
- Dashboard
- Categories

## Phase 2

- Budgeting
- Bills
- Goals
- Reports
- Search

## Phase 3

- Savings Engine
- Automatic Interest
- MP2
- Time Deposits

## Phase 4

- Investments
- Bonds
- Dividend Tracking
- Portfolio Analytics

## Phase 5

- Automation Engine
- Forecasting
- Financial Calendar
- Cloud Synchronization

---

# 📜 Guiding Principles

Perako OS follows several non-negotiable principles:

1. Nothing changes an account balance except a ledger transaction.
2. Every financial event produces balanced ledger entries.
3. Automation never edits balances directly.
4. Balances are calculated, never manually stored.
5. Every change is fully traceable.
6. Historical records are immutable.
7. Reports, forecasts, and dashboards are always derived from the ledger.

---

# 🚀 Future Ideas

- AI-powered financial insights
- Receipt OCR
- Bank statement import
- Stock price synchronization
- Currency exchange tracking
- Shared family accounts
- Multi-user support
- Plugin architecture
- Custom automation scripting
- Financial health score
- What-if financial simulations
- Retirement planning
- Tax reporting
- Offline-first synchronization