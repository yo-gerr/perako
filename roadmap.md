# PeraKo — Build Roadmap

> **Living Document** — Check off items as you complete them.

---

## Contents

- [Prerequisites & Setup](#prerequisites--setup)
- [Phase 1: Foundation & Ledger Engine](#phase-1-foundation--ledger-engine)
- [Phase 2: Financial Management](#phase-2-financial-management)
- [Phase 3: Savings & Time-Based Instruments](#phase-3-savings--time-based-instruments)
- [Phase 4: Investments](#phase-4-investments)
- [Phase 5: Automation & Advanced Features](#phase-5-automation--advanced-features)
- [Appendix](#appendix)

---

## Prerequisites & Setup

### Tech Stack

| Package | Version | Purpose |
|---|---|---|
| `flutter_riverpod` | `^3.3.2` | State management |
| `riverpod_annotation` | `^3.3.2` | Riverpod code generation |
| `riverpod_generator` | `^3.3.2` | Riverpod code generation |
| `drift` | `^2.34.2` | SQLite ORM (runtime) |
| `drift_dev` | `^2.34.2` | Drift code generation |
| `sqlite3_flutter_libs` | latest | SQLite native libs |
| `go_router` | `^17.3.0` | Declarative routing |
| `freezed` | `^3.2.5` | Immutable data class generation |
| `freezed_annotation` | `^3.0.0` | Freezed annotations |
| `json_serializable` | latest | JSON serialization |
| `json_annotation` | latest | JSON annotations |
| `get_it` | latest | Service locator / DI |
| `build_runner` | latest | Code generation runner |
| `flutter_test` | (SDK) | Testing framework |
| `intl` | latest | Date/currency formatting |

### Steps

- [ ] **Initialize Git repo** — `git init` and create initial `.gitignore` (use Flutter template)
- [ ] **Add dependencies** — Add all packages above to `pubspec.yaml` and run `flutter pub get`
- [ ] **Configure `analysis_options.yaml`** — Add Freezed `invalid_annotation_target` ignore rule, enable strict linting
    ```yaml
    analyzer:
      errors:
        invalid_annotation_target: ignore
    ```
- [ ] **Create folder structure** — Set up the following directory layout:
    ```
    lib/
    ├── core/
    │   ├── di/              # get_it service locator setup
    │   ├── database/        # Drift AppDatabase, migrations
    │   ├── theme/           # App theme, colors, text styles
    │   ├── router/          # GoRouter configuration
    │   └── utils/           # Helpers, extensions, constants
    ├── features/
    │   ├── accounts/        # Accounts feature
    │   │   ├── data/        # DAOs, data sources
    │   │   ├── domain/      # Models, repos (freezed models)
    │   │   └── presentation/ # Providers, screens, widgets
    │   ├── transactions/    # Transactions feature
    │   │   ├── data/
    │   │   ├── domain/
    │   │   └── presentation/
    │   ├── categories/      # Categories feature
    │   │   ├── data/
    │   │   ├── domain/
    │   │   └── presentation/
    │   ├── dashboard/       # Dashboard feature
    │   │   └── presentation/
    │   ├── ledger/          # Ledger engine (core, no UI)
    │   │   ├── data/
    │   │   └── domain/
    │   ├── budgeting/       # Phase 2
    │   ├── bills/           # Phase 2
    │   ├── goals/           # Phase 2
    │   ├── reports/         # Phase 2
    │   ├── savings/         # Phase 3
    │   ├── time_deposits/   # Phase 3
    │   ├── mp2/             # Phase 3
    │   ├── bonds/           # Phase 3
    │   ├── investments/     # Phase 4
    │   └── automation/      # Phase 5
    ├── shared/
    │   └── widgets/         # Reusable widgets (buttons, cards, etc.)
    └── main.dart
    ```
- [ ] **Set up `get_it`** — Create `lib/core/di/service_locator.dart` with `GetIt` instance and registration methods for core services (database, ledger engine, etc.)
- [ ] **Set up GoRouter** — Create `lib/core/router/app_router.dart` with initial route table (shell route with bottom nav for Dashboard, Accounts, Transactions)
- [ ] **Create app theme** — `lib/core/theme/app_theme.dart` with light/dark `ThemeData`
- [ ] **Configure Drift build** — Ensure `build.yaml` at project root points drift builders to `lib/core/database/`
- [ ] **Run initial code generation** — `dart run build_runner build --delete-conflicting-outputs`
- [ ] **Verify app runs** — `flutter run` on the Android target

---

## Phase 1: Foundation & Ledger Engine

> Goal: Working app with accounts, transactions, categories, dashboard, and the double-entry ledger engine.

### 1.1 — Database Schema & Ledger Engine

- [x] **Create Drift database** — `lib/core/database/app_database.dart`
    - Define `AppDatabase` class extending `$AppDatabase`
    - Include all core tables (see below)
    - Configure `NativeDatabase` for Android (plus `DriftWebOptions` for web via `drift_flutter`)
- [x] **Define Drift tables** — Create table files in `lib/core/database/tables/`:
    - [x] `accounts_table.dart` — `id`, `name`, `type` (enum), `currency`, `color`, `icon`, `is_archived`, `opening_date`, `created_at`, `updated_at`
    - [x] `categories_table.dart` — `id`, `name`, `parent_id` (nullable, self-ref), `color`, `icon`, `is_archived`
    - [x] `transactions_table.dart` — `id`, `description`, `date`, `notes`, `receipt_path`, `created_at`, `updated_at`
    - [x] `ledger_entries_table.dart` — `id`, `transaction_id` (FK), `account_id` (FK), `category_id` (nullable FK), `amount` (integer, cents), `type` (debit/credit), `entry_date`, `created_at`
    - [x] `tags_table.dart` — `id`, `name`, `color`
    - [x] `transaction_tags_table.dart` — `transaction_id` (FK), `tag_id` (FK)
- [ ] **Create Freezed domain models** — `lib/features/ledger/domain/models/`:
    - [ ] `account.dart` — `Account` with `AccountType` enum
    - [ ] `transaction.dart` — `Transaction` with `TransactionType` enum (income, expense, transfer, refund, adjustment)
    - [ ] `ledger_entry.dart` — `LedgerEntry` with `EntryType` enum (debit, credit)
    - [ ] `category.dart` — `Category`, `CategoryType` enum (income, expense, transfer)
- [x] **Create Drift DAOs** — `lib/features/*/data/daos/`:
    - [x] `accounts_dao.dart` — CRUD, archive/reopen, balance query
    - [x] `transactions_dao.dart` — CRUD, filtering, search, date range queries
    - [x] `categories_dao.dart` — CRUD, tree query for subcategories
    - [x] `ledger_dao.dart` — Query by transaction, by account, by date range
- [x] **Build the Ledger Engine** — `lib/features/ledger/domain/ledger_engine.dart`:
    - [x] `LedgerEngine` class
    - [x] `postTransaction(...)` — Creates `Transaction` + balanced `LedgerEntry` pair(s)
    - [x] `reverseTransaction(...)` — Creates reversal entries keeping audit trail
    - [x] `replaceTransaction(...)` — Atomically reverses the original then posts the correction (edit flow)
    - [x] `getBalance(accountId, [asOfDate])` — Sums all entries for account
    - [x] `getNetWorth()` — Total assets minus total liabilities
    - [x] `validateTransaction(...)` — Ensures debits == credits before posting
- [x] **Write unit tests** — `test/features/ledger/`:
    - [x] Test balanced transaction posting
    - [x] Test unbalanced transaction rejection
    - [x] Test transaction reversal
    - [x] Test balance calculation

### 1.2 — Accounts Feature

- [x] **Create Riverpod providers** — `lib/features/accounts/presentation/providers/`:
    - [x] `accounts_provider.dart` — `StreamProvider<List<Account>>` from DAO
    - [x] `account_balance_provider.dart` — `FutureProvider.family<int, String>` by account ID
    - [ ] `account_form_provider.dart` — `Notifier` for create/edit form state
- [x] **Build account screens** — `lib/features/accounts/presentation/screens/`:
    - [x] `accounts_list_screen.dart` — List all accounts grouped by type (cards), with balance
    - [x] `account_detail_screen.dart` — Single account view with balance, transaction history
    - [x] `account_form_screen.dart` — Create/edit account form (name, type, color, icon, opening balance/date)
    - [x] `account_archive_dialog.dart` — Confirm archive/unarchive
- [x] **Wire up GoRouter** — Add `/accounts`, `/accounts/new`, `/accounts/:id`, `/accounts/:id/edit` routes

### 1.3 — Categories Feature

- [x] **Create Riverpod providers**:
    - [x] `categories_provider.dart` — `StreamProvider<List<Category>>`
    - [ ] `category_form_provider.dart` — Create/edit form state
- [x] **Build category screens**:
    - [x] `categories_list_screen.dart` — Tree/list with color indicators
    - [x] `category_form_screen.dart` — Create/edit name, parent, color, icon, type
- [x] **Wire up GoRouter** — Add `/categories`, `/categories/new`, `/categories/:id/edit` routes

### 1.4 — Transactions Feature

- [x] **Create Riverpod providers**:
    - [x] `transactions_provider.dart` — `StreamProvider` of enriched rows (signed amount, account/category names)
    - [ ] `transaction_form_provider.dart` — Form with split support
    - [ ] `transaction_search_provider.dart` — Search/filter state
- [x] **Build transaction screens**:
    - [x] `transactions_list_screen.dart` — Date-grouped list, swipe-to-archive, day headers
    - [x] `transaction_form_screen.dart` — Create/edit (reverse + repost) with type segmented control, account picker, category picker, amount, date, notes
    - [ ] `transaction_split_screen.dart` — Split transaction across categories
    - [x] `transaction_detail_screen.dart` — Full view with ledger entries, reversal, and edit
    - [ ] `receipt_attachment_widget.dart` — Image picker + attachment display
- [x] **Wire up GoRouter** — Add `/transactions`, `/transactions/new`, `/transactions/:id`, `/transactions/:id/edit` routes
- [x] **Archive & reopen** — Active/Archived filter toggle with restore on both account and category lists

### 1.5 — Dashboard

- [x] **Create providers**:
    - [x] `dashboard_provider.dart` — Aggregates net worth + per-account balances
    - [ ] `net_worth_provider.dart` — Historical net worth data points
- [x] **Build dashboard screen**:
    - [x] `dashboard_screen.dart` — Net worth card, cash flow card, recent transactions list, quick action FAB
    - [ ] `net_worth_chart.dart` — Sparkline or bar chart of net worth over time
    - [ ] `accounts_summary_card.dart` — Total assets / total liabilities with breakdown
    - [x] `cash_flow_card.dart` — Income vs expenses this month
    - [x] `recent_transactions_list.dart` — Last 5 transactions
- [x] **Wire up GoRouter** — Set `/` (home) to dashboard with `StatefulShellRoute`

### 1.6 — User Profile & App Settings

- [x] **Create profile table** — `profiles_table.dart` in Drift
- [x] **Create providers**:
    - [x] `profile_provider.dart` — Current user profile
    - [x] `settings_provider.dart` — Theme, currency, locale preferences
- [x] **Build screens**:
    - [x] `settings_screen.dart` — Currency, locale, date format, theme toggle
    - [x] `profile_screen.dart` — Name, preferences
    - [x] `security_screen.dart` — PIN/biometric enable/change
- [x] **Wire up GoRouter** — Add `/settings`, `/settings/profile`, `/settings/security` routes

### 1.7 — Navigation Shell

- [x] **Build bottom navigation shell** — `lib/core/router/home_shell.dart`:
    - [x] `HomeShell` widget with `StatefulShellRoute` for Dashboard, Accounts, Transactions tabs
    - [x] Tab state preservation across navigation
- [x] **Drawer navigation** — Side drawer for Categories and Sign out

### 1.8 — Phase 1 Testing & Polish

- [x] Write widget tests for the navigation shell (happy path)
- [x] Test ledger engine edge cases (zero amounts, large numbers, date boundaries)
- [x] Verify double-entry integrity — every transaction produces balanced entries
- [x] Smoke test: create account → post income → post expense → verify balance → verify net worth on dashboard
- [x] Test transaction edit (reverse + repost) at engine and form level
- [x] Test archive/reopen for accounts and categories (DAO + list UI)

---

## Phase 2: Financial Management

> Goal: Budgeting, bill tracking, financial goals, reports, and search.

### 2.1 — Budgeting

- [x] **Add Drift tables**:
    - [x] `budgets_table.dart` — `id`, `name`, `account_id` (nullable), `category_id` (nullable), `amount`, `period` (monthly/yearly), `start_date`, `end_date`, `rollover`
    - [x] ~~`budget_allocations_table.dart`~~ — Not built: envelope periods deferred by design decision
- [x] **Create models**:
    - [x] `budget.dart` — `Budget`, `BudgetPeriod` enum (drift data classes, not Freezed)
- [x] **Create DAO** — `budgets_dao.dart` with spending queries
- [x] **Build budget engine**:
    - [x] `BudgetService` — Calculate remaining, forecast overrun, track spending vs budget
- [x] **Create providers**:
    - [x] `budgets_provider.dart` — Active budgets list
    - [x] `budget_detail_provider.dart` — Single budget with spending breakdown
    - [x] `budget_form_provider.dart`
- [x] **Build screens**:
    - [x] `budgets_list_screen.dart` — Progress bars for each budget
    - [x] `budget_detail_screen.dart` — Spending breakdown, remaining, forecast
    - [x] `budget_form_screen.dart` — Create/edit with category/account picker
- [x] **Wire up GoRouter** — Add `/budgets` routes
- [x] **Write tests** — Budget calculation, rollover logic, overrun detection

### 2.2 — Bills & Recurring Transactions

- [x] **Add Drift tables**:
    - [x] `bills_table.dart` — `id`, `name`, `amount`, `account_id` (FK), `category_id` (FK), `frequency` (weekly/monthly/yearly), `day_of_month`, `next_due_date`, `is_active` (as soft-delete `deleted_at` archive, consistent with budgets)
    - [x] `bill_payments_table.dart` — Payment history linking each posting to its ledger transaction
    - [ ] ~~`recurring_transactions_table.dart`~~ — Deferred by design decision; bills cover the recurring-expense use case
- [x] **Create models**:
    - [x] `bill.dart` — `Bill`, `BillFrequency` enum (drift data classes, not Freezed)
- [x] **Create DAO** — `bills_dao.dart`
- [x] **Build bill engine**:
    - [x] `BillService` — Check due bills, mark paid (posts a ledger expense), reschedule, skip
    - [ ] ~~`RecurringTransactionService`~~ — Deferred with recurring templates
- [x] **Create providers**:
    - [x] `bills_provider.dart`
    - [x] `bill_detail_provider.dart` — Bill with payment history
- [x] **Build screens**:
    - [x] `bills_list_screen.dart` — Active bills with due date and status
    - [x] `bill_form_screen.dart`
    - [x] `bill_detail_screen.dart` — Payment history, next due, pay now
- [x] **Wire up GoRouter** — Add `/bills` routes

### 2.3 — Financial Goals

- [x] **Add Drift tables**:
    - [x] `goals_table.dart` — `id`, `name`, `type` (savings/debt_payoff/investment), `target_amount`, `current_amount`, `target_date`, `funding_account_id`, `is_completed`, `created_at` (as `goals` + ledger-backed `goal_contributions` history)
- [x] **Create models**:
    - [x] `goal.dart` — `Goal`, `GoalType` enum (drift data classes, not Freezed)
- [x] **Create DAO** — `goals_dao.dart`
- [x] **Build goal engine**:
    - [x] `GoalService` — Progress calculation, completion forecast, contribution recommendation (contributions post real ledger transfers)
- [x] **Create providers**:
    - [x] `goals_provider.dart`
    - [x] `goal_detail_provider.dart`
- [x] **Build screens**:
    - [x] `goals_list_screen.dart` — Progress circles/cards
    - [x] `goal_detail_screen.dart` — Progress chart, forecast, suggested monthly contribution
    - [x] `goal_form_screen.dart`
- [x] **Wire up GoRouter** — Add `/goals` routes

### 2.4 — Reports & Analytics

- [ ] **Create report service** — `lib/features/reports/domain/report_service.dart`:
    - [ ] Net worth over time (daily/weekly/monthly snapshots)
    - [ ] Cash flow report (income vs expenses by period)
    - [ ] Spending analysis by category (pie/bar)
    - [ ] Income analysis by source
    - [ ] Budget performance report
    - [ ] Savings growth report
    - [ ] Interest earned report
- [ ] **Create providers**:
    - [ ] `net_worth_report_provider.dart`
    - [ ] `cash_flow_provider.dart`
    - [ ] `spending_analysis_provider.dart`
    - [ ] `income_analysis_provider.dart`
- [ ] **Build screens**:
    - [ ] `reports_hub_screen.dart` — Report type picker
    - [ ] `net_worth_report_screen.dart` — Line chart with date range picker
    - [ ] `cash_flow_report_screen.dart` — Bar chart comparing periods
    - [ ] `spending_analysis_screen.dart` — Pie chart by category
    - [ ] `income_analysis_screen.dart`
    - [ ] `budget_performance_screen.dart`
    - [ ] `export_dialog.dart` — Export options (PDF, Excel, CSV)
- [ ] **Wire up GoRouter** — Add `/reports` and sub-routes

### 2.5 — Search

- [ ] **Create search engine**:
    - [ ] `SearchService` — Unified search across transactions, accounts, bills, notes, categories
- [ ] **Create provider**:
    - [ ] `search_provider.dart` — Debounced search, filters, date ranges, tags
- [ ] **Build screen**:
    - [ ] `search_screen.dart` — Search bar, filter chips, results grouped by type
- [ ] **Wire up GoRouter** — Add `/search` route

---

## Phase 3: Savings & Time-Based Instruments

> Goal: Interest calculation engine, time deposits, MP2, and bonds.

### 3.1 — Savings Engine

- [ ] **Add Drift table**:
    - [ ] `savings_accounts_table.dart` — `account_id` (FK), `interest_rate`, `compounding_frequency` (daily/monthly/annually), `interest_credit_schedule`, `is_paused`
    - [ ] `interest_schedule_table.dart` — Planned interest credit dates
- [ ] **Create Freezed models**:
    - [ ] `savings_account.dart` — `SavingsAccount`, `CompoundingFrequency` enum
- [ ] **Build savings engine**:
    - [ ] `SavingsInterestService` — Daily interest calc, compounding logic, generate interest transactions
    - [ ] `SavingsForecastService` — Future balance projection
- [ ] **Create providers**:
    - [ ] `savings_accounts_provider.dart`
    - [ ] `savings_forecast_provider.dart`
- [ ] **Build screens**:
    - [ ] `savings_detail_screen.dart` — Interest rate display, forecast chart, interest credit history
    - [ ] `savings_settings_screen.dart` — Rate, compounding, schedule configuration
- [ ] **Wire up GoRouter** — Extend account routes for savings detail

### 3.2 — Time Deposits

- [ ] **Add Drift table**:
    - [ ] `time_deposits_table.dart` — `account_id` (FK), `principal`, `interest_rate`, `interest_method`, `start_date`, `maturity_date`, `maturity_value`, `is_matured`
- [ ] **Create Freezed models**:
    - [ ] `time_deposit.dart` — `TimeDeposit`, `InterestMethod` enum
- [ ] **Build engine**:
    - [ ] `TimeDepositService` — Maturity value calculation, maturity notification, auto-generate maturity transaction
- [ ] **Create providers**:
    - [ ] `time_deposits_provider.dart`
- [ ] **Build screens**:
    - [ ] `time_deposits_list_screen.dart`
    - [ ] `time_deposit_form_screen.dart`
    - [ ] `time_deposit_detail_screen.dart` — Countdown to maturity, interest earned
- [ ] **Wire up GoRouter** — Add `/time-deposits` routes

### 3.3 — MP2 Management

- [ ] **Add Drift table**:
    - [ ] `mp2_accounts_table.dart` — `account_id` (FK), `dividend_rate`, `start_date`, `maturity_date` (5 years), `is_matured`
    - [ ] `mp2_contributions_table.dart` — `mp2_account_id`, `amount`, `date`
    - [ ] `mp2_withdrawals_table.dart` — `mp2_account_id`, `amount`, `date`
- [ ] **Create Freezed models**:
    - [ ] `mp2_account.dart` — `MP2Account`
- [ ] **Build engine**:
    - [ ] `MP2Service` — Forecast maturity value, forecast annual dividends, generate dividend transactions
- [ ] **Create providers**:
    - [ ] `mp2_accounts_provider.dart`
- [ ] **Build screens**:
    - [ ] `mp2_list_screen.dart`
    - [ ] `mp2_detail_screen.dart` — Contribution history, dividend forecast, maturity countdown
    - [ ] `mp2_form_screen.dart`
- [ ] **Wire up GoRouter** — Add `/mp2` routes

### 3.4 — Bonds

- [ ] **Add Drift table**:
    - [ ] `bonds_table.dart` — `account_id` (FK), `face_value`, `coupon_rate`, `coupon_schedule` (monthly/quarterly/semi-annual/annual), `next_coupon_date`, `maturity_date`, `is_matured`
- [ ] **Create Freezed models**:
    - [ ] `bond.dart` — `Bond`, `CouponSchedule` enum
- [ ] **Build engine**:
    - [ ] `BondService` — Generate coupon payment transactions, forecast maturity value, notify maturity
- [ ] **Create providers**:
    - [ ] `bonds_provider.dart`
- [ ] **Build screens**:
    - [ ] `bonds_list_screen.dart`
    - [ ] `bond_form_screen.dart`
    - [ ] `bond_detail_screen.dart` — Coupon history, next payment, yield
- [ ] **Wire up GoRouter** — Add `/bonds` routes

---

## Phase 4: Investments

> Goal: Track stock/ETF/mutual fund investments with portfolio analytics.

### 4.1 — Investment Accounts

- [ ] **Add Drift tables**:
    - [ ] `investment_accounts_table.dart` — `account_id` (FK), `broker`, `account_number`
    - [ ] `holdings_table.dart` — `id`, `investment_account_id`, `ticker`, `name`, `asset_type` (stock/etf/reit/mutual_fund/uitf), `currency`, `notes`
    - [ ] `investment_transactions_table.dart` — `id`, `holding_id` (FK), `type` (buy/sell/dividend), `shares`, `price_per_share`, `total_amount`, `commission`, `date`, `notes`
- [ ] **Create Freezed models**:
    - [ ] `holding.dart` — `Holding`, `AssetType` enum
    - [ ] `investment_transaction.dart` — `InvestmentTransaction`, `TradeType` enum

### 4.2 — Portfolio Engine

- [ ] **Build portfolio service**:
    - [ ] `PortfolioService` — Calculate cost basis, realized gains, unrealized gains, ROI
    - [ ] `DividendService` — Track dividends by holding, generate income transactions
    - [ ] `InvestmentForecastService` — Project future value
- [ ] **Create providers**:
    - [ ] `portfolio_provider.dart` — All holdings with current value and gain/loss
    - [ ] `holding_detail_provider.dart` — Single holding with transaction history
    - [ ] `portfolio_performance_provider.dart` — ROI and gain/loss over time
- [ ] **Build screens**:
    - [ ] `portfolio_screen.dart` — Holdings list with value, gain/loss, allocation pie
    - [ ] `holding_detail_screen.dart` — Price chart, transaction log, dividend history, ROI
    - [ ] `trade_form_screen.dart` — Buy/sell entry
    - [ ] `dividend_form_screen.dart` — Record dividend received
    - [ ] `portfolio_report_screen.dart` — Performance reports, realized vs unrealized
- [ ] **Wire up GoRouter** — Add `/investments`, `/investments/:ticker` routes

---

## Phase 5: Automation & Advanced Features

> Goal: Automation engine, financial calendar, forecasting, and cloud sync.

### 5.1 — Automation Engine

- [ ] **Add Drift tables**:
    - [ ] `automation_rules_table.dart` — `id`, `name`, `description`, `trigger_type` (schedule/balance_condition/event), `trigger_config` (JSON), `is_enabled`, `priority`, `created_at`
    - [ ] `automation_actions_table.dart` — `id`, `rule_id` (FK), `action_type` (transfer/calculate_interest/generate_dividend/pay_bill), `action_config` (JSON), `order`
    - [ ] `automation_logs_table.dart` — `id`, `rule_id`, `status` (success/failed/skipped), `message`, `executed_at`
- [ ] **Create Freezed models**:
    - [ ] `automation_rule.dart` — `AutomationRule`, `TriggerType` enum
    - [ ] `automation_action.dart` — `AutomationAction`, `ActionType` enum
- [ ] **Build automation engine**:
    - [ ] `AutomationEngine` — Rule evaluator, action executor, scheduler
    - [ ] `RuleScheduler` — Cron-like scheduling for time-based rules
    - [ ] `ConditionEvaluator` — Evaluate balance conditions (e.g., "balance > 50000")
    - [ ] `ActionExecutor` — Execute transfer, interest calc, bill pay, etc.
    - [ ] `DeduplicationGuard` — Prevent duplicate rule execution
    - [ ] `RetryService` — Retry failed automations with backoff
- [ ] **Create providers**:
    - [ ] `automation_rules_provider.dart`
    - [ ] `automation_logs_provider.dart`
    - [ ] `automation_test_provider.dart` — Dry-run rules for testing
- [ ] **Build screens**:
    - [ ] `automation_list_screen.dart` — Rules with enable/disable toggle, last run status
    - [ ] `automation_form_screen.dart` — Visual rule builder (trigger + action chain)
    - [ ] `automation_log_screen.dart` — Execution history with status
    - [ ] `automation_test_screen.dart` — Simulate rule execution (no side effects)
- [ ] **Wire up GoRouter** — Add `/automation` routes
- [ ] **Write tests**:
    - [ ] Test rule evaluation with mock conditions
    - [ ] Test action execution and ledger balancing
    - [ ] Test deduplication
    - [ ] Test schedule-based triggers

### 5.2 — Financial Calendar

- [ ] **Create calendar service**:
    - [ ] `FinancialCalendarService` — Aggregate all dated events: bills, salary, interest credits, dividends, maturity dates, budget periods, goal milestones
- [ ] **Create provider**:
    - [ ] `financial_calendar_provider.dart` — Events for selected month filtered by type
- [ ] **Build screens**:
    - [ ] `financial_calendar_screen.dart` — Month view with event dots, tap to expand
    - [ ] `event_detail_sheet.dart` — Bottom sheet showing event details
    - [ ] `calendar_filter_bar.dart` — Filter by event type
- [ ] **Wire up GoRouter** — Add `/calendar` route

### 5.3 — Forecasting

- [ ] **Build forecasting service**:
    - [ ] `ForecastService` — Project future balances based on recurring transactions, budgets, goals, savings interest
    - [ ] `WhatIfSimulation` — "What if I save X more per month?" scenario runner
- [ ] **Create providers**:
    - [ ] `balance_forecast_provider.dart` — Expected balance at future dates
    - [ ] `goal_forecast_provider.dart` — Completion date projections
- [ ] **Build screens**:
    - [ ] `forecast_screen.dart` — Line chart of projected net worth
    - [ ] `what_if_screen.dart` — Adjust parameters, see impact on forecast

### 5.4 — Notifications & Reminders

- [ ] **Create notification service**:
    - [ ] `NotificationService` — Schedule local notifications for bills, interest, dividends, budget limits, goal milestones
- [ ] **Create provider**:
    - [ ] `notifications_provider.dart` — Configure which notifications to receive
- [ ] **Build screens**:
    - [ ] `notifications_settings_screen.dart` — Toggle each notification type
- [ ] **Wire up GoRouter** — Add `/settings/notifications`

### 5.5 — Data Export & Import

- [ ] **Build export service**:
    - [ ] `ExportService` — Export to CSV, Excel (using `excel` package), PDF (using `pdf` package)
- [ ] **Build import service**:
    - [ ] `ImportService` — Import from CSV, JSON backup
    - [ ] Validate import data integrity before committing to database
- [ ] **Build backup service**:
    - [ ] `BackupService` — Full database backup/restore, encryption option, auto-backup schedule
- [ ] **Create providers**:
    - [ ] `export_provider.dart`
    - [ ] `import_provider.dart`
    - [ ] `backup_provider.dart`

### 5.6 — Cloud Synchronization (via Firebase Cloud Firestore)

> **Additive layer.** Firestore is a sync/backup mirror only — SQLite remains the authoritative source of truth and the app works fully offline.

- [ ] **Add sync metadata to tables** — `last_synced_at`, `sync_version` columns
- [ ] **Design sync protocol** — Last-write-wins on `updated_at`; document IDs reuse local IDs
- [ ] **Build sync service**:
    - [ ] `SyncService` — Push/pull changesets, resolve conflicts
    - [ ] `DeduplicationGuard` — Ignore own-write echoes to prevent sync loops
    - [ ] CLIENTS — Firestore collections mirror local tables (accounts, transactions, ledger entries, etc.)
- [ ] **Build sync UI**:
    - [ ] Sync status indicator in settings
    - [ ] Manual sync button
    - [ ] Account linking screen

---

## Appendix

### Coding Conventions

- **File naming**: `snake_case.dart` — match class name to file name
- **Folder structure**: Feature-first (`features/<name>/data/`, `domain/`, `presentation/`)
- **State management**: Riverpod `@riverpod` annotation with code generation; avoid manual `Provider` declarations
- **DI pattern**: Use `get_it` for singleton services (database, ledger engine, automation engine); use Riverpod for reactive/derived state
- **Models**: All data models use `@freezed` with `json_serializable`
- **Database**: Drift DAOs encapsulate all SQL queries; never write raw SQL outside DAOs
- **Naming conventions**:
    - Providers: `accountsProvider`, `accountBalanceProvider(id)`
    - Screens: `AccountsListScreen`, `AccountFormScreen`
    - Services: `LedgerEngine`, `AutomationEngine`
    - DAOs: `AccountsDao`, `TransactionsDao`
- **Error handling**: Use `Result<T>` pattern (or sealed class) for service operations instead of throwing
- **Money values**: Store as integer (cents) in database; use `int` type; format for display only
- **Dates**: Store as UTC epoch milliseconds (`int`) in database; convert to local `DateTime` for display

### Testing Strategy

- **Unit tests**: All services and engines (ledger, automation, savings, etc.) — mock DAOs
- **Widget tests**: All screens — mock providers using `ProviderContainer` overrides
- **Integration tests**: Critical user flows (create account → post transaction → verify dashboard)
- **Drift-specific**: Use `NativeDatabase.memory()` for test databases; migrate schema in each test setUp
- **Target coverage**: 80%+ for domain logic, 60%+ for UI

### Common `build.yaml` Configuration

```yaml
targets:
  $default:
    builders:
      drift_dev:
        options:
          generate_apply_converters_on_variables: true
      json_serializable:
        options:
          explicit_to_json: true
          include_if_null: false
```

### Code Generation Commands

```bash
# One-time build
dart run build_runner build --delete-conflicting-outputs

# Watch mode (auto-regenerate on changes)
dart run build_runner watch --delete-conflicting-outputs
```

### Local-First Principles

1. The app must work fully offline. All data lives on-device in SQLite.
2. Cloud sync (Phase 5.6) is additive — the app never depends on network.
3. Encryption of sensitive data at rest (PIN hashes, biometric keys).
4. Auto-backup to device-local storage, optionally to cloud.

---

*Last updated: August 2026*
