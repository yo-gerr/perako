/// Hidden balancing accounts used by the ledger so income and expense
/// transactions stay balanced while real asset/liability accounts stay clean.
///
/// These ids never appear in the [Accounts] table, so they are naturally
/// excluded from derived net worth.
abstract final class LedgerConstants {
  /// Credit side for income transactions.
  static const String counterpartyIncome = 'counterparty_income';

  /// Debit side for expense transactions.
  static const String counterpartyExpense = 'counterparty_expense';
}
