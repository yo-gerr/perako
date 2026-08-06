import 'package:drift/drift.dart';

class Accounts extends Table {
  /// Stable shared id (UUID). Also used as the Firestore document id.
  TextColumn get id => text()();

  TextColumn get name => text()();

  /// Account type, e.g. cash, wallet, checking, savings, investment, credit_card, loan.
  TextColumn get type => text()();

  TextColumn get currency => text()();

  TextColumn get color => text()();

  TextColumn get icon => text()();

  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  IntColumn get openingDate => integer()();

  IntColumn get updatedAt => integer()();

  IntColumn get deletedAt => integer().nullable()();

  IntColumn get version => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Categories extends Table {
  TextColumn get id => text()();

  TextColumn get name => text()();

  TextColumn get parentId => text().nullable()();

  // income | expense | transfer
  TextColumn get type => text()();

  TextColumn get color => text()();

  TextColumn get icon => text()();

  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  IntColumn get updatedAt => integer()();

  IntColumn get deletedAt => integer().nullable()();

  IntColumn get version => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Transactions extends Table {
  TextColumn get id => text()();

  TextColumn get description => text()();

  IntColumn get date => integer()();

  TextColumn get notes => text().nullable()();

  TextColumn get receiptPath => text().nullable()();

  IntColumn get updatedAt => integer()();

  IntColumn get deletedAt => integer().nullable()();

  IntColumn get version => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class LedgerEntries extends Table {
  TextColumn get id => text()();

  TextColumn get transactionId => text().references(Transactions, #id)();

  TextColumn get accountId => text().references(Accounts, #id)();

  TextColumn get categoryId => text().references(Categories, #id).nullable()();

  // Amount in integer cents. Always positive; direction is encoded by [type].
  IntColumn get amount => integer()();

  // debit | credit
  TextColumn get type => text()();

  IntColumn get entryDate => integer()();

  IntColumn get updatedAt => integer()();

  IntColumn get deletedAt => integer().nullable()();

  IntColumn get version => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Tags extends Table {
  TextColumn get id => text()();

  TextColumn get name => text()();

  TextColumn get color => text()();

  IntColumn get updatedAt => integer()();

  IntColumn get deletedAt => integer().nullable()();

  IntColumn get version => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class TransactionTags extends Table {
  TextColumn get transactionId => text().references(Transactions, #id)();

  TextColumn get tagId => text().references(Tags, #id)();

  @override
  Set<Column<Object>> get primaryKey => {transactionId, tagId};
}

/// Persists per-collection sync cursors (surrogate key = collection name).
///
/// The cursor is the highest `updatedAt` already processed for a given
/// collection, so pushes and pulls can be incremental.
class SyncState extends Table {
  TextColumn get collection => text()();

  IntColumn get lastSyncedAt => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {collection};
}

/// A user's profile, keyed by Firebase uid.
///
/// Settings that affect the whole device (theme, currency) live in
/// shared_preferences; this table holds per-user identity and preferences.
class Profiles extends Table {
  TextColumn get uid => text()();

  TextColumn get displayName => text()();

  /// ISO currency code, e.g. PHP, USD. Defaults to PHP.
  TextColumn get currency => text().withDefault(const Constant('PHP'))();

  /// BCP-47 locale tag, e.g. en-PH. Nullable until locale support ships.
  TextColumn get locale => text().nullable()();

  /// Preferred date format key. Nullable until date-format support ships.
  TextColumn get dateFormat => text().nullable()();

  IntColumn get createdAt => integer()();

  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {uid};
}

/// A spending limit for a category over a period.
///
/// - [period] is `monthly` or `yearly` (calendar windows). Envelope periods
///   are a later iteration.
/// - [amountCents] is the budgeted amount in integer cents.
/// - [rollover] carries a positive prior-period remainder into the current
///   period's available amount.
/// - [categoryId] scopes the budget to one category (exact match); when null,
///   [accountId] scopes it to one account's spending.
class Budgets extends Table {
  TextColumn get id => text()();

  TextColumn get name => text()();

  /// When set, limits spending to a single account.
  TextColumn get accountId => text().nullable()();

  /// When set, limits spending to a single category (exact match).
  TextColumn get categoryId => text().nullable()();

  IntColumn get amountCents => integer()();

  // monthly | yearly
  TextColumn get period => text()();

  IntColumn get startDate => integer().nullable()();

  IntColumn get endDate => integer().nullable()();

  BoolColumn get rollover => boolean().withDefault(const Constant(false))();

  IntColumn get createdAt => integer()();

  IntColumn get updatedAt => integer()();

  IntColumn get deletedAt => integer().nullable()();

  IntColumn get version => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Per-category spending limits inside a [Budgets] row.
class CategoryBudgetLimits extends Table {
  TextColumn get id => text()();

  TextColumn get budgetId => text().references(Budgets, #id)();

  TextColumn get categoryId => text().references(Categories, #id)();

  IntColumn get amountCents => integer()();

  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// A recurring bill that is materialized as an expense whenever its due date
/// arrives.
///
/// - [frequency] is `weekly`, `monthly`, or `yearly`.
/// - [dayOfMonth] anchors monthly/yearly recurrence (e.g. pay rent on the 5th)
///   and is clamped to the last day of shorter months.
/// - [nextDueDate] is the next scheduled posting date; the bill engine advances
///   it after each payment.
class Bills extends Table {
  TextColumn get id => text()();

  TextColumn get name => text()();

  /// The account credited when the bill is paid. Required for posting.
  TextColumn get accountId => text().references(Accounts, #id)();

  /// Optional category applied to the generated expense.
  TextColumn get categoryId => text().references(Categories, #id).nullable()();

  IntColumn get amountCents => integer()();

  // weekly | monthly | yearly
  TextColumn get frequency => text()();

  IntColumn get dayOfMonth => integer().nullable()();

  IntColumn get nextDueDate => integer()();

  IntColumn get createdAt => integer()();

  IntColumn get updatedAt => integer()();

  IntColumn get deletedAt => integer().nullable()();

  IntColumn get version => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// A ledger-backed payment against a [Bills] row.
///
/// Every payment posts a balanced expense through the ledger; [transactionId]
/// keeps the audit trail pointing at that posting so payment history can be
/// reconciled with the transactions list.
class BillPayments extends Table {
  TextColumn get id => text()();

  TextColumn get billId => text().references(Bills, #id)();

  TextColumn get transactionId => text().references(Transactions, #id)();

  IntColumn get amountCents => integer()();

  IntColumn get paidOn => integer()();

  TextColumn get note => text().nullable()();

  IntColumn get createdAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// A savings, debt-payoff, or investment target.
///
/// - [type] is `savings`, `debt_payoff`, or `investment`.
/// - [targetAmountCents] is the amount to reach; [currentAmountCents] is the
///   running total of [GoalContributions]s posted against the goal.
/// - [fundingAccountId] is the account contributions move into (for
///   savings/investment) or the liability being paid down (debt_payoff).
/// - [isCompleted] flips true once contributions reach the target.
class Goals extends Table {
  TextColumn get id => text()();

  TextColumn get name => text()();

  // savings | debt_payoff | investment
  TextColumn get type => text()();

  IntColumn get targetAmountCents => integer()();

  IntColumn get currentAmountCents =>
      integer().withDefault(const Constant(0))();

  IntColumn get targetDate => integer().nullable()();

  TextColumn get fundingAccountId => text().references(Accounts, #id)();

  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();

  IntColumn get createdAt => integer()();

  IntColumn get updatedAt => integer()();

  IntColumn get deletedAt => integer().nullable()();

  IntColumn get version => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// A ledger-backed contribution against a [Goals] row.
///
/// Every contribution posts a balanced transfer through the ledger;
/// [transactionId] keeps the audit trail pointing at that posting so
/// contribution history can be reconciled with the transactions list.
class GoalContributions extends Table {
  TextColumn get id => text()();

  TextColumn get goalId => text().references(Goals, #id)();

  TextColumn get transactionId => text().references(Transactions, #id)();

  IntColumn get amountCents => integer()();

  IntColumn get contributedOn => integer()();

  TextColumn get note => text().nullable()();

  IntColumn get createdAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// A fixed-term deposit on an [Accounts] row.
///
/// The principal stays in [accountId]; at maturity [TimeDepositService]
/// posts the interest earned as a balanced income transaction and records its
/// id in [maturedTransactionId] so history stays auditable. [maturityValueCents]
/// is the projected payout, recomputed whenever the deposit is edited.
class TimeDeposits extends Table {
  TextColumn get id => text()();

  TextColumn get accountId => text().references(Accounts, #id)();

  /// Display name; defaults to the account name when created.
  TextColumn get label => text()();

  IntColumn get principalCents => integer()();

  /// Annual interest rate as a decimal fraction, e.g. 0.06 for 6% p.a.
  RealColumn get interestRate => real()();

  // simple | compound
  TextColumn get interestMethod => text()();

  IntColumn get startDate => integer()();

  IntColumn get maturityDate => integer()();

  /// Principal plus the interest earned over the full term.
  IntColumn get maturityValueCents => integer()();

  BoolColumn get isMatured => boolean().withDefault(const Constant(false))();

  /// The income transaction that realized the interest; null until matured.
  TextColumn get maturedTransactionId =>
      text().references(Transactions, #id).nullable()();

  IntColumn get createdAt => integer()();

  IntColumn get updatedAt => integer()();

  IntColumn get deletedAt => integer().nullable()();

  IntColumn get version => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Configures an [Accounts] row as an interest-bearing savings account.
///
/// Interest is credited to the linked account through the ledger on a
/// schedule derived from [compoundingFrequency]; every credit is a balanced
/// income posting. Paused accounts stop accruing interest but keep their
/// configuration.
class SavingsAccounts extends Table {
  TextColumn get accountId => text().references(Accounts, #id)();

  /// Annual interest rate as a decimal fraction, e.g. 0.05 for 5% p.a.
  RealColumn get interestRate => real()();

  // daily | monthly | annually
  TextColumn get compoundingFrequency => text()();

  /// Day of the month (1-28) interest is credited for monthly compounding.
  IntColumn get interestCreditDay => integer()();

  BoolColumn get isPaused => boolean().withDefault(const Constant(false))();

  /// Millis when this savings arrangement started; anchors annual credits.
  IntColumn get startDate => integer()();

  IntColumn get updatedAt => integer()();

  IntColumn get deletedAt => integer().nullable()();

  IntColumn get version => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {accountId};
}

/// A planned interest credit for a [SavingsAccounts] row.
///
/// The schedule is seeded in advance from the account's configuration; when a
/// due credit is realized, the principal and interest snapshots plus the
/// generated income transaction id are filled in so history stays auditable.
class InterestSchedules extends Table {
  TextColumn get id => text()();

  TextColumn get savingsAccountId =>
      text().references(SavingsAccounts, #accountId)();

  /// Millis when this credit is scheduled to be realized.
  IntColumn get dueDate => integer()();

  /// Balance the interest was computed on; null until the credit is posted.
  IntColumn get principalCents => integer().nullable()();

  /// Interest credited in integer cents; null until the credit is posted.
  IntColumn get interestCents => integer().nullable()();

  /// The income transaction that realized this credit; null until posted.
  TextColumn get transactionId =>
      text().references(Transactions, #id).nullable()();

  IntColumn get createdAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// A Pag-IBIG MP2 savings account — a 5-year, tax-free savings vehicle that
/// pays annual dividends on the balance held in [accountId].
///
/// Contributions transfer money into [accountId]; withdrawals move it out.
/// Each dividend year is realized by [MP2Service] as a balanced income posting
/// recorded in [Mp2Dividends], so dividends are never credited twice.
class Mp2Accounts extends Table {
  TextColumn get id => text()();

  TextColumn get accountId => text().references(Accounts, #id)();

  /// Display name; defaults to the account name when created.
  TextColumn get label => text()();

  /// Annual dividend rate as a decimal fraction, e.g. 0.07 for 7% p.a.
  RealColumn get dividendRate => real()();

  IntColumn get startDate => integer()();

  /// Five years after [startDate] by MP2 rules.
  IntColumn get maturityDate => integer()();

  BoolColumn get isMatured => boolean().withDefault(const Constant(false))();

  IntColumn get createdAt => integer()();

  IntColumn get updatedAt => integer()();

  IntColumn get deletedAt => integer().nullable()();

  IntColumn get version => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// A ledger-backed contribution against an [Mp2Accounts] row.
///
/// Every contribution posts a balanced transfer into the MP2 account;
/// [transactionId] keeps the audit trail pointing at that posting.
class Mp2Contributions extends Table {
  TextColumn get id => text()();

  TextColumn get mp2AccountId => text().references(Mp2Accounts, #id)();

  TextColumn get transactionId => text().references(Transactions, #id)();

  IntColumn get amountCents => integer()();

  IntColumn get contributedOn => integer()();

  TextColumn get note => text().nullable()();

  IntColumn get createdAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// A ledger-backed partial or full withdrawal from an [Mp2Accounts] row.
///
/// Every withdrawal posts a balanced transfer out of the MP2 account;
/// [transactionId] keeps the audit trail pointing at that posting.
class Mp2Withdrawals extends Table {
  TextColumn get id => text()();

  TextColumn get mp2AccountId => text().references(Mp2Accounts, #id)();

  TextColumn get transactionId => text().references(Transactions, #id)();

  IntColumn get amountCents => integer()();

  IntColumn get withdrawnOn => integer()();

  TextColumn get note => text().nullable()();

  IntColumn get createdAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// A realized annual dividend for an [Mp2Accounts] row.
///
/// [year] is the zero-based dividend year (0 = the first year of the term);
/// the dividend is credited on that year's anniversary. [transactionId] is
/// null when the dividend was zero and nothing was posted.
class Mp2Dividends extends Table {
  TextColumn get id => text()();

  TextColumn get mp2AccountId => text().references(Mp2Accounts, #id)();

  TextColumn get transactionId =>
      text().references(Transactions, #id).nullable()();

  IntColumn get year => integer()();

  IntColumn get amountCents => integer()();

  /// The anniversary date the dividend was credited on.
  IntColumn get paidOn => integer()();

  IntColumn get createdAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// A fixed-income bond held in [accountId] that pays periodic coupons at
/// [couponRate] on [couponSchedule].
///
/// The face value stays in the linked account for the whole term; every coupon
/// is realized by [BondService] as a balanced income posting recorded in
/// [BondCoupons], so coupons are never credited twice. [nextCouponDate] is the
/// cursor the engine advances as coupons are realized.
class Bonds extends Table {
  TextColumn get id => text()();

  TextColumn get accountId => text().references(Accounts, #id)();

  /// Display name; defaults to the account name when created.
  TextColumn get label => text()();

  /// The bond's face value in integer cents; coupons are computed on this.
  IntColumn get faceValueCents => integer()();

  /// Annual coupon rate as a decimal fraction, e.g. 0.05 for 5% p.a.
  RealColumn get couponRate => real()();

  // monthly | quarterly | semi-annual | annual
  TextColumn get couponSchedule => text()();

  IntColumn get startDate => integer()();

  IntColumn get maturityDate => integer()();

  /// The next coupon date to realize; advanced as coupons are credited.
  IntColumn get nextCouponDate => integer()();

  BoolColumn get isMatured => boolean().withDefault(const Constant(false))();

  IntColumn get createdAt => integer()();

  IntColumn get updatedAt => integer()();

  IntColumn get deletedAt => integer().nullable()();

  IntColumn get version => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// A realized coupon for a [Bonds] row.
///
/// [period] is the zero-based coupon index (0 = the first coupon of the term);
/// the coupon is credited on that period's date. [transactionId] is null when
/// the coupon was zero and nothing was posted.
class BondCoupons extends Table {
  TextColumn get id => text()();

  TextColumn get bondId => text().references(Bonds, #id)();

  TextColumn get transactionId =>
      text().references(Transactions, #id).nullable()();

  IntColumn get period => integer()();

  IntColumn get couponCents => integer()();

  /// The coupon date the income was credited on.
  IntColumn get paidOn => integer()();

  IntColumn get createdAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}